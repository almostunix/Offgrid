//
// DeviceListTests.swift
//
// Tests for device list model
//

import XCTest
import SwiftUI
@testable import VictronKit

final class DeviceListTests: XCTestCase {
    var liveDataStore: LiveDataStore!
    var parser: TopicParser!
    
    override func setUp() {
        super.setUp()
        liveDataStore = LiveDataStore()
        parser = TopicParser()
    }
    
    override func tearDown() {
        liveDataStore = nil
        parser = nil
        super.tearDown()
    }
    
    func testDeviceListWithNoDevices() {
        let devices = DeviceListModel.rows(from: liveDataStore)
        
        XCTAssertTrue(devices.isEmpty, "Device list should be empty when no devices are connected")
    }
    
    func testDeviceListWithSingleBattery() {
        // Add a battery
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/ProductName", 
                                          payload: ["value": "SmartShunt 500A"])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        let message2 = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", 
                                           payload: ["value": 12.8])
        guard let message2 = message2 else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message2)
        
        let message3 = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Soc", 
                                           payload: ["value": 78.5])
        guard let message3 = message3 else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message3)
        
        let message4 = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Dc/0/Power", 
                                           payload: ["value": 66.56])
        guard let message4 = message4 else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message4)
        
        let devices = DeviceListModel.rows(from: liveDataStore)
        
        XCTAssertEqual(devices.count, 1, "Device list should have 1 device")
        XCTAssertEqual(devices[0].id, "279", "Device ID should match")
        XCTAssertEqual(devices[0].type, .battery, "Device type should be battery")
        XCTAssertEqual(devices[0].productName, "SmartShunt 500A", "Product name should match")
        XCTAssertEqual(devices[0].power, 66.56, "Power should match")
        XCTAssertEqual(devices[0].soc, 78.5, "SOC should match")
    }
    
    func testDeviceListWithMultipleDevices() {
        // Add a battery
        let batteryMessage = parser.parseMessage(topic: "N/c0ffee000001/battery/279/ProductName", 
                                                 payload: ["value": "SmartShunt 500A"])
        guard let batteryMessage = batteryMessage else {
            XCTFail("Should be able to parse battery message")
            return
        }
        liveDataStore.update(with: batteryMessage)
        
        // Add a solar charger
        let solarMessage = parser.parseMessage(topic: "N/c0ffee000001/solarcharger/278/ProductName", 
                                               payload: ["value": "MPPT 150/70"])
        guard let solarMessage = solarMessage else {
            XCTFail("Should be able to parse solar charger message")
            return
        }
        liveDataStore.update(with: solarMessage)
        
        // Add an inverter
        let inverterMessage = parser.parseMessage(topic: "N/c0ffee000001/vebus/276/ProductName", 
                                                  payload: ["value": "MultiPlus-II 48/5000"])
        guard let inverterMessage = inverterMessage else {
            XCTFail("Should be able to parse inverter message")
            return
        }
        liveDataStore.update(with: inverterMessage)
        
        let devices = DeviceListModel.rows(from: liveDataStore)
        
        XCTAssertEqual(devices.count, 3, "Device list should have 3 devices")
        
        // Check device types
        let types = devices.map { $0.type }
        XCTAssertTrue(types.contains(.battery), "Should contain a battery")
        XCTAssertTrue(types.contains(.solarCharger), "Should contain a solar charger")
        XCTAssertTrue(types.contains(.inverter), "Should contain an inverter")
    }
    
    func testBatteryStatusGood() {
        // Add battery to store
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Soc", 
                                          payload: ["value": 85.0])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        let devices = DeviceListModel.rows(from: liveDataStore)
        guard let device = devices.first(where: { $0.id == "279" }) else {
            XCTFail("Should find battery device")
            return
        }
        
        XCTAssertEqual(device.status, "Good", "Status should be Good for SOC >= 80")
    }
    
    func testBatteryStatusFair() {
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Soc", 
                                          payload: ["value": 60.0])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        let devices = DeviceListModel.rows(from: liveDataStore)
        guard let device = devices.first(where: { $0.id == "279" }) else {
            XCTFail("Should find battery device")
            return
        }
        
        XCTAssertEqual(device.status, "Fair", "Status should be Fair for SOC 50-79")
    }
    
    func testBatteryStatusLow() {
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Soc", 
                                          payload: ["value": 30.0])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        let devices = DeviceListModel.rows(from: liveDataStore)
        guard let device = devices.first(where: { $0.id == "279" }) else {
            XCTFail("Should find battery device")
            return
        }
        
        XCTAssertEqual(device.status, "Low", "Status should be Low for SOC 20-49")
    }
    
    func testBatteryStatusCritical() {
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/Soc", 
                                          payload: ["value": 10.0])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        let devices = DeviceListModel.rows(from: liveDataStore)
        guard let device = devices.first(where: { $0.id == "279" }) else {
            XCTFail("Should find battery device")
            return
        }
        
        XCTAssertEqual(device.status, "Critical", "Status should be Critical for SOC < 20")
    }
    
    func testSolarChargerStatusStates() {
        let states: [(state: Int, expectedStatus: String)] = [
            (0, "Off"),
            (2, "Fault"),
            (3, "Bulk"),
            (4, "Absorption"),
            (5, "Float"),
            (6, "Storage"),
            (7, "Equalize"),
            (252, "External Control")
        ]
        
        for (state, expectedStatus) in states {
            let message = parser.parseMessage(topic: "N/c0ffee000001/solarcharger/278/State", 
                                              payload: ["value": state])
            guard let message = message else {
                XCTFail("Should be able to parse message for state: \\(state)")
                return
            }
            liveDataStore.update(with: message)
            
            let devices = DeviceListModel.rows(from: liveDataStore)
            guard let device = devices.first(where: { $0.id == "278" }) else {
                XCTFail("Should find solar charger device for state: \\(state)")
                return
            }
            
            XCTAssertEqual(device.status, expectedStatus, "Status should be 'expectedStatus' for state: \\(state)")
        }
    }
    
    func testInverterStatusStates() {
        let states: [(state: Int, expectedStatus: String)] = [
            (0, "Off"),
            (1, "Low Power"),
            (2, "Fault"),
            (3, "Bulk"),
            (4, "Absorption"),
            (5, "Float"),
            (6, "Storage"),
            (7, "Equalize"),
            (8, "Passthru"),
            (9, "Inverting"),
            (10, "Power Assist"),
            (11, "Power Supply"),
            (244, "Sustain"),
            (252, "External Control")
        ]
        
        for (state, expectedStatus) in states {
            let message = parser.parseMessage(topic: "N/c0ffee000001/vebus/276/State", 
                                              payload: ["value": state])
            guard let message = message else {
                XCTFail("Should be able to parse message for state: \\(state)")
                return
            }
            liveDataStore.update(with: message)
            
            let devices = DeviceListModel.rows(from: liveDataStore)
            guard let device = devices.first(where: { $0.id == "276" }) else {
                XCTFail("Should find inverter device for state: \\(state)")
                return
            }
            
            XCTAssertEqual(device.status, expectedStatus, "Status should be 'expectedStatus' for state: \\(state)")
        }
    }
    
    func testDeviceListUpdatesWhenDeviceAdded() {
        // Initially empty
        var devices = DeviceListModel.rows(from: liveDataStore)
        XCTAssertTrue(devices.isEmpty, "Device list should be empty initially")
        
        // Add a device
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/ProductName", 
                                          payload: ["value": "SmartShunt 500A"])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        // List should now have 1 device
        devices = DeviceListModel.rows(from: liveDataStore)
        XCTAssertEqual(devices.count, 1, "Device list should have 1 device after adding")
    }
    
    func testDeviceListUpdatesWhenDeviceRemoved() {
        // Add a device
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/ProductName", 
                                          payload: ["value": "SmartShunt 500A"])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        liveDataStore.update(with: message)
        
        var devices = DeviceListModel.rows(from: liveDataStore)
        XCTAssertEqual(devices.count, 1, "Device list should have 1 device initially")
        
        // Remove the device (empty payload)
        liveDataStore.handle(topic: "N/c0ffee000001/battery/279/ProductName", payload: Data())
        
        // List should now be empty
        devices = DeviceListModel.rows(from: liveDataStore)
        XCTAssertTrue(devices.isEmpty, "Device list should be empty after device removal")
    }
}

