import XCTest
@testable import VictronKit

/// T-35: Certificate pinning tests against the Mosquitto test broker with TLS
final class PinningTests: XCTestCase {
    var broker: TestBroker!
    var store: LiveDataStore!
    let queue = DispatchQueue(label: "PinningTests")
    var states: [ConnectionState] = []

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

    func testCorrectPinConnectsSuccessfully() throws {
        let correctPin = try serverCertificateFingerprint()
        var profile = ConnectionProfile(
            name: "Test", 
            host: "127.0.0.1", 
            port: Int(broker.port), 
            useTLS: true,
            username: "cerbo",
            pinnedCertificateSHA256: correctPin
        )
        
        let manager = try makeManager(profile: profile, password: "s3cret")
        manager.connect()
        
        waitUntil("connection success") {
            guard let last = self.states.last else { return false }
            return last == .connected
        }
        
        XCTAssertTrue(onQueue { states.contains(.connected) })
        manager.disconnect()
    }

    func testWrongPinIsRejected() throws {
        let wrongPin = String(repeating: "0", count: 64) // 64 zeros
        let profile = ConnectionProfile(
            name: "Test", 
            host: "127.0.0.1", 
            port: Int(broker.port), 
            useTLS: true,
            username: "cerbo",
            pinnedCertificateSHA256: wrongPin
        )
        
        let manager = try makeManager(profile: profile, password: "s3cret")
        manager.connect()
        
        waitUntil("connection failure") {
            guard let last = self.states.last else { return false }
            return last != .connecting && last != .connected
        }
        
        XCTAssertTrue(onQueue { 
            states.contains { 
                if case .failed(.untrustedCertificate) = $0 { return true }
                return false
            }
        })
        manager.disconnect()
    }

    func testTLSWithoutPinIsRejected() throws {
        let profile = ConnectionProfile(
            name: "Test", 
            host: "127.0.0.1", 
            port: Int(broker.port), 
            useTLS: true,
            username: "cerbo",
            pinnedCertificateSHA256: nil
        )
        
        // Should throw before even connecting
        XCTAssertThrowsError(try makeManager(profile: profile, password: "s3cret")) { error in
            XCTAssertEqual(error as? ConnectionError, .untrustedCertificate)
        }
    }

    func testNoPrintStatementsInVictronKit() throws {
        let victronKitPath = #filePath.components(separatedBy: "/Tests/").first ?? ""
        let victronKitDir = victronKitPath + "/Sources/VictronKit"
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(atPath: victronKitDir) else {
            XCTFail("Could not read VictronKit directory")
            return
        }
        
        for file in files where file.hasSuffix(".swift") {
            let filePath = victronKitDir + "/" + file
            let content = try String(contentsOfFile: filePath)
            
            // Check for print statements
            if content.range(of: #"(^|[^A-Za-z0-9_.])print\("#, options: .regularExpression) != nil {   // a real print( call, not e.g. sha256Fingerprint(
                XCTFail("Found print statement in \(file)")
            }
            
            // Check for password interpolation
            if content.range(of: #"\\\([^)]*[Pp]assword"#, options: .regularExpression) != nil {   // an interpolation that contains a password
                XCTFail("Found password interpolation in \(file)")
            }
        }
    }
}