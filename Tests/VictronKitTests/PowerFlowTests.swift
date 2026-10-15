//
// PowerFlowTests.swift
//
// Tests for PowerFlowModel functionality
//

import XCTest
@testable import VictronKit

final class PowerFlowTests: XCTestCase {

    // MARK: - PowerFlowModel Tests

    func testChargingScenario() {
        // Scenario: Solar producing 1250W, battery charging at 600W, loads consuming 400W
        // Expected flows with DC bus model:
        // - Solar (600W) -> Battery (showing actual charging amount)
        // - Inverter (400W) -> Loads (400W)
        // - Solar (650W) -> Inverter (the rest of the solar)
        // - NO inverter -> battery flow (solar is providing the charging current)
        let system = SystemModel(
            batteryPower: 600.0,
            pvPower: 1250.0,
            acConsumptionOnOutput: 400.0,
            acConsumptionOnInput: 0.0
        )
        
        let flows = PowerFlowModel.flows(from: system)
        
        XCTAssertEqual(flows.count, 3)
        
        // Check solar to battery flow (should show charging amount, not full solar)
        if let solarFlow = flows.first(where: { $0.from == .solar && $0.to == .battery }) {
            XCTAssertEqual(solarFlow.watts, 600.0)
        } else {
            XCTFail("Expected solar to battery flow not found")
        }
        
        XCTAssertEqual(flows.first(where: { $0.from == .solar && $0.to == .inverter })?.watts, 650.0)

        // Check that there's NO inverter to battery flow (this was the bug)
        let inverterToBatteryFlows = flows.filter { $0.from == .inverter && $0.to == .battery }
        XCTAssertEqual(inverterToBatteryFlows.count, 0, "Should not have inverter to battery flow when solar is charging")
        
        // Check inverter to loads flow
        if let loadFlow = flows.first(where: { $0.from == .inverter && $0.to == .loads }) {
            XCTAssertEqual(loadFlow.watts, 400.0)
        } else {
            XCTFail("Expected inverter to loads flow not found")
        }
    }

    func testDischargingScenario() {
        // Scenario: No solar, battery discharging at 800W, loads consuming 750W
        // Expected flows:
        // - Battery (800W) -> Inverter (800W) [discharging]
        // - Inverter (750W) -> Loads (750W)
        let system = SystemModel(
            batteryPower: -800.0,
            pvPower: nil,
            acConsumptionOnOutput: 750.0,
            acConsumptionOnInput: 0.0
        )
        
        let flows = PowerFlowModel.flows(from: system)
        
        XCTAssertEqual(flows.count, 2)
        
        // Check battery to inverter flow (discharging)
        if let dischargeFlow = flows.first(where: { $0.from == .battery && $0.to == .inverter }) {
            XCTAssertEqual(dischargeFlow.watts, 800.0)
        } else {
            XCTFail("Expected battery to inverter flow not found")
        }
        
        // Check inverter to loads flow
        if let loadFlow = flows.first(where: { $0.from == .inverter && $0.to == .loads }) {
            XCTAssertEqual(loadFlow.watts, 750.0)
        } else {
            XCTFail("Expected inverter to loads flow not found")
        }
    }

    func testTinyValuesAreSkipped() {
        // Values under 1W should be skipped
        let system = SystemModel(
            batteryPower: 0.3,
            pvPower: 0.5,
            acConsumptionOnOutput: 0.8,
            acConsumptionOnInput: 0.0
        )
        
        let flows = PowerFlowModel.flows(from: system)
        
        XCTAssertTrue(flows.isEmpty, "Expected no flows for values under 1W")
    }

    func testNilValuesAreSkipped() {
        // Nil values should be skipped
        let system = SystemModel(
            batteryPower: nil,
            pvPower: nil,
            acConsumptionOnOutput: nil,
            acConsumptionOnInput: nil
        )
        
        let flows = PowerFlowModel.flows(from: system)
        
        XCTAssertTrue(flows.isEmpty, "Expected no flows for nil values")
    }

