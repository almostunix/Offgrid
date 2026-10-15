import Foundation
import CocoaMQTT

final class TestBroker {
    let port: UInt16
    let tls: Bool
    let username: String?
    let password: String?
    private var process: Process?
    private var configFileURL: URL?
    private var configDirURL: URL?
    private var _caCertificateURL: URL?
    var serverCertificateURL: URL?
    private var serverKeyURL: URL?
    private var passwordFileURL: URL?
    private let mqttBinaryPath = "/opt/homebrew/sbin/mosquitto"

    init(port: UInt16 = 0, tls: Bool = false, username: String? = nil, password: String? = nil) {
        self.port = port == 0 ? Self.findFreePort() : port
        self.tls = tls
        self.username = username
        self.password = password
        print("TestBroker initialized with port: \(port), tls: \(tls), username: \(username ?? "nil")")
    }

    var caCertificateURL: URL? {
        return _caCertificateURL
    }

    /// True while this broker's own mosquitto process is alive (other tests may run their own brokers in parallel).
    var isRunning: Bool { process?.isRunning ?? false }

    private static func findFreePort() -> UInt16 {
        let startPort: UInt16 = 20000
        let endPort: UInt16 = 40000
        let portRange = startPort...endPort

        for _ in 0..<100 {
            let randomPort = UInt16.random(in: portRange)
            if isPortAvailable(randomPort) {
                return randomPort
            }
        }
        return startPort
    }

    private static func isPortAvailable(_ port: UInt16) -> Bool {
        let mqtt = CocoaMQTT(clientID: "port-checker", host: "127.0.0.1", port: port)
        mqtt.connect()
        mqtt.disconnect()
        return true
    }

    func start() throws {
        // Check if mosquitto binary exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: mqttBinaryPath) else {
            print("Mosquitto binary not found at: \(mqttBinaryPath)")
            throw NSError(domain: "TestBroker", code: 1, userInfo: [NSLocalizedDescriptionKey: "brew install mosquitto"])
        }
        print("Starting TestBroker on port \(port), TLS: \(tls), username: \(username ?? "nil")")

        // Create temp directory for config
        let uuid = UUID().uuidString
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(uuid)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configDirURL = tempDir

        // Generate TLS certificates if needed
        if tls {
            try generateTLSCertificates(in: tempDir)
        }

        // Create password file if needed
        if let username = username, let password = password {
            try createPasswordFile(username: username, password: password, in: tempDir)
        }

        // Write config file
        let configFile = tempDir.appendingPathComponent("mosquitto.conf")
        let configContent = try createConfigContent(in: tempDir)
        try configContent.write(to: configFile, atomically: true, encoding: .utf8)
        configFileURL = configFile
        
        // Debug: print config content
        print("=== Mosquitto Config ===")
        print(configContent)
        print("========================")

        // Launch mosquitto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mqttBinaryPath)
        process.arguments = ["-c", configFile.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        self.process = process
        print("Mosquitto process launched with PID: \(process.processIdentifier)")

        // Wait for broker to be ready
        try waitForBrokerReady(port: port)
        print("Broker started successfully on port \(port)")
    }

