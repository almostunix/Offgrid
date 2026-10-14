//
// FullPublishIntegrationTests.swift
//
// Integration tests that feed the full-publish fixture and check every model field.
//

import XCTest
@testable import VictronKit

final class FullPublishIntegrationTests: XCTestCase {
    var parser: TopicParser!
    var store: LiveDataStore!
    
    override func setUp() {
        super.setUp()
        parser = TopicParser()
        store = LiveDataStore()
    }
    
    override func tearDown() {
        parser = nil
        store = nil
        super.tearDown()
    }
    
    func testFullPublishFixture() throws {
        // Load and parse all fixture files to simulate a full publish
        let fixtureFiles = ["system", "battery", "solarcharger", "vebus"]
        
        for filename in fixtureFiles {
            let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "Fixtures")
            XCTAssertNotNil(url, "Could not find fixture file: \(filename).json")
            
            guard let url = url else { continue }
            
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            XCTAssertNotNil(json, "JSON should be a dictionary for file: \(filename).json")
            
            guard let json = json, let messages = json["messages"] as? [[String: Any]] else {
                XCTFail("Invalid fixture format for file: \(filename).json")
                continue
            }
            
            // Update store with all messages from this fixture
            for messageDict in messages {
                guard let topic = messageDict["topic"] as? String,
                      let payload = messageDict["payload"] as? [String: Any] else {
                    XCTFail("Invalid message format in file: \(filename).json")
                    continue
                }
                
                guard let message = parser.parseMessage(topic: topic, payload: payload) else {
                    XCTFail("Should be able to parse message: \(topic) in file: \(filename).json")
                    continue
                }
                
                store.update(with: message)
            }
        }
        
        // Verify portal ID was detected
        XCTAssertEqual(store.portalId, "c0ffee000001")
        
        // MARK: - System Model Field Checks
        
        // Check every field in SystemModel
        XCTAssertNotNil(store.system, "System model should exist")
        XCTAssertEqual(store.system.serial, "HQ212200XA", "System serial should match")
        XCTAssertEqual(store.system.batterySoc, 78.5, "System battery SoC should match")
        XCTAssertEqual(store.system.batteryPower, 66.56, "System battery power should match")
        XCTAssertEqual(store.system.pvPower, 1250, "System PV power should match")
        XCTAssertEqual(store.system.acConsumptionTotal, 1500, "System AC consumption should match")
        XCTAssertEqual(store.system.timeToGo, 3600, "System time to go should match")
        
        // MARK: - Battery Model Field Checks
        
        // Check every field in BatteryModel
        let battery = store.batteries["279"]
        XCTAssertNotNil(battery, "Battery with ID 279 should exist")
        XCTAssertEqual(battery?.productName, "Victron SmartShunt 500A", "Battery product name should match")
        XCTAssertEqual(battery?.voltage, 12.8, "Battery voltage should match")
        XCTAssertEqual(battery?.current, 5.2, "Battery current should match")
        XCTAssertEqual(battery?.power, 66.56, "Battery power should match")
        XCTAssertEqual(battery?.soc, 78.5, "Battery SoC should match")
        XCTAssertEqual(battery?.timeToGo, 3600, "Battery time to go should match")
        XCTAssertEqual(battery?.consumedAmphours, 250.5, "Battery consumed amp-hours should match")
        
        // MARK: - Solar Charger Model Field Checks
        
        // Check every field in SolarChargerModel
        let solarCharger = store.solarChargers["278"]
        XCTAssertNotNil(solarCharger, "Solar charger with ID 278 should exist")
        XCTAssertEqual(solarCharger?.productName, "MPPT 150/70", "Solar charger product name should match")
        XCTAssertEqual(solarCharger?.pvVoltage, 24.5, "Solar charger PV voltage should match")
        XCTAssertEqual(solarCharger?.yieldPower, 150, "Solar charger yield power should match")
        XCTAssertEqual(solarCharger?.dcVoltage, 13.2, "Solar charger DC voltage should match")
        XCTAssertEqual(solarCharger?.dcCurrent, 11.5, "Solar charger DC current should match")
        XCTAssertEqual(solarCharger?.state, 4, "Solar charger state should match")
        
        // MARK: - Inverter Model Field Checks
        