    func testSystemFixtureScenario() {
        // Test with the system.json fixture data
        let store = LiveDataStore()
        let topicParser = TopicParser()
        
        // Load fixture data
        let fixtureData = loadSystemFixture()
        
        // Parse and update store with fixture messages
        for messageTuple in fixtureData {
            if let message = topicParser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) {
                store.update(with: message)
            }
        }
        
        // Expected values from fixture:
        // - pvPower: 1250
        // - batteryPower: 66.56
        // - acConsumptionOnOutput: 1180
        // - acConsumptionOnInput: 320
        // - acConsumptionTotal: 1500
        
        let flows = PowerFlowModel.flows(from: store.system)
        
        // Expected flows with DC bus model:
        // - Solar (66.56W) -> Battery (showing actual charging amount, not full solar)
        // - Inverter (1500W) -> Loads (1500W)
        // - NO inverter -> battery flow (this was the bug)
        
        XCTAssertEqual(flows.count, 3)
        
        // Check solar to battery flow (should show charging amount, not full solar)
        if let solarFlow = flows.first(where: { $0.from == .solar && $0.to == .battery }) {
            XCTAssertEqual(solarFlow.watts, 66.56, "Solar to battery flow should show charging amount 66.56W, not full solar 1250W")
        } else {
            XCTFail("Expected solar to battery flow not found")
        }
        
        // The rest of the solar (1250 - 66.56) goes to the inverter, which is inverting
        XCTAssertEqual(flows.first(where: { $0.from == .solar && $0.to == .inverter })?.watts ?? 0, 1250.0 - 66.56, accuracy: 0.001)
        XCTAssertEqual(PowerFlowModel.dcToInverter(from: store.system), 1250.0 - 66.56, accuracy: 0.001)

        // Check that there's NO inverter to battery flow (this was the bug)
        let inverterToBatteryFlows = flows.filter { $0.from == .inverter && $0.to == .battery }
        XCTAssertEqual(inverterToBatteryFlows.count, 0, "Should not have inverter to battery flow when solar is charging")
        
        // Check inverter to loads flow
        if let loadFlow = flows.first(where: { $0.from == .inverter && $0.to == .loads }) {
            XCTAssertEqual(loadFlow.watts, 1500.0, "Inverter to loads flow should be 1500W")
        } else {
            XCTFail("Expected inverter to loads flow not found")
        }
    }

    // MARK: - Helper Methods

    // MARK: - DC side split (T-63)

    private func watts(_ flows: [PowerFlow]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: flows.map { ($0.from.rawValue + ">" + $0.to.rawValue, $0.watts) })
    }

    func testChargingFromACWithoutSolar() {
        let flows = PowerFlowModel.flows(from: SystemModel(batteryPower: 500, pvPower: 0, acConsumptionOnOutput: 0, acConsumptionOnInput: 0))
        XCTAssertEqual(watts(flows), ["inverter>battery": 500])
        XCTAssertEqual(PowerFlowModel.dcToInverter(from: SystemModel(batteryPower: 500, pvPower: 0)), -500)
    }

    func testSolarCoversPartOfTheCharging() {
        let flows = PowerFlowModel.flows(from: SystemModel(batteryPower: 500, pvPower: 200, acConsumptionOnOutput: 0, acConsumptionOnInput: 0))
        XCTAssertEqual(watts(flows), ["solar>battery": 200, "inverter>battery": 300])
    }

    func testDischargingWhileSolarProduces() {
        let flows = PowerFlowModel.flows(from: SystemModel(batteryPower: -400, pvPower: 300, acConsumptionOnOutput: 700, acConsumptionOnInput: 0))
        XCTAssertEqual(watts(flows), ["solar>inverter": 300, "battery>inverter": 400, "inverter>loads": 700])
        XCTAssertEqual(PowerFlowModel.dcToInverter(from: SystemModel(batteryPower: -400, pvPower: 300)), 700)
    }

    private func loadSystemFixture() -> [(topic: String, payload: [String: Any])] {
        guard let url = Bundle.module.url(forResource: "system", withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            XCTFail("Failed to load system fixture")
            return []
        }
        
        return messages.compactMap { message -> (topic: String, payload: [String: Any])? in
            guard let topic = message["topic"] as? String,
                  let payload = message["payload"] as? [String: Any] else {
                return nil
            }
            return (topic, payload)
        }
    }
}