// MARK: - Helper Functions

extension DeviceListTests {
    // Helper to get battery status
    private func batteryStatus(for battery: BatteryModel) -> String {
        guard let soc = battery.soc else { return "Unknown" }
        
        if soc >= 80 {
            return "Good"
        } else if soc >= 50 {
            return "Fair"
        } else if soc >= 20 {
            return "Low"
        } else {
            return "Critical"
        }
    }
    
    // Helper to get solar charger status
    private func solarChargerStatus(for solarCharger: SolarChargerModel) -> String {
        guard let state = solarCharger.state else { return "Unknown" }
        
        switch state {
        case 0: return "Off"
        case 2: return "Fault"
        case 3: return "Bulk"
        case 4: return "Absorption"
        case 5: return "Float"
        case 6: return "Storage"
        case 7: return "Equalize"
        case 252: return "External Control"
        default: return "Unknown"
        }
    }
    
    // Helper to get inverter status
    private func inverterStatus(for inverter: InverterModel) -> String {
        guard let state = inverter.state else { return "Unknown" }
        
        switch state {
        case 0: return "Off"
        case 1: return "Low Power"
        case 2: return "Fault"
        case 3: return "Bulk"
        case 4: return "Absorption"
        case 5: return "Float"
        case 6: return "Storage"
        case 7: return "Equalize"
        case 8: return "Passthru"
        case 9: return "Inverting"
        case 10: return "Power Assist"
        case 11: return "Power Supply"
        case 244: return "Sustain"
        case 252: return "External Control"
        default: return "Unknown"
        }
    }
}