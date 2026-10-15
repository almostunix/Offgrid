//
// ConnectionManager.swift
//
// Connection state machine for the Cerbo's MQTT broker (T-16).
// CocoaMQTT does the transport, MQTT keep-alive and auto-reconnect with capped backoff. This class maps its callbacks
// to ConnectionState, learns the portal ID, feeds messages into LiveDataStore, and runs the Victron keepalive:
// the first R/<portalId>/keepalive is empty (full republish), later ones ask for suppress-republish (docs/PLAN.md).
// Everything it sends goes through ReadOnlyPublisher, so only R/ topics can ever leave the app.
//

import Foundation
import CocoaMQTT

public enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting
    case failed(ConnectionError)
}

public enum ConnectionError: Error, Equatable {
    case invalidPort(Int)
    case connectionRefused
    case authenticationFailed
    case unknown(String)
}

public final class ConnectionManager {
    public private(set) var state: ConnectionState = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    public private(set) var portalId: String?

    /// Called on `queue` whenever the state changes.
    public var onStateChange: ((ConnectionState) -> Void)?
    /// Called on `queue` when the portal ID is learned from the first N/<portalId>/... message.
    public var onPortalIdDetected: ((String) -> Void)?
    /// Called on `queue` after each message has been passed to the LiveDataStore.
    public var onMessage: ((String) -> Void)?

    /// History store for managing history data
    public let historyStore = HistoryStore()

    private let mqtt: CocoaMQTT
    private let liveDataStore: LiveDataStore
    private let keepaliveInterval: TimeInterval
    private let queue: DispatchQueue
    private var publisher: ReadOnlyPublisher?
    private var keepaliveTimer: DispatchSourceTimer?
    private var sentFirstKeepalive = false
    private var userDisconnect = false
    private var fullPublishCompleted = false

    /// - Parameters:
    ///   - keepaliveInterval: seconds between Victron keepalives (must stay under the Cerbo's 60 s timeout).
    ///   - queue: where all callbacks and state changes happen (default: main).
    public init(profile: ConnectionProfile, liveDataStore: LiveDataStore, password: String? = nil,
                keepaliveInterval: TimeInterval = 30, queue: DispatchQueue = .main) throws {
        guard let port = UInt16(exactly: profile.port), port > 0 else { throw ConnectionError.invalidPort(profile.port) }
        self.liveDataStore = liveDataStore
        self.keepaliveInterval = keepaliveInterval
        self.queue = queue
        mqtt = CocoaMQTT(clientID: "VictronKit-" + UUID().uuidString, host: profile.host, port: port)
        mqtt.delegateQueue = queue
        mqtt.keepAlive = 60                       // MQTT PINGREQ, handled by CocoaMQTT
        mqtt.autoReconnect = true                 // CocoaMQTT backs off exponentially up to the cap
        mqtt.autoReconnectTimeInterval = 1        // seconds (UInt16)
        mqtt.maxAutoReconnectTimeInterval = 30
        mqtt.enableSSL = profile.useTLS           // certificate pinning comes with T-35
        mqtt.username = profile.username
        mqtt.password = password
        if let known = profile.portalId { try usePortalId(known) }
        setUpCallbacks()
    }

    public func connect() {
        queue.async {
            self.userDisconnect = false
            self.state = .connecting
            _ = self.mqtt.connect()
        }
    }

    public func disconnect() {
        queue.async {
            self.userDisconnect = true
            self.stopKeepalive()
            self.mqtt.disconnect()
            self.state = .idle
        }
    }

    // MARK: - CocoaMQTT callbacks (all on `queue`)

    private func setUpCallbacks() {
        mqtt.didConnectAck = { [weak self] mqtt, ack in
            guard let self = self else { return }
            switch ack {
            case .accept:
                self.state = .connected
                mqtt.subscribe(self.portalId.map { "N/\($0)/#" } ?? "N/+/#")
            case .badUsernameOrPassword, .notAuthorized:
                self.state = .failed(.authenticationFailed)
            default:
                self.state = .failed(.connectionRefused)
            }
        }
        mqtt.didSubscribeTopics = { [weak self] _, success, _ in
            guard let self = self, success.count > 0 else { return }
            self.sentFirstKeepalive = false   // every (re)connect starts with a full republish
            self.startKeepalive()
        }
        mqtt.didReceiveMessage = { [weak self] _, message, _ in
            self?.handle(topic: message.topic, payload: Data(message.payload))
        }
        mqtt.didDisconnect = { [weak self] _, _ in
            guard let self = self else { return }
            self.stopKeepalive()
            if self.userDisconnect { self.state = .idle } else { self.state = .reconnecting }   // CocoaMQTT retries
        }
    }

    private func handle(topic: String, payload: Data) {
        if portalId == nil {
            let parts = topic.split(separator: "/", omittingEmptySubsequences: false)
            if parts.count >= 3, parts[0] == "N", !parts[1].isEmpty, (try? usePortalId(String(parts[1]))) != nil {
                onPortalIdDetected?(String(parts[1]))
                startKeepalive()   // now we can ask for the full publish
            }
        }
        liveDataStore.handle(topic: topic, payload: payload)
        historyStore.handle(topic: topic, payload: payload)
        onMessage?(topic)
        
        // Check for full_publish_completed
        if topic.hasSuffix("full_publish_completed") {
            fullPublishCompleted = true
            requestHistory()
        }
    }

    // MARK: - Victron keepalive

    private func usePortalId(_ id: String) throws {
        publisher = try ReadOnlyPublisher(portalId: id) { [weak self] topic, payload in
            self?.mqtt.publish(topic, withString: payload, qos: .qos0, retained: false)
        }
        portalId = id
    }

    private func startKeepalive() {
        guard publisher != nil, state == .connected, keepaliveTimer == nil else { return }
        sendKeepalive()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + keepaliveInterval, repeating: keepaliveInterval)
        timer.setEventHandler { [weak self] in self?.sendKeepalive() }
        timer.resume()
        keepaliveTimer = timer
    }

    private func stopKeepalive() {
        keepaliveTimer?.cancel()
        keepaliveTimer = nil
    }

    private func sendKeepalive() {
        guard let publisher = publisher, let id = portalId else { return }
        let payload = sentFirstKeepalive ? #"{"keepalive-options":["suppress-republish"]}"# : ""
        try? publisher.publish(topic: "R/\(id)/keepalive", payload: payload)
        sentFirstKeepalive = true
    }

    /// Request history data by publishing R/ sub-tree reads for all known solar chargers and batteries
    public func requestHistory() {
        queue.async {
            guard let publisher = self.publisher, let id = self.portalId else { return }
            
            // Request solar charger history for all known instances
            for instance in self.liveDataStore.solarChargers.keys {
                try? publisher.publish(topic: "R/" + id + "/solarcharger/" + instance + "/History", payload: "")
            }
            
            // Request battery history for all known instances
            for instance in self.liveDataStore.batteries.keys {
                try? publisher.publish(topic: "R/" + id + "/battery/" + instance + "/History", payload: "")
            }
        }
    }
}
