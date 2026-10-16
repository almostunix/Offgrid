//
// LiveOverviewTests.swift
//
// Tests for LiveOverview view functionality and LiveOverviewModel.
//

import XCTest
@testable import VictronKit

final class LiveOverviewTests: XCTestCase {
    var store: LiveDataStore!
    
    override func setUp() {
        super.setUp()
        store = LiveDataStore()
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    // MARK: - LiveOverviewModel Tests
    
    func testChargeStateFromBatteryPower() {
        // Test charging state
        let chargingState = ChargeState.from(batteryPower: 1000.0)
        XCTAssertEqual(chargingState, .charging)
        
        // Test discharging state
        let dischargingState = ChargeState.from(batteryPower: -500.0)
        XCTAssertEqual(dischargingState, .discharging)
        
        // Test idle state
        let idleState = ChargeState.from(batteryPower: 0.0)
        XCTAssertEqual(idleState, .idle)
        
        // Test unknown state
        let unknownState = ChargeState.from(batteryPower: nil)
        XCTAssertEqual(unknownState, .unknown)
    }
    
    func testDeviceStateFromRawState() {
        // Test various device states
        XCTAssertEqual(DeviceState.from(rawState: 0), .off)
        XCTAssertEqual(DeviceState.from(rawState: 1), .lowPower)
        XCTAssertEqual(DeviceState.from(rawState: 2), .fault)
        XCTAssertEqual(DeviceState.from(rawState: 3), .bulk)
        XCTAssertEqual(DeviceState.from(rawState: 4), .absorption)
        XCTAssertEqual(DeviceState.from(rawState: 5), .float)
        XCTAssertEqual(DeviceState.from(rawState: 6), .storage)
        XCTAssertEqual(DeviceState.from(rawState: 7), .equalize)
        XCTAssertEqual(DeviceState.from(rawState: 8), .passthru)
        XCTAssertEqual(DeviceState.from(rawState: 9), .inverting)
        XCTAssertEqual(DeviceState.from(rawState: 10), .powerAssist)
        XCTAssertEqual(DeviceState.from(rawState: 11), .powerSupply)
        XCTAssertEqual(DeviceState.from(rawState: 244), .sustain)
        XCTAssertEqual(DeviceState.from(rawState: 252), .externalControl)
        
        // Test unknown state
        XCTAssertEqual(DeviceState.from(rawState: 999), .unknown)
        XCTAssertEqual(DeviceState.from(rawState: nil), .unknown)
    }
    
    func testPowerFormatter() {
        // Test power formatting
        XCTAssertEqual(PowerFormatter.formatPower(1000), "1.0 kW")
        XCTAssertEqual(PowerFormatter.formatPower(1500), "1.5 kW")
        XCTAssertEqual(PowerFormatter.formatPower(999), "999 W")
        XCTAssertEqual(PowerFormatter.formatPower(100), "100 W")
        XCTAssertEqual(PowerFormatter.formatPower(-1500), "-1.5 kW")
        XCTAssertEqual(PowerFormatter.formatPower(-500), "-500 W")
    }
    
    func testTimeFormatter() {
        // Test time formatting
        XCTAssertEqual(TimeFormatter.formatTimeToGo(3600), "1:00h")
        XCTAssertEqual(TimeFormatter.formatTimeToGo(3660), "1:01h")
        XCTAssertEqual(TimeFormatter.formatTimeToGo(7200), "2:00h")
        XCTAssertEqual(TimeFormatter.formatTimeToGo(3600 + 60), "1:01h")
    }
    
    func testBatteryStatusHelper() {
        let system = SystemModel(batterySoc: 80.0, batteryPower: -1000.0, timeToGo: 7200.0)
        let battery = BatteryModel(power: -800.0, soc: 75.0, timeToGo: 3600.0)
        let batteries = ["test": battery]
        
        // Test with system data
        XCTAssertEqual(BatteryStatusHelper.batterySoc(from: system, batteries: [:]), 80.0)
        XCTAssertEqual(BatteryStatusHelper.timeToGo(from: system, batteries: [:]), 7200.0)
        XCTAssertEqual(BatteryStatusHelper.chargeState(from: system, batteries: [:]), .discharging)
        
        // Test with battery data when system data is missing
        let emptySystem = SystemModel()
        XCTAssertEqual(BatteryStatusHelper.batterySoc(from: emptySystem, batteries: batteries), 75.0)
        XCTAssertEqual(BatteryStatusHelper.timeToGo(from: emptySystem, batteries: batteries), 3600.0)
        XCTAssertEqual(BatteryStatusHelper.chargeState(from: emptySystem, batteries: batteries), .discharging)
        
        // Test with no data
        XCTAssertNil(BatteryStatusHelper.batterySoc(from: emptySystem, batteries: [:]))
        XCTAssertNil(BatteryStatusHelper.timeToGo(from: emptySystem, batteries: [:]))
        XCTAssertEqual(BatteryStatusHelper.chargeState(from: emptySystem, batteries: [:]), .unknown)
    }
    
    // MARK: - LiveOverview Data Flow Tests
    
    func testLiveOverviewDataFlow() throws {
        // Test that LiveOverview can display data from LiveDataStore
        let topic = "N/c0ffee000001/system/0/Dc/Battery/Soc"
        let payload: [String: Any] = ["value": 78.5]
        
        let topicParser = TopicParser()
        guard let message = topicParser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        
        // Verify data is stored correctly
        XCTAssertEqual(store.system.batterySoc, 78.5)
    }
    
    func testLiveOverviewWithCompleteData() throws {
        // Test with a complete set of data for the overview
        let messages = [
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": -1250.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1500.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 851.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 300.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/TimeToGo", payload: ["value": 12345.0]),
            (topic: "N/c0ffee000001/battery/279/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/battery/279/State", payload: ["value": 2]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 5]),
            (topic: "N/c0ffee000001/vebus/276/State", payload: ["value": 9])
        ]
        
