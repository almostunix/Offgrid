import XCTest
@testable import VictronKit

/// T-46: DemoPlayer tests - offline playback into the data store
final class DemoPlayerTests: XCTestCase {
    var store: LiveDataStore!
    var historyStore: HistoryStore!
    let queue = DispatchQueue(label: "DemoPlayerTests")
    
    override func setUpWithError() throws {
        store = LiveDataStore()
        historyStore = HistoryStore()
    }
    
    override func tearDown() {
        store = nil
        historyStore = nil
    }
    
    private func loadFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
    
    /// Polls `condition` (evaluated on the test queue) until it holds or `timeout` passes.
    private func waitUntil(_ what: String, timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTFail("timed out waiting for: \(what)")
    }
    
    // Test load and start playback
    func testLoadAndStartPlayback() throws {
        // Load fixture recordings
        let batteryData = try loadFixture("battery")
        let solarChargerData = try loadFixture("solarcharger")
        let inverterData = try loadFixture("vebus")
        
        let player = DemoPlayer(store: store, historyStore: historyStore, interval: 0.05, queue: queue)
        
        // Load recordings
        try player.load([batteryData, solarChargerData, inverterData])
        
        // Start playback
        player.start()
        
        // Verify isPlaying is true
        XCTAssertTrue(player.isPlaying)
        
        // Wait for initial full publish
        waitUntil("initial full publish") {
            !self.store.batteries.isEmpty && 
            !self.store.solarChargers.isEmpty && 
            !self.store.inverters.isEmpty
        }
        
        // Verify devices are present with expected values
        XCTAssertEqual(store.batteries.count, 1)
        XCTAssertEqual(store.solarChargers.count, 1)
        XCTAssertEqual(store.inverters.count, 1)
        
        // Check battery values from fixture
        let battery = store.batteries["279"]
        XCTAssertNotNil(battery)
        XCTAssertEqual(battery?.productName, "Victron SmartShunt 500A")
        XCTAssertEqual(battery?.voltage, 12.8)
        XCTAssertEqual(battery?.current, 5.2)
        XCTAssertEqual(battery?.power, 66.56)
        XCTAssertEqual(battery?.soc, 78.5)
        
        // Check solar charger values from fixture
        let solarCharger = store.solarChargers["278"]
        XCTAssertNotNil(solarCharger)
        XCTAssertEqual(solarCharger?.productName, "MPPT 150/70")
        XCTAssertEqual(solarCharger?.pvVoltage, 24.5)
        XCTAssertEqual(solarCharger?.yieldPower, 150)
        
        // Check inverter values from fixture
        let inverter = store.inverters["276"]
        XCTAssertNotNil(inverter)
        XCTAssertEqual(inverter?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(inverter?.acInputPower, 1200)
        XCTAssertEqual(inverter?.acOutputPower, 851)
    }
    
    func testVariationStaysWithinBounds() throws {
        // Load fixture recordings
        let batteryData = try loadFixture("battery")
        let solarChargerData = try loadFixture("solarcharger")
        
        let player = DemoPlayer(store: store, historyStore: historyStore, interval: 0.05, queue: queue)
        try player.load([batteryData, solarChargerData])
        player.start()
        
        // Wait for initial values
        waitUntil("initial values") {
            self.store.batteries["279"]?.power != nil
        }
        
        let originalBatteryPower = store.batteries["279"]?.power ?? 0
        let originalSoc = store.batteries["279"]?.soc ?? 0
        
        // Wait for a few ticks to see variation
        var startTime = Date()
        waitUntil("variation to occur") {
            Date().timeIntervalSince(startTime) > 0.3
        }
        
        // Check that battery power has changed but stays within ±5% of original
        let currentBatteryPower = store.batteries["279"]?.power ?? 0
        let powerDifference = abs(currentBatteryPower - originalBatteryPower)
        let powerPercentageChange = powerDifference / originalBatteryPower
        
        XCTAssertGreaterThan(powerDifference, 0, "Power should have changed")
        XCTAssertLessThan(powerPercentageChange, 0.05, "Power change should be less than 5%")
        
        // Check that SoC stays within 0...100
        let currentSoc = store.batteries["279"]?.soc ?? 0
        XCTAssertGreaterThanOrEqual(currentSoc, 0, "SoC should be >= 0")
        XCTAssertLessThanOrEqual(currentSoc, 100, "SoC should be <= 100")
    }
    
    func testStopPlayback() throws {
        // Load fixture recordings
        let batteryData = try loadFixture("battery")
        
        let player = DemoPlayer(store: store, historyStore: historyStore, interval: 0.05, queue: queue)
        try player.load([batteryData])
        player.start()
        
        // Wait for initial values
        waitUntil("initial values") {
            self.store.batteries["279"]?.power != nil
        }
        
        let initialPower = store.batteries["279"]?.power ?? 0
        
        // Stop playback
        player.stop()
        XCTAssertFalse(player.isPlaying)
        
        // Wait a bit to ensure no more updates
        Thread.sleep(forTimeInterval: 0.2)
        
        // Power should remain unchanged
        let finalPower = store.batteries["279"]?.power ?? 0
        XCTAssertEqual(finalPower, initialPower, "Power should not change after stop")
    }
    
    func testMultipleRecordings() throws {
        // Load multiple fixture recordings
        let batteryData = try loadFixture("battery")
        let solarChargerData = try loadFixture("solarcharger")
        let inverterData = try loadFixture("vebus")
        let systemData = try loadFixture("system")
        
        let player = DemoPlayer(store: store, historyStore: historyStore, interval: 0.05, queue: queue)
        try player.load([batteryData, solarChargerData, inverterData, systemData])
        player.start()
        
        // Wait for all devices to be present
        waitUntil("all devices present") {
            self.store.batteries.count == 1 && 
            self.store.solarChargers.count == 1 && 
            self.store.inverters.count == 1 &&
            self.store.system.serial != nil
        }
        
        // Verify all devices are present
        XCTAssertEqual(store.batteries.count, 1)
        XCTAssertEqual(store.solarChargers.count, 1)
        XCTAssertEqual(store.inverters.count, 1)
        XCTAssertNotNil(store.system.serial)
    }
    
    func testDemoFilesCanBeLoadedFromBundle() throws {
        // Test that demo files can be loaded from the bundle
        let recordingNames = ["system", "battery", "solarcharger", "vebus", "full_publish_completed", "solarcharger_history", "battery_history", "alarms"]
        
        for name in recordingNames {
            let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            XCTAssertNotNil(url, "Could not find demo fixture file: \(name).json")
            
            guard let url = url else { continue }
            
            let data = try Data(contentsOf: url)
            XCTAssertNotNil(data, "Could not load data from file: \"(name).json\"")
            
            // Verify it can be parsed as a Recording
            let recording = Recording(data: data)
            XCTAssertNotNil(recording, "Could not parse recording from file: \"(name).json\"")
            
            guard let recording = recording else { continue }
            
            // Verify portal ID
            XCTAssertEqual(recording.portalId, "c0ffee000001")
            
            // Verify messages are present
            XCTAssertGreaterThan(recording.messages.count, 0, "Recording should have messages")
        }
    }
    
    func testDemoPlayerWithAllDemoFiles() throws {
        // Load all demo files
        let recordingNames = ["system", "battery", "solarcharger", "vebus", "full_publish_completed", "solarcharger_history", "battery_history", "alarms"]
        
        var recordings: [Data] = []
        for name in recordingNames {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            let data = try Data(contentsOf: url)
            recordings.append(data)
        }
        
        let player = DemoPlayer(store: store, historyStore: historyStore, interval: 0.05, queue: queue)
        try player.load(recordings)
        player.start()
        
        // Wait for all data to be loaded
        waitUntil("all demo data loaded") {
            self.store.batteries.count >= 1 && 
            self.store.solarChargers.count >= 1 && 
            self.store.inverters.count >= 1 &&
            self.store.system.serial != nil &&
            !self.store.alarmStore.active.isEmpty
        }
        
        // Verify all data is present
        XCTAssertEqual(store.batteries.count, 1)
        XCTAssertEqual(store.solarChargers.count, 1)
        XCTAssertEqual(store.inverters.count, 1)
        XCTAssertNotNil(store.system.serial)
        XCTAssertGreaterThan(store.alarmStore.active.count, 0, "Should have active alarms")
        
        // Verify specific values
        let battery = store.batteries["279"]
        XCTAssertNotNil(battery)
        XCTAssertEqual(battery?.productName, "Victron SmartShunt 500A")
        
        let solarCharger = store.solarChargers["278"]
        XCTAssertNotNil(solarCharger)
        XCTAssertEqual(solarCharger?.productName, "MPPT 150/70")
        
        let inverter = store.inverters["276"]
        XCTAssertNotNil(inverter)
        XCTAssertEqual(inverter?.productName, "MultiPlus-II 48/5000")
    }
}
