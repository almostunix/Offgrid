import Foundation
import CocoaMQTT

final class FixtureReplayer {
    private let broker: TestBroker
    private let mqtt: CocoaMQTT
    private let queue = DispatchQueue(label: "com.victron.fixture-replayer")
    private var fixtures: [(topic: String, payload: String)] = []

    init(broker: TestBroker) {
        self.broker = broker
        self.mqtt = CocoaMQTT(clientID: "replayer", host: "127.0.0.1", port: broker.port)
        self.mqtt.keepAlive = 60
        self.mqtt.enableSSL = false
        self.fixtures = FixtureLoader.loadFixtures()
    }

    /// Connects, subscribes to R/c0ffee000001/keepalive and returns only once the broker has acknowledged
    /// the subscription (callbacks run on our own queue, so waiting here can't deadlock the test's main thread).
    func start(timeout: TimeInterval = 5) throws {
        let subscribed = DispatchSemaphore(value: 0)
        mqtt.delegateQueue = queue
        mqtt.didConnectAck = { mqtt, ack in
            if ack == .accept {
                mqtt.subscribe("R/c0ffee000001/keepalive")   // only after CONNACK
            }
        }
        mqtt.didSubscribeTopics = { _, success, _ in
            if success["R/c0ffee000001/keepalive"] != nil { subscribed.signal() }
        }

        mqtt.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let self = self else { return }
            self.handleKeepaliveMessage(topic: message.topic, payload: message.string ?? "")   // already on our queue
        }

        _ = mqtt.connect()
        if subscribed.wait(timeout: .now() + timeout) == .timedOut {
            throw NSError(domain: "FixtureReplayer", code: 1, userInfo: [NSLocalizedDescriptionKey: "replayer not subscribed within \(timeout)s"])
        }
    }

    func publishFixtures(payload: String) {
        queue.async {
            self.handleKeepaliveMessage(topic: "R/c0ffee000001/keepalive", payload: payload)
        }
    }

    static func parseKeepaliveOptions(payload: String) -> (suppress: Bool, echo: String?) {
        // Empty payload means no options
        guard !payload.isEmpty else {
            return (false, nil)
        }

        guard let keepaliveData = payload.data(using: .utf8) else {
            return (false, nil)
        }

        guard let keepaliveJson = try? JSONSerialization.jsonObject(with: keepaliveData, options: []) as? [String: Any] else {
            return (false, nil)
        }

        guard let options = keepaliveJson["keepalive-options"] as? [Any] else {
            return (false, nil)
        }

        var suppress = false
        var echoId: String? = nil

        for option in options {
            if let option = option as? String {
                // String option: "suppress-republish"
                if option == "suppress-republish" {
                    suppress = true
                }
            } else if let option = option as? [String: Any] {
                // Dictionary option: {"full-publish-completed-echo": "id"}
                if let echo = option["full-publish-completed-echo"] as? String {
                    echoId = echo
                }
            }
        }

        return (suppress, echoId)
    }

    private func handleKeepaliveMessage(topic: String, payload: String) {
        // Parse keepalive options
        let (suppress, _) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        
        // Check if suppress-republish is requested
        if suppress {
            return
        }

        // Publish all fixtures
        for fixture in fixtures {
            mqtt.publish(fixture.topic, withString: fixture.payload, qos: .qos0, retained: false)
        }

        // Publish full_publish_completed
        let timestamp = Int(Date().timeIntervalSince1970)
        var completionPayload: [String: Any] = ["value": timestamp]

        // Check for echo id
        let (_, echoId) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        if let echoId = echoId {
            completionPayload["full-publish-completed-echo"] = echoId
        }

        let completionData = try? JSONSerialization.data(withJSONObject: completionPayload, options: [])
        if let completionData = completionData, let completionString = String(data: completionData, encoding: .utf8) {
            mqtt.publish("N/c0ffee000001/full_publish_completed", withString: completionString, qos: .qos0, retained: false)
        }
    }

    func stop() {
        mqtt.disconnect()
    }
}
