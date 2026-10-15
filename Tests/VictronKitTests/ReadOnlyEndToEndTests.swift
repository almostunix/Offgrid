import XCTest
@testable import VictronKit
import CocoaMQTT

final class ReadOnlyEndToEndTests: XCTestCase {
    var broker: TestBroker!
    var replayer: FixtureReplayer!
    var store: LiveDataStore!
    var manager: ConnectionManager?
    let queue = DispatchQueue(label: "ReadOnlyEndToEndTests")
    
    // Spy client to monitor W/ topics
    var spyMQTT: CocoaMQTT?
    var receivedWMessages: [(topic: String, payload: String)] = []
    var receivedAllMessages: [(topic: String, payload: String)] = []
    let spyQueue = DispatchQueue(label: "ReadOnlyEndToEndTests.spy")
    var spySubscribed = false   // only touched on spyQueue

    override func setUpWithError() throws {
        broker = TestBroker()
        try broker.start()
        replayer = FixtureReplayer(broker: broker)
        try replayer.start()
        store = LiveDataStore()
        
        // Set up spy client
        setupSpyClient()
    }

    override func tearDown() {
        if let manager = manager {
            manager.disconnect()
            queue.sync {}
        }
        spyMQTT?.disconnect()
        replayer?.stop()
        broker?.stop()
        super.tearDown()
    }

    private func setupSpyClient() {
        spyMQTT = CocoaMQTT(clientID: "spy-watcher", host: "127.0.0.1", port: broker.port)
        spyMQTT?.keepAlive = 60
        spyMQTT?.enableSSL = false
        spyMQTT?.delegateQueue = spyQueue
        
        spyMQTT?.didConnectAck = { mqtt, ack in
            // "#" sees every topic, W/ included; the W/ filter is applied in didReceiveMessage
            if ack == .accept { mqtt.subscribe("#") }
        }
        
        spyMQTT?.didSubscribeTopics = { [weak self] _, success, _ in
            if success["#"] != nil { self?.spySubscribed = true }
        }
        
        spyMQTT?.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let self = self else { return }
            let topic = message.topic
            let payload = message.string ?? ""
            
            // Track all messages
            self.receivedAllMessages.append((topic: topic, payload: payload))
            
            // Specifically track W/ messages
            if topic.hasPrefix("W/") {
                self.receivedWMessages.append((topic: topic, payload: payload))
            }
        }
        
        _ = spyMQTT?.connect()
    }

    private func makeManager(portalId: String?, keepalive: TimeInterval = 30) throws -> ConnectionManager {
        var profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: Int(broker.port), useTLS: false)
        profile.portalId = portalId
        let m = try ConnectionManager(profile: profile, liveDataStore: store, keepaliveInterval: keepalive, queue: queue)
        manager = m
        return m
    }

    private func onQueue<T>(_ body: () -> T) -> T { queue.sync(execute: body) }

    /// Polls `condition` (evaluated on the manager's queue) until it holds or `timeout` passes.
    private func waitUntil(_ what: String, timeout: TimeInterval = 5, _ condition: () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if onQueue(condition) { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTFail("timed out waiting for: " + what)
    }

    /// Waits for the spy to receive subscription acknowledgment
    private func waitForSpySubscribed(timeout: TimeInterval = 3) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if spyQueue.sync(execute: { spySubscribed }) { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTFail("timed out waiting for spy to be subscribed")
    }

    func testNoWTopicsPublished() throws {
        // Wait for spy to be fully subscribed
        waitForSpySubscribed()
        
        // Create and connect manager
        let m = try makeManager(portalId: "c0ffee000001")
        m.connect()
        
        // Wait for full publish to complete
        waitUntil("full publish") { self.store.batteries["279"] != nil }
        
        // Wait for at least one keepalive and history to be requested/received
        waitUntil("keepalive and history") {
            // Check for at least one keepalive
            let hasKeepalive = self.replayer.receivedKeepalives.count >= 1
            // Check for history data
            let hasHistory = self.manager?.historyStore.solarDays["278"]?.count == 30 && 
                           self.manager?.historyStore.batteryTotals["279"]?.count == 8
            return hasKeepalive && hasHistory
        }
        
        // Disconnect cleanly
        m.disconnect()
        waitUntil("disconnected") { self.manager?.state == .idle }
        
        Thread.sleep(forTimeInterval: 0.3)   // let the spy drain anything still in flight
        let (wMessages, allMessages) = spyQueue.sync { (receivedWMessages, receivedAllMessages) }

        // Verify no W/ messages were received
        XCTAssertEqual(wMessages.count, 0, "No W/ topics should be published")
        
        // Verify all messages from app start with R/c0ffee000001/
        // Messages from the app will be the ones we sent (keepalives, history requests)
        // We need to verify that all messages starting with R/ from the app follow the correct format
        let rMessagesFromApp = allMessages.filter { $0.topic.hasPrefix("R/") }
        
        // The spy must actually see the app's traffic, or the checks above prove nothing
        XCTAssertTrue(rMessagesFromApp.contains { $0.topic == "R/c0ffee000001/keepalive" }, "the spy saw no keepalive")
        XCTAssertTrue(rMessagesFromApp.contains { $0.topic.hasSuffix("/History") }, "the spy saw no history read")

        // All R/ messages should start with R/c0ffee000001/
        for message in rMessagesFromApp {
            XCTAssertTrue(message.topic.hasPrefix("R/c0ffee000001/"), 
                        "R/ message should start with R/c0ffee000001/: \(message.topic)")
        }
    }

    func testCocoaMQTTOnlyInConnectionManager() throws {
        // Tests/VictronKitTests/<this file> -> the package root
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var filesWithCocoaMQTT: [String] = []
        var scanned = 0
        for dir in ["Sources", "App"] {
            let base = root.appendingPathComponent(dir)
            let files = try XCTUnwrap(FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil))
            for case let url as URL in files where url.pathExtension == "swift" {
                scanned += 1
                if try String(contentsOf: url, encoding: .utf8).contains("import CocoaMQTT") {
                    filesWithCocoaMQTT.append(url.lastPathComponent)
                }
            }
        }
        XCTAssertGreaterThan(scanned, 20, "the scan found too few source files")
        XCTAssertEqual(filesWithCocoaMQTT, ["ConnectionManager.swift"],
                       "Only ConnectionManager.swift may import CocoaMQTT. Found in: \(filesWithCocoaMQTT.joined(separator: ", "))")
    }
}
