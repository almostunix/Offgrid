//
// DeviceDiscoveryTests.swift
//
// DeviceDiscovery with fakes only: no real interface, socket or HTTP fetch.
//

import XCTest
@testable import VictronKit

final class DeviceDiscoveryTests: XCTestCase {

    /// Answers a send to a known host with a canned reply, the way a GX device answers a unicast M-SEARCH.
    final class FakeTransport: DatagramTransport {
        var onReceive: ((Data, String) -> Void)?
        var replies: [String: Data] = [:]
        private(set) var sentHosts: [String] = []

        func send(_ data: Data, to host: String, port: UInt16) {
            sentHosts.append(host)
            if let reply = replies[host] { onReceive?(reply, host) }
        }

        func close() {}
    }

    private let iface = IPv4Interface(address: 0xC0A8_0125, netmask: 0xFFFF_FF00) // 192.168.1.37/24

    private func fixture(_ name: String, _ ext: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures/discovery"))
        return try Data(contentsOf: url)
    }

    private func transportAnswering20() throws -> FakeTransport {
        let transport = FakeTransport()
        transport.replies["192.168.1.20"] = try fixture("victron_ssdp_reply_192_168_1_20", "txt")
        return transport
    }

    private func run(_ discovery: DeviceDiscovery) -> [DiscoveredDevice] {
        var captured: [DiscoveredDevice] = []
        var calls = 0
        let done = expectation(description: "onUpdate")
        discovery.start { devices in
            calls += 1
            captured = devices
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(calls, 1)
        return captured
    }

    func testNoInterfaceStillReportsOnceWithoutSweeping() {
        let transport = FakeTransport()
        let discovery = DeviceDiscovery(resolveVenusLocal: { [] }, interface: { nil }, makeTransport: { transport }, describe: { _ in nil }, sweepListen: 0.1)
        XCTAssertEqual(run(discovery), [])
        XCTAssertTrue(transport.sentHosts.isEmpty, "an injected nil interface must not fall back to the real Wi-Fi")
    }

    func testSweepFindsDeviceWhenVenusLocalFails() throws {
        let transport = try transportAnswering20()
        let description = DeviceDescriptionParser.parse(try fixture("victron_description", "xml"))
        let discovery = DeviceDiscovery(resolveVenusLocal: { [] }, interface: { self.iface }, makeTransport: { transport }, describe: { _ in description }, sweepListen: 0.2)

        let devices = run(discovery)

        XCTAssertEqual(transport.sentHosts.count, 253) // .1 to .254 without our own .37
        XCTAssertEqual(devices.count, 1)
        let device = try XCTUnwrap(devices.first)
        XCTAssertEqual(device.portalId, "c0ffee000001")
        XCTAssertEqual(device.host, "192.168.1.20")
        XCTAssertEqual(device.name, "My Solar Installation (c0ffee000001)")
        XCTAssertEqual(device.mqttOnLan, .on)
    }

    func testSweepDoesNotDuplicateDeviceAlreadyFoundByVenusLocal() throws {
        let transport = try transportAnswering20()
        let venus = DiscoveredDevice(id: "c0ffee000001", name: "Venus Device", host: "192.168.1.100", portalId: "c0ffee000001", mqttOnLan: .on, venusVersion: "v3.60", lastSeen: Date())
        let discovery = DeviceDiscovery(resolveVenusLocal: { [venus] }, interface: { self.iface }, makeTransport: { transport }, describe: { _ in nil }, sweepListen: 0.2)

        let devices = run(discovery)

        XCTAssertEqual(devices.map(\.name), ["Venus Device"])
    }

    func testSweptDeviceWithFailedDescriptionIsStillListed() throws {
        let transport = try transportAnswering20()
        let discovery = DeviceDiscovery(resolveVenusLocal: { [] }, interface: { self.iface }, makeTransport: { transport }, describe: { _ in nil }, sweepListen: 0.2)

        let devices = run(discovery)

        XCTAssertEqual(devices.count, 1)
        let device = try XCTUnwrap(devices.first)
        XCTAssertEqual(device.portalId, "c0ffee000001")
        XCTAssertEqual(device.name, "Victron GX (192.168.1.20)")
        XCTAssertNil(device.mqttOnLan)
    }
}
