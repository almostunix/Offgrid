//
// SubnetSweepTests.swift
//
// Tests for subnet sweep functionality.
//

import XCTest
@testable import VictronKit

final class SubnetSweepTests: XCTestCase {

    func testHostsFor24Subnet() {
        // 192.168.1.37 with /24 netmask
        let iface = IPv4Interface(
            address: 0xC0A80125,  // 192.168.1.37 in host order
            netmask: 0xFFFFFF00  // /24
        )
        
        let hosts = SubnetSweep.hosts(for: iface)
        
        // Should have 253 hosts (256 total - 2 for network/broadcast - 1 for self)
        XCTAssertEqual(hosts.count, 253)
        
        // Should not include network address (.0), broadcast address (.255), or self (.37)
        XCTAssertFalse(hosts.contains("192.168.1.0"))
        XCTAssertFalse(hosts.contains("192.168.1.255"))
        XCTAssertFalse(hosts.contains("192.168.1.37"))
        
        // Should include first and last valid hosts
        XCTAssertTrue(hosts.contains("192.168.1.1"))
        XCTAssertTrue(hosts.contains("192.168.1.254"))
    }

    func testHostsFor16SubnetCappedTo24() {
        // 10.0.5.9 with /16 netmask (should be capped to /24)
        let iface = IPv4Interface(
            address: 0x0A000509,  // 10.0.5.9 in host order
            netmask: 0xFFFF0000  // /16
        )
        
        let hosts = SubnetSweep.hosts(for: iface)
        
        // Should be capped to /24, so 253 hosts
        XCTAssertEqual(hosts.count, 253)
        
        // Should not include network address (10.0.5.0), broadcast address (10.0.5.255), or self (10.0.5.9)
        XCTAssertFalse(hosts.contains("10.0.5.0"))
        XCTAssertFalse(hosts.contains("10.0.5.255"))
        XCTAssertFalse(hosts.contains("10.0.5.9"))
        
        // Should include first and last valid hosts in the /24
        XCTAssertTrue(hosts.contains("10.0.5.1"))
        XCTAssertTrue(hosts.contains("10.0.5.254"))
    }

    func testHostsFor30Subnet() {
        // 192.168.1.100 with /30 netmask (4 addresses total)
        let iface = IPv4Interface(
            address: 0xC0A80164,  // 192.168.1.100 in host order
            netmask: 0xFFFFFFFC  // /30
        )
        
        let hosts = SubnetSweep.hosts(for: iface)
        
        // Should have 2 hosts (4 total - 2 for network/broadcast = 2, minus self = 1)
        XCTAssertEqual(hosts.count, 2)
        
        // Should include the valid hosts in the range
        XCTAssertTrue(hosts.contains("192.168.1.101"))
        XCTAssertTrue(hosts.contains("192.168.1.102"))
    }

    func testHostsFor32Subnet() {
        // 192.168.1.1 with /32 netmask (single host)
        let iface = IPv4Interface(
            address: 0xC0A80101,  // 192.168.1.1 in host order
            netmask: 0xFFFFFFFF  // /32
        )
        
        let hosts = SubnetSweep.hosts(for: iface)
        
        // Should have no hosts (no range to sweep)
        XCTAssertEqual(hosts.count, 0)
    }

    func testWifiInterfaceReturnsValidInterfaceOrNil() {
        // This test verifies the function can handle cases where no interface is found
        // In a real test environment, we might mock the system calls
        // For now, we just verify the function exists and returns the correct type
        let result = SubnetSweep.wifiInterface()
        // In a test environment, this might return nil or a valid interface
        // We just check that it returns the correct type
        if let result = result {
            // If it returns a value, verify it has valid address and netmask
            XCTAssertGreaterThan(result.address, 0)
            XCTAssertGreaterThan(result.netmask, 0)
        }
    }

    func testIPv4InterfaceEquatable() {
        let iface1 = IPv4Interface(address: 0xC0A80101, netmask: 0xFFFFFF00)
        let iface2 = IPv4Interface(address: 0xC0A80101, netmask: 0xFFFFFF00)
        let iface3 = IPv4Interface(address: 0xC0A80102, netmask: 0xFFFFFF00)
        
        XCTAssertEqual(iface1, iface2)
        XCTAssertNotEqual(iface1, iface3)
    }
}