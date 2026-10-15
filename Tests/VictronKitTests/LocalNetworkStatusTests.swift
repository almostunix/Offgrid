//
// LocalNetworkStatusTests.swift
//

import XCTest
import Network
@testable import VictronKit

final class LocalNetworkStatusTests: XCTestCase {

    func testDNSPolicyDeniedErrorMapsToDenied() {
        // Create a DNS error with policy denied code (-65570)
        // We'll create a mock error that simulates the DNS policy denied scenario
        let dnsError = NSError(domain: "com.apple.network.dns", code: -65570, userInfo: [
            NSLocalizedDescriptionKey: "DNS policy denied"
        ])
        
        let status = LocalNetworkErrorMapper.map(dnsError)
        XCTAssertEqual(status, .denied)
    }

    func testHostUnreachableErrorMapsToDenied() {
        let nwError = NSError(domain: NSPOSIXErrorDomain, code: Int(EHOSTUNREACH), userInfo: nil)
        
        let status = LocalNetworkErrorMapper.map(nwError)
        XCTAssertEqual(status, .denied)
    }

    func testNetworkUnreachableErrorMapsToDenied() {
        let nwError = NSError(domain: NSPOSIXErrorDomain, code: Int(ENETUNREACH), userInfo: nil)
        
        let status = LocalNetworkErrorMapper.map(nwError)
        XCTAssertEqual(status, .denied)
    }

    func testUnknownErrorMapsToUnknown() {
        let nwError = NSError(domain: NSPOSIXErrorDomain, code: Int(EIO), userInfo: nil)
        
        let status = LocalNetworkErrorMapper.map(nwError)
        XCTAssertEqual(status, .unknown)
    }

    func testGenericErrorMapsToUnknown() {
        let error = NSError(domain: "com.test", code: 123)
        
        let status = LocalNetworkErrorMapper.map(error)
        XCTAssertEqual(status, .unknown)
    }

    func testLocalNetworkStatusEnumValues() {
        // Test that all cases are accessible
        let unknown = LocalNetworkStatus.unknown
        let allowed = LocalNetworkStatus.allowed
        let denied = LocalNetworkStatus.denied
        
        // Test equality
        XCTAssertEqual(unknown, .unknown)
        XCTAssertEqual(allowed, .allowed)
        XCTAssertEqual(denied, .denied)
    }

    func testNetworkFrameworkErrorsMap() {
        XCTAssertEqual(LocalNetworkErrorMapper.map(NWError.posix(.EHOSTUNREACH)), .denied)
        XCTAssertEqual(LocalNetworkErrorMapper.map(NWError.posix(.ENETUNREACH)), .denied)
        XCTAssertEqual(LocalNetworkErrorMapper.map(NWError.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))), .denied)
        XCTAssertEqual(LocalNetworkErrorMapper.map(NWError.posix(.ECONNREFUSED)), .unknown)
    }
}
