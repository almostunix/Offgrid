//
// SSDPSweeper.swift
//
// SSDP sweeper that probes multiple hosts for Victron GX devices.
//

import Foundation

public protocol DatagramTransport: AnyObject {
    var onReceive: ((Data, String) -> Void)? { get set }
    func send(_ data: Data, to host: String, port: UInt16)
    func close()
}

public final class UDPDatagramTransport: DatagramTransport {
    private var socket: Int32 = -1
    private let receiveQueue: DispatchQueue
    private var isRunning = false
    
    public var onReceive: ((Data, String) -> Void)?
    
    public init() {
        self.receiveQueue = DispatchQueue(label: "VictronKit.udp.receive", qos: .utility)
    }
    
    deinit {
        close()
    }
    
    public func send(_ data: Data, to host: String, port: UInt16) {
        guard socket != -1 else { return }
        
        let hostCString = host.cString(using: .ascii)
        guard let hostCString = hostCString else { return }
        
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(hostCString)
        
        _ = data.withUnsafeBytes { buffer in
            sendto(socket, buffer.baseAddress?.assumingMemoryBound(to: UInt8.self), buffer.count, 0, 
                   withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }, 
                   socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    
    public func start() {
        guard socket == -1 else { return }
        
        socket = Darwin.socket(AF_INET, SOCK_DGRAM, 0)
        guard socket != -1 else { return }
        
        // Set receive timeout to 0.5 seconds
        var timeout = timeval()
        timeout.tv_sec = 0
        timeout.tv_usec = 500000
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        // Bind to any available port
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) { 
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { 
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            close()
            return
        }
        
        isRunning = true
        startReceiveLoop()
    }
    
    private func startReceiveLoop() {
        receiveQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            var addr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let bufferSize = 8192
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            
            while self.isRunning {
                let bytesReceived = recvfrom(self.socket, &buffer, bufferSize, 0, 
                                            withUnsafeMutablePointer(to: &addr) { 
                                                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { 
                                                    $0
                                                }
                                            }, &addrLen)
                
                if bytesReceived > 0 {
                    let data = Data(buffer[0..<bytesReceived])
                    
                    // Extract sender's IP address
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
                    let senderIP = String(cString: ipBuffer)
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.onReceive?(data, senderIP)
                    }
                }
            }
        }
    }
    
    public func close() {
        isRunning = false
        if socket != -1 {
            Darwin.close(socket)
            socket = -1
        }
    }
}

public final class SSDPSweeper {
    private let transport: DatagramTransport
    private let interval: TimeInterval
    static let batchSize = 32
    private let listen: TimeInterval
    private let queue: DispatchQueue
    private var completion: (([(portalId: String, location: URL, host: String)]) -> Void)?
    
    public init(transport: DatagramTransport, interval: TimeInterval = 0.01, listen: TimeInterval = 3.0, queue: DispatchQueue = DispatchQueue(label: "VictronKit.sweep")) {
        self.transport = transport
        self.interval = interval
        self.listen = listen
        self.queue = queue
    }
    
    public func sweep(hosts: [String], request: (String) -> String, completion: @escaping ([(portalId: String, location: URL, host: String)]) -> Void) {
        self.completion = completion
        
        var results = [String: (portalId: String, location: URL, host: String)]()
        var sendCount = 0
        
        // Start transport
        if let udpTransport = transport as? UDPDatagramTransport {
            udpTransport.start()
        } else {
            // For testing or other transport types, we still need to set up the receive handler
            // but we won't start a socket
        }
        
        // Set up receive handler
        let resultsLock = NSLock()
        transport.onReceive = { [weak self] data, senderHost in
            guard let self = self else { return }
            
            let text = String(decoding: data, as: UTF8.self)
            if let parsed = SSDPReply.parse(text, from: senderHost) {
                // De-duplicate by portal ID (first reply wins)
                resultsLock.lock()
                if results[parsed.portalId] == nil {
                    results[parsed.portalId] = (parsed.portalId, parsed.location, senderHost)
                }
                resultsLock.unlock()
            }
        }
        
        // Send requests to each host
        for host in hosts {
            let ssdpRequest = request(host)
            transport.send(Data(ssdpRequest.utf8), to: host, port: 1900)
            sendCount += 1
            
            // Pause after each batch rather than each packet: a per-packet sleep is coalesced to ~80 ms on a utility queue (20 s for a /24)
            if self.interval > 0, sendCount % Self.batchSize == 0, sendCount < hosts.count {
                Thread.sleep(forTimeInterval: self.interval)
            }
        }
        
        // Schedule completion after listen timeout
        queue.asyncAfter(deadline: .now() + listen) { [weak self] in
            guard let self = self else { return }
            
            // Convert results to array (read under lock)
            resultsLock.lock()
            let finalResults = Array(results.values)
            resultsLock.unlock()
            
            self.completion?(finalResults)
            
            // Close transport
            self.transport.close()
            self.transport.onReceive = nil
            self.completion = nil
        }
    }
}