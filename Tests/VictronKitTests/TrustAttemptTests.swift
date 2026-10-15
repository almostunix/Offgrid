//
// TrustAttemptTests.swift
//
// Tests for TrustAttempt struct functionality
//

import XCTest
@testable import VictronKit

final class TrustAttemptTests: XCTestCase {

    func testTrustAttemptAcceptsMatchingId() {
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true))
        XCTAssertTrue(attempt.accepts(resultFor: attempt.id))
    }

    func testTrustAttemptRejectsDifferentId() {
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true))
        let differentId = UUID()
        XCTAssertFalse(attempt.accepts(resultFor: differentId))
    }

    func testTrustAttemptPinMatchesHostPort() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: profile, 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertEqual(result, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
    }

    func testTrustAttemptPinRejectsChangedHost() {
        let profile = ConnectionProfile(name: "Test", host: "192.168.1.1", port: 8883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsChangedPort() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 1883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsChangedTLSSetting() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: false)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsNilFingerprint() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: profile, fingerprint: nil, host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsNonTLSProfile() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: false)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }
}