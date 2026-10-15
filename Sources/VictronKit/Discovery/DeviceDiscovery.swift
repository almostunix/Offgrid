//
// DeviceDiscovery.swift
//
// Main discovery service for finding Victron GX devices on the LAN.
//

import Foundation
import Network

public class DeviceDiscovery: DeviceDiscovering {
    private var discoveryTask: DispatchWorkItem?
    private var onUpdate: ([DiscoveredDevice]) -> Void = { _ in }
    private let discoveryQueue = DispatchQueue(label: "VictronKit.discovery", qos: .utility)

    public init() {}

    public func start(onUpdate: @escaping ([DiscoveredDevice]) -> Void) {
        self.onUpdate = onUpdate
        
        let task = DispatchWorkItem { [weak self] in
            self?.discoverDevice()
        }
        
        discoveryTask = task
        discoveryQueue.asyncAfter(deadline: .now(), execute: task)
    }

    public func stop() {
        discoveryTask?.cancel()
        discoveryTask = nil
    }

    private func discoverDevice() {
        // Step 1: Resolve venus.local to IPv4
        let host = "venus.local"
        var hint = addrinfo()
        hint.ai_family = AF_INET
        hint.ai_socktype = SOCK_DGRAM

        var result: UnsafeMutablePointer<addrinfo>?
        let error = getaddrinfo(host, nil, &hint, &result)

        guard error == 0, result != nil else {
            // No device found
            onUpdate([])
            freeaddrinfo(result)
            return
        }

        defer { freeaddrinfo(result) }

        // Get the IPv4 address as text
        guard let addr = result?.pointee.ai_addr, result?.pointee.ai_family == AF_INET else { onUpdate([]); return }
        var sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &sin.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { onUpdate([]); return }
        let ipAddress = String(cString: buffer)

        // Step 2: Send SSDP M-SEARCH to resolved IP
        let ssdpRequest = createSSDPRequest(ipAddress: ipAddress)
        let reply = sendSSDPRequest(request: ssdpRequest, ipAddress: ipAddress)

        // Step 3: Parse SSDP reply and fetch device description
        if let (portalId, location) = SSDPReply.parse(reply, from: ipAddress) {
            // Fetch device description
            if let description = fetchDeviceDescription(from: location) {
                // Validate manufacturer
                guard description.manufacturer == "Victron Energy" else {
                    onUpdate([])
                    return
                }

                let device = DiscoveredDevice(
                    id: portalId,
                    name: description.friendlyName,
                    host: ipAddress,
                    portalId: portalId,
                    mqttOnLan: description.mqttOnLan,
                    venusVersion: description.venusVersion,
                    lastSeen: Date()
                )
                onUpdate([device])
            } else {
                // Description fetch failed, create minimal device
                let device = DiscoveredDevice(
                    id: ipAddress,
                    name: "Victron GX (venus.local)",
                    host: ipAddress,
                    portalId: portalId,
                    lastSeen: Date()
                )
                onUpdate([device])
            }
        } else {
            // No valid SSDP reply, create minimal device
            let device = DiscoveredDevice(
                id: ipAddress,
                name: "Victron GX (venus.local)",
                host: ipAddress,
                lastSeen: Date()
            )
            onUpdate([device])
        }
    }

    private func createSSDPRequest(ipAddress: String) -> String {
        return "M-SEARCH * HTTP/1.1\r\n"
            + "HOST: " + ipAddress + ":1900\r\n"
            + "MAN: \"ssdp:discover\"\r\n"
            + "ST: urn:schemas-upnp-org:device:Basic:1\r\n"
            + "MX: 3\r\n"
            + "\r\n"
    }

    /// One unicast M-SEARCH to ipAddress:1900 (a connected UDP socket, so only that host's reply is received).
    /// The connection runs on its own queue: this function blocks the discovery queue while it waits.
    private func sendSSDPRequest(request: String, ipAddress: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var reply = ""
        let connection = NWConnection(host: NWEndpoint.Host(ipAddress), port: 1900, using: .udp)
        connection.stateUpdateHandler = { [weak connection] state in
            switch state {
            case .ready:
                connection?.send(content: Data(request.utf8), completion: .idempotent)
                connection?.receiveMessage { data, _, _, _ in
                    if let data, !data.isEmpty {
                        lock.lock(); reply = String(decoding: data.prefix(8192), as: UTF8.self); lock.unlock()
                    }
                    semaphore.signal()
                }
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue(label: "VictronKit.discovery.ssdp"))
        _ = semaphore.wait(timeout: .now() + 3.0)
        connection.cancel()
        lock.lock(); defer { lock.unlock() }
        return reply
    }

    /// One read-only GET of the device description. LOCATION was already checked to be on the resolved IP
    /// (SSDPReply.parse); redirects are refused, nothing is stored or sent but the request, max 64 KB.
    private func fetchDeviceDescription(from url: URL) -> DeviceDescription? {
        guard url.scheme == "http" else { return nil }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3.0
        config.timeoutIntervalForResource = 3.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.urlCredentialStorage = nil
        let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var description: DeviceDescription?
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil, let data, data.count <= 65_536,
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let parsed = DeviceDescriptionParser.parse(data)
            lock.lock(); description = parsed; lock.unlock()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 3.5)
        lock.lock(); defer { lock.unlock() }
        return description
    }
}

/// Refuses every HTTP redirect, so the description request can't be sent anywhere but the resolved host.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
