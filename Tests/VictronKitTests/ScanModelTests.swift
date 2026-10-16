//
// ScanModelTests.swift
//
// Tests for ScanModel functionality
//

import XCTest
@testable import VictronKit

class ScanModelTests: XCTestCase {

    func testFoundRowsFiltersByPortalId() {
        let date = Date()
        let device1 = DiscoveredDevice(id: "portal123", name: "Cerbo1", host: "192.168.1.100", portalId: "portal123", mqttOnLan: .on, lastSeen: date)
        let device2 = DiscoveredDevice(id: "portal456", name: "Cerbo2", host: "192.168.1.101", portalId: "portal456", mqttOnLan: .on, lastSeen: date)
        
        let savedProfile = ConnectionProfile(name: "Saved Cerbo", host: "192.168.1.100", port: 8883, useTLS: true, username: nil, pinnedCertificateSHA256: nil)
        var savedProfileCopy = savedProfile
        savedProfileCopy.portalId = "portal123"
        
        let found = [device1, device2]
        let saved = [savedProfileCopy]
        
        let filtered = ScanModel.foundRows(found: found, saved: saved)
        
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].id, "portal456")
    }

    func testFoundRowsFiltersByHost() {
        let date = Date()
        let device1 = DiscoveredDevice(id: "host1", name: "Cerbo1", host: "192.168.1.100", portalId: nil, mqttOnLan: .on, lastSeen: date)
        let device2 = DiscoveredDevice(id: "host2", name: "Cerbo2", host: "192.168.1.101", portalId: nil, mqttOnLan: .on, lastSeen: date)
        
        let savedProfile = ConnectionProfile(name: "Saved Cerbo", host: "192.168.1.100", port: 8883, useTLS: true, username: nil, pinnedCertificateSHA256: nil)
        
        let found = [device1, device2]
        let saved = [savedProfile]
        
        let filtered = ScanModel.foundRows(found: found, saved: saved)
        
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].id, "host2")
    }

    func testCanConnectReturnsFalseWhenMQTTOff() {
        let date = Date()
        let device = DiscoveredDevice(id: "test", name: "Cerbo", host: "192.168.1.100", portalId: "portal123", mqttOnLan: .off, lastSeen: date)
        
        let canConnect = ScanModel.canConnect(device)
        
        XCTAssertFalse(canConnect)
    }

    func testCanConnectReturnsTrueWhenMQTTOn() {
        let date = Date()
        let device = DiscoveredDevice(id: "test", name: "Cerbo", host: "192.168.1.100", portalId: "portal123", mqttOnLan: .on, lastSeen: date)
        
        let canConnect = ScanModel.canConnect(device)
        
        XCTAssertTrue(canConnect)
    }

    func testProfileForDeviceWithTLSENABLED() {
        let date = Date()
        let device = DiscoveredDevice(id: "test", name: "Test Cerbo", host: "192.168.1.100", portalId: "portal123", mqttOnLan: .on, lastSeen: date)
        
        let profile = ScanModel.profile(for: device, useTLS: true)
        
        XCTAssertEqual(profile.name, "Test Cerbo")
        XCTAssertEqual(profile.host, "192.168.1.100")
        XCTAssertEqual(profile.port, 8883)
        XCTAssertTrue(profile.useTLS)
        XCTAssertNil(profile.username)
    }

    func testProfileForDeviceWithTLSDisabled() {
        let date = Date()
        let device = DiscoveredDevice(id: "test", name: "Test Cerbo", host: "192.168.1.100", portalId: "portal123", mqttOnLan: .on, lastSeen: date)
        
        let profile = ScanModel.profile(for: device, useTLS: false)
        
        XCTAssertEqual(profile.name, "Test Cerbo")
        XCTAssertEqual(profile.host, "192.168.1.100")
        XCTAssertEqual(profile.port, 1883)
        XCTAssertFalse(profile.useTLS)
        XCTAssertNil(profile.username)
    }

    func testFoundRowsWithEmptyArrays() {
        let found: [DiscoveredDevice] = []
        let saved: [ConnectionProfile] = []
        
        let filtered = ScanModel.foundRows(found: found, saved: saved)
        
        XCTAssertTrue(filtered.isEmpty)
    }

    func testProfileIncludesPortalId() {
        let date = Date()
        let device = DiscoveredDevice(id: "test", name: "Test Cerbo", host: "192.168.1.100", portalId: "portal123", mqttOnLan: .on, lastSeen: date)
        
        let profile = ScanModel.profile(for: device, useTLS: true)
        
        XCTAssertEqual(profile.portalId, "portal123")
    }

    func testProfileWithNilPortalId() {
        let date = Date()
        let device = DiscoveredDevice(id: "test", name: "Test Cerbo", host: "192.168.1.100", portalId: nil, mqttOnLan: .on, lastSeen: date)
        
        let profile = ScanModel.profile(for: device, useTLS: false)
        
        XCTAssertNil(profile.portalId)
    }

    func testProfileCarriesThePortalId() {
        let device = DiscoveredDevice(id: "c0ffee000001", name: "My Cerbo", host: "192.0.2.10", portalId: "c0ffee000001")
        XCTAssertEqual(ScanModel.profile(for: device, useTLS: true).portalId, "c0ffee000001")
        XCTAssertNil(ScanModel.profile(for: DiscoveredDevice(id: "192.0.2.11", name: "GX", host: "192.0.2.11"), useTLS: true).portalId)
    }
}
