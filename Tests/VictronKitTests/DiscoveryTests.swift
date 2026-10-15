//
// DiscoveryTests.swift
//
// Tests for the Victron GX device discovery service.
//

import XCTest
@testable import VictronKit

final class DiscoveryTests: XCTestCase {

    // MARK: - SSDP Reply Parser Tests

    func testSSDPReplyParsing() throws {
        let fixtureURL = Bundle.module.url(forResource: "victron_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let reply = try String(contentsOf: fixtureURL)

        let result = SSDPReply.parse(reply, from: "192.168.1.100")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.portalId, "c0ffee000001")
        XCTAssertEqual(result?.location.absoluteString, "http://192.168.1.100:8080/description.xml")
    }

    func testNonVictronSSDPReplyRejected() throws {
        let fixtureURL = Bundle.module.url(forResource: "non_victron_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let reply = try String(contentsOf: fixtureURL)

        let result = SSDPReply.parse(reply, from: "192.168.1.200")

        XCTAssertNil(result)
    }

    func testMalformedSSDPReplyRejected() throws {
        let fixtureURL = Bundle.module.url(forResource: "malformed_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let reply = try String(contentsOf: fixtureURL)

        let result = SSDPReply.parse(reply, from: "192.168.1.300")

        XCTAssertNil(result)
    }

    func testSSDPReplyWithWrongHostRejected() throws {
        let fixtureURL = Bundle.module.url(forResource: "victron_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let reply = try String(contentsOf: fixtureURL)

        let result = SSDPReply.parse(reply, from: "192.168.1.999")

        XCTAssertNil(result)
    }

    // MARK: - Device Description Parser Tests

    func testDeviceDescriptionParsing() throws {
        let fixtureURL = Bundle.module.url(forResource: "victron_description", withExtension: "xml", subdirectory: "Fixtures/discovery")!
        let data = try Data(contentsOf: fixtureURL)

        let result = DeviceDescriptionParser.parse(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.friendlyName, "My Solar Installation (c0ffee000001)")
        XCTAssertEqual(result?.manufacturer, "Victron Energy")
        XCTAssertEqual(result?.modelName, "Cerbo GX")
        XCTAssertEqual(result?.serialNumber, "HQ0000TEST")
        XCTAssertEqual(result?.vrmPortalId, "c0ffee000001")
        XCTAssertEqual(result?.mqttOnLan, MqttOnLan.on)
        XCTAssertEqual(result?.venusVersion, "v3.60")
    }

    func testNonVictronDeviceDescriptionRejected() throws {
        let fixtureURL = Bundle.module.url(forResource: "non_victron_description", withExtension: "xml", subdirectory: "Fixtures/discovery")!
        let data = try Data(contentsOf: fixtureURL)

        let result = DeviceDescriptionParser.parse(data)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.manufacturer, "Other Company")
    }

    func testMqttOnLanMapping() {
        XCTAssertEqual(MqttOnLan.off.rawValue, 0)
        XCTAssertEqual(MqttOnLan.on.rawValue, 1)
        XCTAssertEqual(MqttOnLan.tokensOnly.rawValue, 2)
    }

    // MARK: - FakeDiscovery Tests

    func testFakeDiscovery() {
        let device = DiscoveredDevice(
            id: "test123",
            name: "Test Device",
            host: "192.168.1.100",
            portalId: "test123",
            mqttOnLan: .on,
            venusVersion: "v2.50",
            lastSeen: Date()
        )

        let fakeDiscovery = FakeDiscovery(devices: [device])
        var receivedDevices: [DiscoveredDevice]?

        fakeDiscovery.start { devices in
            receivedDevices = devices
        }

        XCTAssertEqual(receivedDevices?.count, 1)
        XCTAssertEqual(receivedDevices?.first?.id, "test123")
        XCTAssertEqual(receivedDevices?.first?.name, "Test Device")
        XCTAssertEqual(receivedDevices?.first?.host, "192.168.1.100")
        XCTAssertEqual(receivedDevices?.first?.portalId, "test123")
        XCTAssertEqual(receivedDevices?.first?.mqttOnLan, .on)
        XCTAssertEqual(receivedDevices?.first?.venusVersion, "v2.50")
    }

    func testFakeDiscoveryUpdate() {
        let device1 = DiscoveredDevice(
            id: "test1",
            name: "Device 1",
            host: "192.168.1.100"
        )

        let device2 = DiscoveredDevice(
            id: "test2",
            name: "Device 2",
            host: "192.168.1.101"
        )

        let fakeDiscovery = FakeDiscovery(devices: [device1])
        var receivedDevices: [DiscoveredDevice]?

        fakeDiscovery.start { devices in
            receivedDevices = devices
        }

        XCTAssertEqual(receivedDevices?.count, 1)
        
        // Update devices
        fakeDiscovery.setDevices([device2])
        
        XCTAssertEqual(receivedDevices?.count, 1)
        XCTAssertEqual(receivedDevices?.first?.id, "test2")
    }
}