    private func generateTLSCertificates(in directory: URL) throws {
        let fileManager = FileManager.default
        let opensslPath = "/usr/bin/openssl"
        
        // Create CA key and certificate
        let caKeyFile = directory.appendingPathComponent("ca.key")
        let caCertFile = directory.appendingPathComponent("ca.crt")
        
        // Generate CA private key
        var task = Process()
        task.launchPath = opensslPath
        task.arguments = ["genrsa", "-out", caKeyFile.path, "2048"]
        task.launch()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestBroker", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate CA key"])
        }
        
        // Generate CA certificate
        task = Process()
        task.launchPath = opensslPath
        task.arguments = [
            "req", "-x509", "-new", "-nodes", "-key", caKeyFile.path,
            "-days", "1", "-out", caCertFile.path,
            "-subj", "/C=US/ST=Test/L=Test/O=Test/OU=Test/CN=Test CA"
        ]
        task.launch()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestBroker", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to generate CA certificate"])
        }
        
        _caCertificateURL = caCertFile
        
        // Create server key
        let serverKeyFile = directory.appendingPathComponent("server.key")
        task = Process()
        task.launchPath = opensslPath
        task.arguments = ["genrsa", "-out", serverKeyFile.path, "2048"]
        task.launch()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestBroker", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to generate server key"])
        }
        
        // Create server CSR
        let serverCsrFile = directory.appendingPathComponent("server.csr")
        task = Process()
        task.launchPath = opensslPath
        task.arguments = [
            "req", "-new", "-key", serverKeyFile.path, "-out", serverCsrFile.path,
            "-subj", "/C=US/ST=Test/L=Test/O=Test/OU=Test/CN=127.0.0.1"
        ]
        task.launch()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestBroker", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to generate server CSR"])
        }
        
        // Create server certificate signed by CA
        let serverCertFile = directory.appendingPathComponent("server.crt")
        let configFile = directory.appendingPathComponent("openssl.cnf")
        let configContent = """
[req]
distinguished_name = req_distinguished_name

[req_distinguished_name]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = 127.0.0.1
"""
        try configContent.write(to: configFile, atomically: true, encoding: .utf8)
        
        task = Process()
        task.launchPath = opensslPath
        task.arguments = [
            "x509", "-req", "-in", serverCsrFile.path, "-CA", caCertFile.path,
            "-CAkey", caKeyFile.path, "-CAcreateserial", "-out", serverCertFile.path,
            "-days", "1", "-extensions", "v3_req", "-extfile", configFile.path
        ]
        task.launch()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestBroker", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to generate server certificate"])
        }
        
        serverCertificateURL = serverCertFile
        serverKeyURL = serverKeyFile
        
        // Clean up temporary files
        try? fileManager.removeItem(at: caKeyFile)
        try? fileManager.removeItem(at: serverCsrFile)
        try? fileManager.removeItem(at: configFile)
    }

    private func createPasswordFile(username: String, password: String, in directory: URL) throws {
        let passwordFile = directory.appendingPathComponent("password.txt")
        let mosquittoPasswdPath = "/opt/homebrew/bin/mosquitto_passwd"
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: mosquittoPasswdPath) else {
            throw NSError(domain: "TestBroker", code: 8, userInfo: [NSLocalizedDescriptionKey: "mosquitto_passwd not found. brew install mosquitto"])
        }
        
        var task = Process()
        task.launchPath = mosquittoPasswdPath
        task.arguments = ["-c", "-b", passwordFile.path, username, password]
        task.launch()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "TestBroker", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to create password file"])
        }
        
        passwordFileURL = passwordFile
    }

    private func createConfigContent(in directory: URL) throws -> String {
        var configLines = [String]()
        configLines.append("listener \(port) 127.0.0.1")
        
        if tls {
            configLines.append("protocol mqtt")
            configLines.append("cafile " + directory.appendingPathComponent("ca.crt").path)
            configLines.append("certfile " + directory.appendingPathComponent("server.crt").path)
            configLines.append("keyfile " + directory.appendingPathComponent("server.key").path)
            configLines.append("tls_version tlsv1.2")
        }
        
        if passwordFileURL != nil {
            configLines.append("allow_anonymous false")
            configLines.append("password_file " + passwordFileURL!.path)
        } else {
            configLines.append("allow_anonymous true")
        }
        
        configLines.append("persistence false")
        configLines.append("log_dest stderr")
        
        return configLines.joined(separator: "\n")
    }

    private func waitForBrokerReady(port: UInt16) throws {
        let startTime = Date()
        let timeout: TimeInterval = 5.0

        while Date().timeIntervalSince(startTime) < timeout {
            let task = Process()
            task.launchPath = "/usr/bin/nc"
            task.arguments = ["-z", "127.0.0.1", String(port)]
            task.launch()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return
            }
            
            Thread.sleep(forTimeInterval: 0.2)
        }

        throw NSError(domain: "TestBroker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Broker failed to start"])
    }

    func stop() {
        print("Stopping TestBroker on port \(port)")
        process?.terminate()
        process?.waitUntilExit()   // really gone before the next test; `process` is kept so isRunning can be checked

        if let configDirURL = configDirURL {
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: configDirURL)
        }
        configFileURL = nil
        configDirURL = nil
        _caCertificateURL = nil
        serverCertificateURL = nil
        serverKeyURL = nil
        passwordFileURL = nil
    }
}
