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
        // Expected flows:
        // - Solar (1250W) -> Battery (600W)
        // - Inverter (600W) -> Battery (600W) [charging]
        // - Inverter (400W) -> Loads (400W)
        let system = SystemModel(
            batteryPower: 600.0,
            pvPower: 1250.0,
            acConsumptionOnOutput: 400.0,
            acConsumptionOnInput: 0.0
        )
        
        let flows = PowerFlowModel.flows(from: system)
        
        XCTAssertEqual(flows.count, 3)
        
        // Check solar to battery flow
        if let solarFlow = flows.first(where: { $0.from == .solar && $0.to == .battery }) {
            XCTAssertEqual(solarFlow.watts, 1250.0)
        } else {
            XCTFail("Expected solar to battery flow not found")
        }
        
        // Check inverter to battery flow (charging)
        if let chargeFlow = flows.first(where: { $0.from == .inverter && $0.to == .battery }) {
            XCTAssertEqual(chargeFlow.watts, 600.0)
        } else {
            XCTFail("Expected inverter to battery flow not found")
        }
        
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
        
        // Expected flows:
        // - Solar (1250W) -> Battery (1250W)
        // - Inverter (66.56W) -> Battery (66.56W) [charging]
        // - Inverter (1500W) -> Loads (1500W)
        
        XCTAssertEqual(flows.count, 3)
        
        // Check solar to battery flow
        if let solarFlow = flows.first(where: { $0.from == .solar && $0.to == .battery }) {
            XCTAssertEqual(solarFlow.watts, 1250.0, "Solar to battery flow should be 1250W")
        } else {
            XCTFail("Expected solar to battery flow not found")
        }
        
        // Check inverter to battery flow (charging)
        if let chargeFlow = flows.first(where: { $0.from == .inverter && $0.to == .battery }) {
            XCTAssertEqual(chargeFlow.watts, 66.56, "Inverter to battery flow should be 66.56W")
        } else {
            XCTFail("Expected inverter to battery flow not found")
        }
        
        // Check inverter to loads flow
        if let loadFlow = flows.first(where: { $0.from == .inverter && $0.to == .loads }) {
            XCTAssertEqual(loadFlow.watts, 1500.0, "Inverter to loads flow should be 1500W")
        } else {
            XCTFail("Expected inverter to loads flow not found")
        }
    }

    // MARK: - Helper Methods

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
