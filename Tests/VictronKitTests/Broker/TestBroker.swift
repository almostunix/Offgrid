import Foundation
import CocoaMQTT

final class TestBroker {
    let port: UInt16
    private var process: Process?
    /// True while this broker's own mosquitto process is alive (other tests may run their own brokers in parallel).
    var isRunning: Bool { process?.isRunning ?? false }
    private var configFileURL: URL?
    private var configDirURL: URL?
    private let mqttBinaryPath = "/opt/homebrew/sbin/mosquitto"

    init(port: UInt16 = 0) {
        self.port = port == 0 ? Self.findFreePort() : port
    }

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
            throw NSError(domain: "TestBroker", code: 1, userInfo: [NSLocalizedDescriptionKey: "brew install mosquitto"])
        }

        // Create temp directory for config
        let uuid = UUID().uuidString
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(uuid)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        configDirURL = tempDir

        // Write config file
        let configFile = tempDir.appendingPathComponent("mosquitto.conf")
        let configContent = "listener \(port) 127.0.0.1\nallow_anonymous true\npersistence false\nlog_dest stderr\n"
        try configContent.write(to: configFile, atomically: true, encoding: .utf8)
        configFileURL = configFile

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

        // Wait for broker to be ready
        try waitForBrokerReady(port: port)
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
        process?.terminate()
        process?.waitUntilExit()   // really gone before the next test; `process` is kept so isRunning can be checked

        if let configDirURL = configDirURL {
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: configDirURL)
        }
        configFileURL = nil
        configDirURL = nil
    }
}
