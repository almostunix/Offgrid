import XCTest
@testable import VictronKit

/// T-16: ConnectionManager against the Mosquitto test broker and fixture replayer (T-11). Never the real Cerbo.
final class ConnectionManagerTests: XCTestCase {
    var broker: TestBroker!
    var replayer: FixtureReplayer!
    var store: LiveDataStore!
    var manager: ConnectionManager?
    let queue = DispatchQueue(label: "ConnectionManagerTests")
    var states: [ConnectionState] = []   // only touched on `queue`

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
            queue.sync {}   // let the disconnect run
        }
        replayer?.stop()
        broker?.stop()
        super.tearDown()
    }

    private func makeManager(portalId: String?, keepalive: TimeInterval = 30) throws -> ConnectionManager {
        var profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: Int(broker.port), useTLS: false)
        profile.portalId = portalId
        let m = try ConnectionManager(profile: profile, liveDataStore: store, keepaliveInterval: keepalive, queue: queue)
        m.onStateChange = { [unowned self] in self.states.append($0) }   // runs on `queue`
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
        XCTFail("timed out waiting for: \(what)")
    }

    func testConnectsAndReceivesFullPublish() throws {
        let m = try makeManager(portalId: "c0ffee000001")
        m.connect()
        waitUntil("battery 279 from the full publish") { self.store.batteries["279"] != nil }
        XCTAssertEqual(onQueue { m.state }, .connected)
        XCTAssertEqual(onQueue { Array(states.prefix(2)) }, [.connecting, .connected])
        XCTAssertEqual(replayer.receivedKeepalives.first, "", "the first keepalive asks for a full republish")
        XCTAssertNotNil(onQueue { store.solarChargers["278"] })
        XCTAssertNotNil(onQueue { store.inverters["276"] })
    }

    func testLearnsPortalIdFromFirstMessage() throws {
        let m = try makeManager(portalId: nil)
        var detected: String?
        m.onPortalIdDetected = { detected = $0 }   // runs on `queue`
        m.connect()
        waitUntil("connected") { m.state == .connected }
        // The Cerbo's own traffic reveals the portal ID; simulate one N/ message until the manager has subscribed.
        let end = Date().addingTimeInterval(5)
        while onQueue({ detected }) == nil && Date() < end {
            replayer.mqtt.publish("N/c0ffee000001/system/0/Serial", withString: #"{"value":"c0ffee000001"}"#, qos: .qos0, retained: false)
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(onQueue { detected }, "c0ffee000001")
        XCTAssertEqual(onQueue { m.portalId }, "c0ffee000001")
        waitUntil("full publish after the portal ID was learned") { self.store.batteries["279"] != nil }
    }

    func testKeepaliveSuppressesRepublishAfterTheFirst() throws {
        let m = try makeManager(portalId: "c0ffee000001", keepalive: 0.3)
        m.connect()
        let end = Date().addingTimeInterval(5)
        while replayer.receivedKeepalives.count < 3 && Date() < end { Thread.sleep(forTimeInterval: 0.05) }
        let keepalives = replayer.receivedKeepalives
        XCTAssertGreaterThanOrEqual(keepalives.count, 3)
        XCTAssertEqual(keepalives.first, "")
        for later in keepalives.dropFirst() { XCTAssertTrue(later.contains("suppress-republish"), later) }
    }

    func testReconnectingWhenTheBrokerGoesAway() throws {
        let m = try makeManager(portalId: "c0ffee000001")
        m.connect()
        waitUntil("connected") { m.state == .connected }
        replayer.stop()
        broker.stop()
        waitUntil("reconnecting") { m.state == .reconnecting }
    }

    func testDisconnectStopsKeepalives() throws {
        let m = try makeManager(portalId: "c0ffee000001", keepalive: 0.2)
        m.connect()
        waitUntil("connected") { m.state == .connected }
        Thread.sleep(forTimeInterval: 0.5)
        m.disconnect()
        waitUntil("idle") { m.state == .idle }
        let count = replayer.receivedKeepalives.count
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(replayer.receivedKeepalives.count, count, "no keepalives after disconnect")
    }

    func testInvalidPortThrows() {
        let profile = ConnectionProfile(name: "Bad", host: "127.0.0.1", port: 0, useTLS: false)
        XCTAssertThrowsError(try ConnectionManager(profile: profile, liveDataStore: LiveDataStore())) { error in
            XCTAssertEqual(error as? ConnectionError, .invalidPort(0))
        }
    }
}
