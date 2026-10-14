//
// LiveDataStoreTests.swift
//
// Tests for LiveDataStore functionality.
//

import XCTest
@testable import VictronKit

final class LiveDataStoreTests: XCTestCase {
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
    
    // MARK: - Portal ID Tests
    
    func testPortalIdDetection() throws {
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload: [String: Any] = ["value": "HQ212200XA"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.portalId, "c0ffee000001")
    }
    
    // MARK: - System Model Tests
    
    func testSystemModelSerial() throws {
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload: [String: Any] = ["value": "HQ212200XA"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.serial, "HQ212200XA")
    }
    
    func testSystemModelBatterySoc() throws {
        let topic = "N/c0ffee000001/system/0/Dc/Battery/Soc"
        let payload: [String: Any] = ["value": 78.5]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.batterySoc, 78.5)
    }
    
    func testSystemModelBatteryPower() throws {
        let topic = "N/c0ffee000001/system/0/Dc/Battery/Power"
        let payload: [String: Any] = ["value": 66.56]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.batteryPower, 66.56)
    }
    
    func testSystemModelPvPower() throws {
        let topic = "N/c0ffee000001/system/0/Dc/Pv/Power"
        let payload: [String: Any] = ["value": 1250]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.pvPower, 1250)
    }
    
    func testSystemModelAcConsumptionOnOutput() throws {
        let topic = "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power"
        let payload: [String: Any] = ["value": 1180]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.acConsumptionOnOutput, 1180)
    }
    
    func testSystemModelAcConsumptionOnInput() throws {
        let topic = "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power"
        let payload: [String: Any] = ["value": 320]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.acConsumptionOnInput, 320)
    }
    
    func testSystemModelAcConsumptionTotal() throws {
        let topic1 = "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power"
        let payload1: [String: Any] = ["value": 1180]
        
        let topic2 = "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power"
        let payload2: [String: Any] = ["value": 320]
        
        guard let message1 = parser.parseMessage(topic: topic1, payload: payload1) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        guard let message2 = parser.parseMessage(topic: topic2, payload: payload2) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message1)
        store.update(with: message2)
        XCTAssertEqual(store.system.acConsumptionTotal, 1500)
    }
    
    func testSystemModelTimeToGo() throws {
        let topic = "N/c0ffee000001/system/0/Dc/Battery/TimeToGo"
        let payload: [String: Any] = ["value": 3600]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.timeToGo, 3600)
    }
    
    func testSystemModelComplete() throws {
        // Test that all system fields can be populated
        let messages = [
            (topic: "N/c0ffee000001/system/0/Serial", payload: ["value": "HQ212200XA"]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": 66.56]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1250]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 1180]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 320]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/TimeToGo", payload: ["value": 3600])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        XCTAssertEqual(store.system.batterySoc, 78.5)
        XCTAssertEqual(store.system.batteryPower, 66.56)
        XCTAssertEqual(store.system.pvPower, 1250)
        XCTAssertEqual(store.system.acConsumptionOnOutput, 1180)
        XCTAssertEqual(store.system.acConsumptionOnInput, 320)
        XCTAssertEqual(store.system.acConsumptionTotal, 1500)
        XCTAssertEqual(store.system.timeToGo, 3600)
    }
    
    // MARK: - Battery Model Tests
    
    func testBatteryModelProductName() throws {
        let topic = "N/c0ffee000001/battery/279/ProductName"
        let payload: [String: Any] = ["value": "Victron SmartShunt 500A"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.productName, "Victron SmartShunt 500A")
    }
    
    func testBatteryModelVoltage() throws {
        let topic = "N/c0ffee000001/battery/279/Dc/0/Voltage"
        let payload: [String: Any] = ["value": 12.8]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.8)
    }
    
    func testBatteryModelCurrent() throws {
        let topic = "N/c0ffee000001/battery/279/Dc/0/Current"
        let payload: [String: Any] = ["value": 5.2]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.current, 5.2)
    }
    
    func testBatteryModelPower() throws {
        let topic = "N/c0ffee000001/battery/279/Dc/0/Power"
        let payload: [String: Any] = ["value": 66.56]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.power, 66.56)
    }
    
    func testBatteryModelSoc() throws {
        let topic = "N/c0ffee000001/battery/279/Soc"
        let payload: [String: Any] = ["value": 78.5]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.soc, 78.5)
    }
    
    func testBatteryModelTimeToGo() throws {
        let topic = "N/c0ffee000001/battery/279/TimeToGo"
        let payload: [String: Any] = ["value": 3600]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.timeToGo, 3600)
    }
    
    func testBatteryModelConsumedAmphours() throws {
        let topic = "N/c0ffee000001/battery/279/ConsumedAmphours"
        let payload: [String: Any] = ["value": 250.5]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.batteries["279"]?.consumedAmphours, 250.5)
    }
    
    func testBatteryModelComplete() throws {
        // Test that all battery fields can be populated
        let messages = [
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "Victron SmartShunt 500A"]),
            (topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", payload: ["value": 12.8]),
            (topic: "N/c0ffee000001/battery/279/Dc/0/Current", payload: ["value": 5.2]),
            (topic: "N/c0ffee000001/battery/279/Dc/0/Power", payload: ["value": 66.56]),
            (topic: "N/c0ffee000001/battery/279/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/battery/279/TimeToGo", payload: ["value": 3600]),
            (topic: "N/c0ffee000001/battery/279/ConsumedAmphours", payload: ["value": 250.5])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        let battery = store.batteries["279"]
        XCTAssertNotNil(battery)
        XCTAssertEqual(battery?.productName, "Victron SmartShunt 500A")
        XCTAssertEqual(battery?.voltage, 12.8)
        XCTAssertEqual(battery?.current, 5.2)
        XCTAssertEqual(battery?.power, 66.56)
        XCTAssertEqual(battery?.soc, 78.5)
        XCTAssertEqual(battery?.timeToGo, 3600)
        XCTAssertEqual(battery?.consumedAmphours, 250.5)
    }
    
    // MARK: - Solar Charger Model Tests
    
    func testSolarChargerModelProductName() throws {
        let topic = "N/c0ffee000001/solarcharger/278/ProductName"
        let payload: [String: Any] = ["value": "MPPT 150/70"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.solarChargers["278"]?.productName, "MPPT 150/70")
    }
    
    func testSolarChargerModelPvVoltage() throws {
        let topic = "N/c0ffee000001/solarcharger/278/Pv/V"
        let payload: [String: Any] = ["value": 24.5]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.solarChargers["278"]?.pvVoltage, 24.5)
    }
    
    func testSolarChargerModelYieldPower() throws {
        let topic = "N/c0ffee000001/solarcharger/278/Yield/Power"
        let payload: [String: Any] = ["value": 150]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.solarChargers["278"]?.yieldPower, 150)
    }
    
    func testSolarChargerModelDcVoltage() throws {
        let topic = "N/c0ffee000001/solarcharger/278/Dc/0/Voltage"
        let payload: [String: Any] = ["value": 13.2]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.solarChargers["278"]?.dcVoltage, 13.2)
    }
    
    func testSolarChargerModelDcCurrent() throws {
        let topic = "N/c0ffee000001/solarcharger/278/Dc/0/Current"
        let payload: [String: Any] = ["value": 11.5]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.solarChargers["278"]?.dcCurrent, 11.5)
    }
    
    func testSolarChargerModelState() throws {
        let topic = "N/c0ffee000001/solarcharger/278/State"
        let payload: [String: Any] = ["value": 4]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.solarChargers["278"]?.state, 4)
    }
    
    func testSolarChargerModelComplete() throws {
        // Test that all solar charger fields can be populated
        let messages = [
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/278/Pv/V", payload: ["value": 24.5]),
            (topic: "N/c0ffee000001/solarcharger/278/Yield/Power", payload: ["value": 150]),
            (topic: "N/c0ffee000001/solarcharger/278/Dc/0/Voltage", payload: ["value": 13.2]),
            (topic: "N/c0ffee000001/solarcharger/278/Dc/0/Current", payload: ["value": 11.5]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 4])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        let solarCharger = store.solarChargers["278"]
        XCTAssertNotNil(solarCharger)
        XCTAssertEqual(solarCharger?.productName, "MPPT 150/70")
        XCTAssertEqual(solarCharger?.pvVoltage, 24.5)
        XCTAssertEqual(solarCharger?.yieldPower, 150)
        XCTAssertEqual(solarCharger?.dcVoltage, 13.2)
        XCTAssertEqual(solarCharger?.dcCurrent, 11.5)
        XCTAssertEqual(solarCharger?.state, 4)
    }
    
    // MARK: - Inverter Model Tests
    
    func testInverterModelProductName() throws {
        let topic = "N/c0ffee000001/vebus/276/ProductName"
        let payload: [String: Any] = ["value": "MultiPlus-II 48/5000"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.inverters["276"]?.productName, "MultiPlus-II 48/5000")
    }
    
    func testInverterModelAcInputPower() throws {
        let topic = "N/c0ffee000001/vebus/276/Ac/ActiveIn/L1/P"
        let payload: [String: Any] = ["value": 1200]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.inverters["276"]?.acInputPower, 1200)
    }
    
    func testInverterModelAcOutputPower() throws {
        let topic = "N/c0ffee000001/vebus/276/Ac/Out/L1/P"
        let payload: [String: Any] = ["value": 851]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.inverters["276"]?.acOutputPower, 851)
    }
    
    func testInverterModelMode() throws {
        let topic = "N/c0ffee000001/vebus/276/Mode"
        let payload: [String: Any] = ["value": 3]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.inverters["276"]?.mode, 3)
    }
    
    func testInverterModelState() throws {
        let topic = "N/c0ffee000001/vebus/276/State"
        let payload: [String: Any] = ["value": 2]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.inverters["276"]?.state, 2)
    }
    
    func testInverterModelComplete() throws {
        // Test that all inverter fields can be populated
        let messages = [
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/276/Ac/ActiveIn/L1/P", payload: ["value": 1200]),
            (topic: "N/c0ffee000001/vebus/276/Ac/Out/L1/P", payload: ["value": 851]),
            (topic: "N/c0ffee000001/vebus/276/Mode", payload: ["value": 3]),
            (topic: "N/c0ffee000001/vebus/276/State", payload: ["value": 2])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        let inverter = store.inverters["276"]
        XCTAssertNotNil(inverter)
        XCTAssertEqual(inverter?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(inverter?.acInputPower, 1200)
        XCTAssertEqual(inverter?.acOutputPower, 851)
        XCTAssertEqual(inverter?.mode, 3)
        XCTAssertEqual(inverter?.state, 2)
    }
    
    // MARK: - Full Fixture Tests
    
    func testUpdateWithFullPublishFixture() throws {
        // Load and parse the full publish fixture
        let url = Bundle.module.url(forResource: "system", withExtension: "json", subdirectory: "Fixtures")
        XCTAssertNotNil(url)
        
        guard let url = url else { return }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json)
        
        guard let json = json, let messages = json["messages"] as? [[String: Any]] else {
            XCTFail("Invalid fixture format")
            return
        }
        
        // Update store with all messages
        for messageDict in messages {
            guard let topic = messageDict["topic"] as? String,
                  let payload = messageDict["payload"] as? [String: Any] else {
                XCTFail("Invalid message format")
                continue
            }
            
            guard let message = parser.parseMessage(topic: topic, payload: payload) else {
                XCTFail("Should be able to parse message: \(topic)")
                continue
            }
            
            store.update(with: message)
        }
        
        // Verify system model
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        XCTAssertEqual(store.system.batterySoc, 78.5)
        XCTAssertEqual(store.system.batteryPower, 66.56)
        XCTAssertEqual(store.system.pvPower, 1250)
        XCTAssertEqual(store.system.acConsumptionTotal, 1500)
        XCTAssertEqual(store.system.timeToGo, 3600)
    }
    
    func testUpdateWithAllFixturesComprehensive() throws {
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
        
        // Verify system model - check every field
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        XCTAssertEqual(store.system.batterySoc, 78.5)
        XCTAssertEqual(store.system.batteryPower, 66.56)
        XCTAssertEqual(store.system.pvPower, 1250)
        XCTAssertEqual(store.system.acConsumptionOnOutput, 1180)
        XCTAssertEqual(store.system.acConsumptionOnInput, 320)
        XCTAssertEqual(store.system.acConsumptionTotal, 1500)
        XCTAssertEqual(store.system.timeToGo, 3600)
        
        // Verify battery model - check every field
        let battery = store.batteries["279"]
        XCTAssertNotNil(battery, "Battery with ID 279 should exist")
        XCTAssertEqual(battery?.productName, "Victron SmartShunt 500A")
        XCTAssertEqual(battery?.voltage, 12.8)
        XCTAssertEqual(battery?.current, 5.2)
        XCTAssertEqual(battery?.power, 66.56)
        XCTAssertEqual(battery?.soc, 78.5)
        XCTAssertEqual(battery?.timeToGo, 3600)
        XCTAssertEqual(battery?.consumedAmphours, 250.5)
        
        // Verify solar charger model - check every field
        let solarCharger = store.solarChargers["278"]
        XCTAssertNotNil(solarCharger, "Solar charger with ID 278 should exist")
        XCTAssertEqual(solarCharger?.productName, "MPPT 150/70")
        XCTAssertEqual(solarCharger?.pvVoltage, 24.5)
        XCTAssertEqual(solarCharger?.yieldPower, 150)
        XCTAssertEqual(solarCharger?.dcVoltage, 13.2)
        XCTAssertEqual(solarCharger?.dcCurrent, 11.5)
        XCTAssertEqual(solarCharger?.state, 4)
        
        // Verify inverter model - check every field
        let inverter = store.inverters["276"]
        XCTAssertNotNil(inverter, "Inverter with ID 276 should exist")
        XCTAssertEqual(inverter?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(inverter?.acInputPower, 1200)
        XCTAssertEqual(inverter?.acOutputPower, 851)
        XCTAssertEqual(inverter?.mode, 3)
        XCTAssertEqual(inverter?.state, 2)
    }
    
    func testUpdateWithAllFixtures() throws {
        // Test with all fixture files
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
        
        // Verify all models are populated
        XCTAssertEqual(store.portalId, "c0ffee000001")
        
        // System model
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        XCTAssertEqual(store.system.batterySoc, 78.5)
        XCTAssertEqual(store.system.batteryPower, 66.56)
        XCTAssertEqual(store.system.pvPower, 1250)
        XCTAssertEqual(store.system.acConsumptionOnOutput, 1180)
        XCTAssertEqual(store.system.acConsumptionOnInput, 320)
        XCTAssertEqual(store.system.acConsumptionTotal, 1500)
        XCTAssertEqual(store.system.timeToGo, 3600)
        
        // Battery model
        let battery = store.batteries["279"]
        XCTAssertNotNil(battery)
        XCTAssertEqual(battery?.productName, "Victron SmartShunt 500A")
        XCTAssertEqual(battery?.voltage, 12.8)
        XCTAssertEqual(battery?.current, 5.2)
        XCTAssertEqual(battery?.power, 66.56)
        XCTAssertEqual(battery?.soc, 78.5)
        XCTAssertEqual(battery?.timeToGo, 3600)
        XCTAssertEqual(battery?.consumedAmphours, 250.5)
        
        // Solar charger model
        let solarCharger = store.solarChargers["278"]
        XCTAssertNotNil(solarCharger)
        XCTAssertEqual(solarCharger?.productName, "MPPT 150/70")
        XCTAssertEqual(solarCharger?.pvVoltage, 24.5)
        XCTAssertEqual(solarCharger?.yieldPower, 150)
        XCTAssertEqual(solarCharger?.dcVoltage, 13.2)
        XCTAssertEqual(solarCharger?.dcCurrent, 11.5)
        XCTAssertEqual(solarCharger?.state, 4)
        
        // Inverter model
        let inverter = store.inverters["276"]
        XCTAssertNotNil(inverter)
        XCTAssertEqual(inverter?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(inverter?.acInputPower, 1200)
        XCTAssertEqual(inverter?.acOutputPower, 851)
        XCTAssertEqual(inverter?.mode, 3)
        XCTAssertEqual(inverter?.state, 2)
    }
    
    // MARK: - Multiple Device Tests
    
    func testMultipleBatteries() throws {
        // Test that multiple batteries can be tracked
        let messages = [
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "SmartShunt 500A"]),
            (topic: "N/c0ffee000001/battery/280/ProductName", payload: ["value": "SmartShunt 300A"]),
            (topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", payload: ["value": 12.8]),
            (topic: "N/c0ffee000001/battery/280/Dc/0/Voltage", payload: ["value": 12.7])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        XCTAssertEqual(store.batteries.count, 2)
        XCTAssertEqual(store.batteries["279"]?.productName, "SmartShunt 500A")
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.8)
        XCTAssertEqual(store.batteries["280"]?.productName, "SmartShunt 300A")
        XCTAssertEqual(store.batteries["280"]?.voltage, 12.7)
    }
    
    func testMultipleSolarChargers() throws {
        // Test that multiple solar chargers can be tracked
        let messages = [
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/279/ProductName", payload: ["value": "MPPT 100/30"]),
            (topic: "N/c0ffee000001/solarcharger/278/Pv/V", payload: ["value": 24.5]),
            (topic: "N/c0ffee000001/solarcharger/279/Pv/V", payload: ["value": 18.2])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        XCTAssertEqual(store.solarChargers.count, 2)
        XCTAssertEqual(store.solarChargers["278"]?.productName, "MPPT 150/70")
        XCTAssertEqual(store.solarChargers["278"]?.pvVoltage, 24.5)
        XCTAssertEqual(store.solarChargers["279"]?.productName, "MPPT 100/30")
        XCTAssertEqual(store.solarChargers["279"]?.pvVoltage, 18.2)
    }
    
    func testMultipleInverters() throws {
        // Test that multiple inverters can be tracked
        let messages = [
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/277/ProductName", payload: ["value": "MultiPlus-II 24/3000"]),
            (topic: "N/c0ffee000001/vebus/276/Ac/Out/L1/P", payload: ["value": 851]),
            (topic: "N/c0ffee000001/vebus/277/Ac/Out/L1/P", payload: ["value": 500])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        XCTAssertEqual(store.inverters.count, 2)
        XCTAssertEqual(store.inverters["276"]?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(store.inverters["276"]?.acOutputPower, 851)
        XCTAssertEqual(store.inverters["277"]?.productName, "MultiPlus-II 24/3000")
        XCTAssertEqual(store.inverters["277"]?.acOutputPower, 500)
    }
    
    // MARK: - Unknown Service Tests
    
    func testUnknownServiceIgnored() throws {
        let topic = "N/c0ffee000001/unknownservice/123/Field"
        let payload: [String: Any] = ["value": 42]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        // Before update
        let initialCount = store.batteries.count + store.solarChargers.count + store.inverters.count
        
        // Update with unknown service
        store.update(with: message)
        
        // Count should not change
        let finalCount = store.batteries.count + store.solarChargers.count + store.inverters.count
        XCTAssertEqual(initialCount, finalCount)
    }
    
    // MARK: - Handle Method Tests
    
    func testHandleEmptyPayloadRemovesDevice() throws {
        // Add a battery first
        let topic = "N/c0ffee000001/battery/279/ProductName"
        let payload: [String: Any] = ["value": "Victron SmartShunt 500A"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertNotNil(store.batteries["279"])
        
        // Now send empty payload to remove it
        store.handle(topic: topic, payload: Data())
        XCTAssertNil(store.batteries["279"])
    }
    
    func testHandleEmptyPayloadOtherPortalIgnored() throws {
        // Add a battery first
        let topic = "N/c0ffee000001/battery/279/ProductName"
        let payload: [String: Any] = ["value": "Victron SmartShunt 500A"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertNotNil(store.batteries["279"])
        
        // Send empty payload for different portal - should be ignored
        let otherTopic = "N/otherportal/battery/279/Soc"
        store.handle(topic: otherTopic, payload: Data())
        XCTAssertNotNil(store.batteries["279"])
    }
    
    func testHandleEmptyPayloadIgnoresSystem() throws {
        // Add system serial first
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload: [String: Any] = ["value": "HQ212200XA"]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        
        // Send empty payload for system - should be ignored
        store.handle(topic: topic, payload: Data())
        XCTAssertEqual(store.system.serial, "HQ212200XA")
    }
    
    func testHandlePortalIdFiltering() throws {
        // Set portal ID using handle method
        let topic1 = "N/c0ffee000001/system/0/Serial"
        let payload1 = Data("{\"value\":\"HQ212200XA\"}".utf8)
        
        store.handle(topic: topic1, payload: payload1)
        XCTAssertEqual(store.portalId, "c0ffee000001")
        
        // Try to update with different portal ID using handle - should be ignored
        let topic2 = "N/otherportalid/system/0/Serial"
        let payload2 = Data("{\"value\":\"OTHER\"}".utf8)
        
        store.handle(topic: topic2, payload: payload2)
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        XCTAssertEqual(store.portalId, "c0ffee000001")
    }
    
    func testHandleMalformedPayloadIgnored() throws {
        let topic = "N/c0ffee000001/system/0/Serial"
        let malformedPayload = Data("not json".utf8)
        
        // Should not crash
        store.handle(topic: topic, payload: malformedPayload)
        
        // System should remain unchanged
        XCTAssertNil(store.system.serial)
    }
    
    func testHandleNullValueClearsField() throws {
        // Set a value first
        let topic = "N/c0ffee000001/system/0/Dc/Battery/Soc"
        let payload: [String: Any] = ["value": 78.5]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        XCTAssertEqual(store.system.batterySoc, 78.5)
        
        // Send null value to clear it
        let nullPayload = ["value": NSNull()]
        guard let nullMessage = parser.parseMessage(topic: topic, payload: nullPayload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: nullMessage)
        XCTAssertNil(store.system.batterySoc)
    }
    
    func testHandleWithValidPayload() throws {
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload = Data("{\"value\":\"HQ212200XA\"}".utf8)
        
        store.handle(topic: topic, payload: payload)
        XCTAssertEqual(store.system.serial, "HQ212200XA")
    }
}