        // Check every field in InverterModel
        let inverter = store.inverters["276"]
        XCTAssertNotNil(inverter, "Inverter with ID 276 should exist")
        XCTAssertEqual(inverter?.productName, "MultiPlus-II 48/5000", "Inverter product name should match")
        XCTAssertEqual(inverter?.acInputPower, 1200, "Inverter AC input power should match")
        XCTAssertEqual(inverter?.acOutputPower, 851, "Inverter AC output power should match")
        XCTAssertEqual(inverter?.mode, 3, "Inverter mode should match")
        XCTAssertEqual(inverter?.state, 2, "Inverter state should match")
        
        // MARK: - Data Integrity Checks
        
        // Verify that related fields have consistent values
        // System battery SoC should match battery SoC
        XCTAssertEqual(store.system.batterySoc, battery?.soc, "System battery SoC should match battery SoC")
        
        // System battery power should match battery power
        XCTAssertEqual(store.system.batteryPower, battery?.power, "System battery power should match battery power")
        
        // Verify that all expected devices are present
        XCTAssertEqual(store.batteries.count, 1, "Should have 1 battery")
        XCTAssertEqual(store.solarChargers.count, 1, "Should have 1 solar charger")
        XCTAssertEqual(store.inverters.count, 1, "Should have 1 inverter")
    }
    
    func testFullPublishWithMultipleDevices() throws {
        // Test with multiple devices of each type
        let messages = [
            // System
            (topic: "N/c0ffee000001/system/0/Serial", payload: ["value": "HQ212200XA"]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            
            // Battery 1
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "SmartShunt 500A"]),
            (topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", payload: ["value": 12.8]),
            
            // Battery 2
            (topic: "N/c0ffee000001/battery/280/ProductName", payload: ["value": "SmartShunt 300A"]),
            (topic: "N/c0ffee000001/battery/280/Dc/0/Voltage", payload: ["value": 12.7]),
            
            // Solar Charger 1
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/278/Pv/V", payload: ["value": 24.5]),
            
            // Solar Charger 2
            (topic: "N/c0ffee000001/solarcharger/279/ProductName", payload: ["value": "MPPT 100/30"]),
            (topic: "N/c0ffee000001/solarcharger/279/Pv/V", payload: ["value": 18.2]),
            
            // Inverter 1
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/276/Ac/Out/L1/P", payload: ["value": 851]),
            
            // Inverter 2
            (topic: "N/c0ffee000001/vebus/277/ProductName", payload: ["value": "MultiPlus-II 24/3000"]),
            (topic: "N/c0ffee000001/vebus/277/Ac/Out/L1/P", payload: ["value": 500])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        // Verify multiple devices are tracked correctly
        XCTAssertEqual(store.batteries.count, 2, "Should have 2 batteries")
        XCTAssertEqual(store.solarChargers.count, 2, "Should have 2 solar chargers")
        XCTAssertEqual(store.inverters.count, 2, "Should have 2 inverters")
        
        // Verify each device has correct data
        XCTAssertEqual(store.batteries["279"]?.productName, "SmartShunt 500A")
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.8)
        XCTAssertEqual(store.batteries["280"]?.productName, "SmartShunt 300A")
        XCTAssertEqual(store.batteries["280"]?.voltage, 12.7)
        
        XCTAssertEqual(store.solarChargers["278"]?.productName, "MPPT 150/70")
        XCTAssertEqual(store.solarChargers["278"]?.pvVoltage, 24.5)
        XCTAssertEqual(store.solarChargers["279"]?.productName, "MPPT 100/30")
        XCTAssertEqual(store.solarChargers["279"]?.pvVoltage, 18.2)
        
        XCTAssertEqual(store.inverters["276"]?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(store.inverters["276"]?.acOutputPower, 851)
        XCTAssertEqual(store.inverters["277"]?.productName, "MultiPlus-II 24/3000")
        XCTAssertEqual(store.inverters["277"]?.acOutputPower, 500)
    }
    
    func testFullPublishUpdatesOverTime() throws {
        // Test that the store correctly updates values over time
        
        // First update
        let message1 = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", 
                                           payload: ["value": 12.8])
        guard let message1 = message1 else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message1)
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.8)
        
        // Second update with different value
        let message2 = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", 
                                           payload: ["value": 12.9])
        guard let message2 = message2 else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message2)
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.9)
        
        // Third update with different field
        let message3 = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Dc/0/Current", 
                                           payload: ["value": 5.5])
        guard let message3 = message3 else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message3)
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.9) // Should remain unchanged
        XCTAssertEqual(store.batteries["279"]?.current, 5.5) // Should be updated
    }
}
