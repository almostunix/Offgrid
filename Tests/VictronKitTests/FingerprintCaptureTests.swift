import XCTest
@testable import VictronKit

/// T-44: Fingerprint capture tests for trust-on-first-use
final class FingerprintCaptureTests: XCTestCase {
    var broker: TestBroker!
    let queue = DispatchQueue(label: "FingerprintCaptureTests")
    var capturedFingerprint: String?
    var captureError: ConnectionError?

    override func setUpWithError() throws {
        broker = TestBroker(tls: true, username: "cerbo", password: "s3cret")
        try broker.start()
        capturedFingerprint = nil
        captureError = nil
    }

    override func tearDown() {
        broker?.stop()
        broker = nil
        super.tearDown()
    }

    private func serverCertificateFingerprint() throws -> String {
        let url = try XCTUnwrap(broker.serverCertificateURL)
        let pem = try String(contentsOf: url, encoding: .utf8)
        let base64 = pem.components(separatedBy: .newlines).filter { !$0.hasPrefix("-----") }.joined()
        let der = try XCTUnwrap(Data(base64Encoded: base64))
        let cert = try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
        return ConnectionManager.sha256Fingerprint(of: cert)
    }

    func testFingerprintCaptureFromTLSBroker() throws {
        let expectedFingerprint = try serverCertificateFingerprint()
        let expectation = self.expectation(description: "Capture fingerprint")

        ConnectionManager.fetchServerFingerprint(
            host: "127.0.0.1",
            port: UInt16(broker.port),
            timeout: 5
        ) { result in
            switch result {
            case .success(let fingerprint):
                self.capturedFingerprint = fingerprint
            case .failure(let error):
                self.captureError = error as? ConnectionError
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 6, handler: nil)

        XCTAssertNil(captureError, "Should not have error")
        XCTAssertNotNil(capturedFingerprint, "Should have captured fingerprint")
        XCTAssertEqual(capturedFingerprint, expectedFingerprint, "Captured fingerprint should match server certificate")
    }

    func testFingerprintCanBeUsedForPinning() throws {
        let expectedFingerprint = try serverCertificateFingerprint()
        let captureExpectation = self.expectation(description: "Capture fingerprint")
        var states: [ConnectionState] = []

        ConnectionManager.fetchServerFingerprint(
            host: "127.0.0.1",
            port: UInt16(broker.port),
            timeout: 5
        ) { result in
            switch result {
            case .success(let fingerprint):
                self.capturedFingerprint = fingerprint
            case .failure(let error):
                self.captureError = error as? ConnectionError
            }
            captureExpectation.fulfill()
        }

        waitForExpectations(timeout: 6, handler: nil)

        XCTAssertNil(captureError, "Should not have error")
        XCTAssertEqual(capturedFingerprint, expectedFingerprint, "Captured fingerprint should match server certificate")

        // Now use the captured fingerprint to connect
        let profile = ConnectionProfile(
            name: "Test",
            host: "127.0.0.1",
            port: Int(broker.port),
            useTLS: true,
            username: "cerbo",
            pinnedCertificateSHA256: capturedFingerprint
        )

        let store = LiveDataStore()
        let manager = try ConnectionManager(profile: profile, liveDataStore: store, password: "s3cret", queue: queue)
        manager.onStateChange = { state in
            states.append(state)
        }

        manager.connect()

        // Wait for connection
        let connectExpectation = self.expectation(description: "Connect with pinned certificate")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            connectExpectation.fulfill()
        }

        waitForExpectations(timeout: 4, handler: nil)

        XCTAssertTrue(states.contains(.connected), "Should connect with captured fingerprint")
        manager.disconnect()
    }

    func testNonTLSBrokerFails() throws {
        let nonTLSBroker = TestBroker(tls: false, username: "cerbo", password: "s3cret")
        try nonTLSBroker.start()

        let expectation = self.expectation(description: "Non-TLS broker should fail")

        ConnectionManager.fetchServerFingerprint(
            host: "127.0.0.1",
            port: UInt16(nonTLSBroker.port),
            timeout: 2
        ) { result in
            switch result {
            case .success:
                XCTFail("Should not succeed for non-TLS broker")
            case .failure(let error):
                self.captureError = error as? ConnectionError
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3, handler: nil)

        XCTAssertEqual(captureError, .connectionRefused, "Should fail with connectionRefused for non-TLS broker")

        nonTLSBroker.stop()
    }
}
