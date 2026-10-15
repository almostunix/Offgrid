//
// TrustPromptTests.swift
//
// Tests for trust-on-first-use prompt utilities
//

import XCTest
@testable import VictronKit

final class TrustPromptTests: XCTestCase {
    func testFormatFingerprint() {
        let fingerprint = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        let formatted = formatFingerprint(forDisplay: fingerprint)
        let expected = "a1 b2 c3 d4 e5 f6 a1 b2 c3 d4 e5 f6 a1 b2 c3 d4 e5 f6 a1 b2 c3 d4 e5 f6 a1 b2 c3 d4 e5 f6 a1 b2"
        XCTAssertEqual(formatted, expected)
    }

    func testFormatFingerprintShort() {
        let fingerprint = "short"
        let formatted = formatFingerprint(forDisplay: fingerprint)
        XCTAssertEqual(formatted, "short")
    }

    func testNeedsTrustPromptWithTLSAndNoPin() {
        let profile = ConnectionProfile(
            name: "Test",
            host: "127.0.0.1",
            port: 8883,
            useTLS: true,
            username: "test",
            pinnedCertificateSHA256: nil
        )
        XCTAssertTrue(needsTrustPrompt(for: profile))
    }

    func testNeedsTrustPromptWithTLSAndPin() {
        let profile = ConnectionProfile(
            name: "Test",
            host: "127.0.0.1",
            port: 8883,
            useTLS: true,
            username: "test",
            pinnedCertificateSHA256: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
        )
        XCTAssertFalse(needsTrustPrompt(for: profile))
    }

    func testNeedsTrustPromptWithoutTLS() {
        let profile = ConnectionProfile(
            name: "Test",
            host: "127.0.0.1",
            port: 1883,
            useTLS: false,
            username: "test"
        )
        XCTAssertFalse(needsTrustPrompt(for: profile))
    }
}
