import XCTest
@testable import VictronKit

final class ConnectionManagerHistoryTests: XCTestCase {
    var broker: TestBroker!
    var replayer: FixtureReplayer!
    var store: LiveDataStore!
    var manager: ConnectionManager?
    let queue = DispatchQueue(label: "ConnectionManagerHistoryTests")

    override func setUpWithError() throws {
        broker = TestBroker()
        try broker.start()
        replayer = FixtureReplayer(broker: broker)
        try replayer.start()
        store = LiveDataStore()
    }

    override func tearDown() {
        if let manager = manager {
            manager.disconnect()
            queue.sync {}
        }
        replayer?.stop()
        broker?.stop()
        super.tearDown()
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

    func testRequestsHistoryAfterFullPublish() throws {
        let m = try makeManager(portalId: "c0ffee000001")
        m.connect()
        
        // Wait for full publish to complete
        waitUntil("full publish") { self.store.batteries["279"] != nil }
        
        // Wait for history to be requested and received
        waitUntil("history data") { 
            // already on the manager's queue here (waitUntil runs the condition via queue.sync), so no nested onQueue
            self.manager?.historyStore.solarDays["278"]?.count == 30 && self.manager?.historyStore.batteryTotals["279"]?.count == 8
        }
        
        // Verify history data
        let solarDays = onQueue { manager?.historyStore.solarDays["278"] }
        let batteryTotals = onQueue { manager?.historyStore.batteryTotals["279"] }
        
        XCTAssertEqual(solarDays?.count, 30, "Should have 30 days of solar history")
        XCTAssertEqual(batteryTotals?.count, 8, "Should have 8 battery history fields")
    }

    func testManualHistoryRequest() throws {
        let expectation = self.expectation(description: "History request completes")
        let m = try makeManager(portalId: "c0ffee000001")
        m.connect()
        
        // Wait for full publish to complete
        waitUntil("full publish") { self.store.batteries["279"] != nil }
        
        // Manually request history
        m.requestHistory()
        
        // Wait for history to be received
        waitUntil("manual history request") { 
            // already on the manager's queue here (waitUntil runs the condition via queue.sync), so no nested onQueue
            self.manager?.historyStore.solarDays["278"]?.count == 30 && self.manager?.historyStore.batteryTotals["279"]?.count == 8
        }
        
        expectation.fulfill()
        waitForExpectations(timeout: 5, handler: nil)
    }
}