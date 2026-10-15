import XCTest
@testable import VictronKit

/// T-61: Offgrid fix verification - wrong password shows .failed(.authenticationFailed) not .reconnecting forever
final class ConnectionManagerAuthTests: XCTestCase {
    var broker: TestBroker!
    var store: LiveDataStore!
    let queue = DispatchQueue(label: "ConnectionManagerAuthTests")
    var states: [ConnectionState] = []   // only touched on `queue`

    override func setUpWithError() throws {
        broker = TestBroker(tls: true, username: "cerbo", password: "s3cret")
        try broker.start()
        store = LiveDataStore()
    }

    override func tearDown() {
        broker?.stop()   // otherwise every test leaks a mosquitto process
        broker = nil
        super.tearDown()
    }

    private func makeManager(profile: ConnectionProfile, password: String? = nil) throws -> ConnectionManager {
        let m = try ConnectionManager(profile: profile, liveDataStore: store, password: password, queue: queue)
        m.onStateChange = { [unowned self] in self.states.append($0) }
        return m
    }

    private func onQueue<T>(_ body: () -> T) -> T { queue.sync(execute: body) }

    /// Polls `condition` (evaluated on the manager's queue) until it holds or `timeout` passes.
    private func waitUntil(_ what: String, timeout: TimeInterval = 5, _ condition: () -> Bool) {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if onQueue(condition) { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTFail("timed out waiting for: \(what)")
    }

    /// Get the SHA-256 fingerprint of the broker's server certificate
    private func serverCertificateFingerprint() throws -> String {
        let url = try XCTUnwrap(broker.serverCertificateURL)
        let pem = try String(contentsOf: url, encoding: .utf8)
        let base64 = pem.components(separatedBy: .newlines).filter { !$0.hasPrefix("-----") }.joined()
        let der = try XCTUnwrap(Data(base64Encoded: base64))
        let cert = try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
        return ConnectionManager.sha256Fingerprint(of: cert)
    }

    func testWrongPasswordShowsFailedNotReconnecting() throws {
        // This is the exact scenario from T-61: wrong password with pinned profile
        let correctPin = try serverCertificateFingerprint()
        let profile = ConnectionProfile(
            name: "Test", 
            host: "127.0.0.1", 
            port: Int(broker.port), 
            useTLS: true,
            username: "cerbo",
            pinnedCertificateSHA256: correctPin
        )
        
        let manager = try makeManager(profile: profile, password: "wrong")
        manager.connect()
        
        // Wait for connection to fail
        waitUntil("connection failure") {
            guard let last = self.states.last else { return false }
            return last != .connecting && last != .connected
        }
        
        // State should be .failed(.authenticationFailed)
        XCTAssertTrue(onQueue { 
            states.contains { 
                if case .failed(.authenticationFailed) = $0 { return true }
                return false
            }
        })
        
        // State should NOT be .reconnecting
        XCTAssertFalse(onQueue { 
            states.contains { 
                if case .reconnecting = $0 { return true }
                return false
            }
        })
        
        // Wait 3 seconds to ensure it doesn't transition to .reconnecting
        Thread.sleep(forTimeInterval: 3)
        
        // State should still be .failed, not .reconnecting
        let finalState = onQueue { manager.state }
        switch finalState {
        case .failed(.authenticationFailed):
            break // This is what we expect
        default:
            XCTFail("Expected .failed(.authenticationFailed), got: \(finalState)")
        }
        
        // Should NOT be in reconnecting state
        XCTAssertFalse(onQueue { 
            states.contains { 
                if case .reconnecting = $0 { return true }
                return false
            }
        })
    }

    func testCorrectPasswordConnectsSuccessfully() throws {
        // Verify that correct credentials still work
        let correctPin = try serverCertificateFingerprint()
        let profile = ConnectionProfile(
            name: "Test", 
            host: "127.0.0.1", 
            port: Int(broker.port), 
            useTLS: true,
            username: "cerbo",
            pinnedCertificateSHA256: correctPin
        )
        
        let manager = try makeManager(profile: profile, password: "s3cret")
        manager.connect()
        
        // Wait for connection to succeed
        waitUntil("connection success") {
            guard let last = self.states.last else { return false }
            return last == .connected
        }
        
        // Should be in connected state
        XCTAssertEqual(onQueue { manager.state }, .connected)
        
        // Should NOT be in failed state
        XCTAssertFalse(onQueue { 
            states.contains { 
                if case .failed = $0 { return true }
                return false
            }
        })
        
        // Should NOT be in reconnecting state
        XCTAssertFalse(onQueue { 
            states.contains { 
                if case .reconnecting = $0 { return true }
                return false
            }
        })
    }
}