        let topicParser = TopicParser()
        for messageTuple in messages {
            guard let message = topicParser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        // Verify all data is stored correctly
        XCTAssertEqual(store.system.batterySoc, 78.5)
        XCTAssertEqual(store.system.batteryPower, -1250.0)
        XCTAssertEqual(store.system.pvPower, 1500.0)
        XCTAssertEqual(store.system.acConsumptionOnOutput, 851.0)
        XCTAssertEqual(store.system.acConsumptionOnInput, 300.0)
        XCTAssertEqual(store.system.timeToGo, 12345.0)
        
        // Battery state should be 2 (Fault)
        XCTAssertEqual(store.batteries["279"]?.soc, 78.5)
        
        // Solar charger state should be 5 (Float)
        XCTAssertEqual(store.solarChargers["278"]?.state, 5)
        
        // Inverter state should be 9 (Inverting)
        XCTAssertEqual(store.inverters["276"]?.state, 9)
    }

    // MARK: - formatTimeToGo Tests

    func testFormatTimeToGoNormalValues() {
        // Test normal values
        XCTAssertEqual(TimeFormatter.formatTimeToGo(3600), "1:00h")  // 1 hour
        XCTAssertEqual(TimeFormatter.formatTimeToGo(9000), "2:30h")  // 2 hours 30 minutes
        XCTAssertEqual(TimeFormatter.formatTimeToGo(0), "0:00h")     // 0 hours
    }

    func testFormatTimeToGoEdgeCases() {
        // Test edge cases that should return "–"
        XCTAssertEqual(TimeFormatter.formatTimeToGo(.infinity), "–")
        XCTAssertEqual(TimeFormatter.formatTimeToGo(.nan), "–")
        XCTAssertEqual(TimeFormatter.formatTimeToGo(1e300), "–")     // Huge value
        XCTAssertEqual(TimeFormatter.formatTimeToGo(-5), "–")        // Negative value
        
        // Test maximum allowed value (just under 100 days)
        let maxDays = Double(100 * 24 * 3600)
        XCTAssertEqual(TimeFormatter.formatTimeToGo(maxDays - 3600), String(format: "%d:%02dh", Int(maxDays / 3600) - 1, 0))
        
        // Test value over 100 days
        XCTAssertEqual(TimeFormatter.formatTimeToGo(maxDays + 3600), "–")
    }
}