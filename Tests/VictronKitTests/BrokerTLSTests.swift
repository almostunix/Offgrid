import XCTest
import CocoaMQTT
import Security

/// T-12: the Mosquitto test broker with TLS + username/password (like the Cerbo's 8883), using a throwaway test CA.
/// Trust uses CocoaMQTT's own `trustedServerCertificates` (no hand-written trust evaluation). Local only.
final class BrokerTLSTests: XCTestCase {
    var broker: TestBroker!
    let queue = DispatchQueue(label: "BrokerTLSTests")

    override func setUpWithError() throws {
        broker = TestBroker(tls: true, username: "cerbo", password: "s3cret")
        try broker.start()
    }

    override func tearDown() {
        broker?.stop()
        broker = nil
        super.tearDown()
    }

    /// The test CA as a SecCertificate (the file is PEM; Security wants DER).
    private func testCA() throws -> SecCertificate {
        let url = try XCTUnwrap(broker.caCertificateURL)
        let pem = try String(contentsOf: url, encoding: .utf8)
        let base64 = pem.components(separatedBy: .newlines).filter { !$0.hasPrefix("-----") }.joined()
        let der = try XCTUnwrap(Data(base64Encoded: base64))
        return try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
    }

    private func client(password: String, trustTestCA: Bool) throws -> CocoaMQTT {
        let mqtt = CocoaMQTT(clientID: "tls-test-" + UUID().uuidString, host: "127.0.0.1", port: broker.port)
        mqtt.delegateQueue = queue
        mqtt.enableSSL = true
        mqtt.username = "cerbo"
        mqtt.password = password
        mqtt.autoReconnect = false
        if trustTestCA {
            mqtt.trustedServerCertificates = [try testCA()]
            mqtt.usesSystemTrustStore = false
        }
        return mqtt
    }

    /// Connects and returns the CONNACK, or nil if the connection ended (or timed out) without one.
    private func connectResult(_ mqtt: CocoaMQTT, timeout: TimeInterval = 10) -> CocoaMQTTConnAck? {
        var result: CocoaMQTTConnAck?
        let done = expectation(description: "connect finished")
        done.assertForOverFulfill = false
        mqtt.didConnectAck = { _, ack in result = ack; done.fulfill() }
        mqtt.didDisconnect = { _, _ in done.fulfill() }
        _ = mqtt.connect()
        wait(for: [done], timeout: timeout)
        mqtt.disconnect()
        return queue.sync { result }
    }

    func testCorrectCredentialsAndTrustedCAConnect() throws {
        XCTAssertEqual(connectResult(try client(password: "s3cret", trustTestCA: true)), .accept)
    }

    func testWrongPasswordIsRejected() throws {
        let ack = connectResult(try client(password: "wrong", trustTestCA: true))
        XCTAssertNotEqual(ack, .accept, "a wrong password must never be accepted")
    }

    func testUntrustedCertificateIsRejected() throws {
        // Only the system trust store: the throwaway test CA isn't in it, so TLS must fail before any CONNACK.
        let ack = connectResult(try client(password: "s3cret", trustTestCA: false))
        XCTAssertNil(ack, "an untrusted certificate must not get as far as MQTT")
    }
}
