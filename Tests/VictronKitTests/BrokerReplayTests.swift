import XCTest
import CocoaMQTT
@testable import VictronKit

final class BrokerReplayTests: XCTestCase {
    var broker: TestBroker!
    var replayer: FixtureReplayer!
    var mqtt: CocoaMQTT!
    var receivedMessages: [(topic: String, payload: String)] = []
    let expectationTimeout: TimeInterval = 10.0

    override func setUp() {
        super.setUp()
        broker = TestBroker()
        try! broker.start()

        // Replayer first, so it is subscribed before the test client can send anything.
        replayer = FixtureReplayer(broker: broker)
        try! replayer.start()

        mqtt = CocoaMQTT(clientID: "test-client", host: "127.0.0.1", port: broker.port)
        mqtt.keepAlive = 60
        mqtt.enableSSL = false
        
        let connectionExpectation = self.expectation(description: "Test client connected and subscribed")
        connectionExpectation.expectedFulfillmentCount = 1
        connectionExpectation.assertForOverFulfill = false
        
        mqtt.didConnectAck = { [weak self] mqtt, ack in
            guard let self = self else { return }
            if ack == .accept {
                mqtt.subscribe("N/c0ffee000001/#")
            }
        }
        mqtt.didSubscribeTopics = { _, success, _ in
            if success["N/c0ffee000001/#"] != nil { connectionExpectation.fulfill() }   // SUBACK received
        }

        DispatchQueue.main.async {
            _ = self.mqtt.connect()
        }

        // Wait for test client to be connected and subscribed
        waitForExpectations(timeout: 5.0, handler: nil)
        

        receivedMessages = []
    }

    override func tearDown() {
        mqtt.disconnect()
        replayer.stop()
        broker.stop()

        // Our own broker must be gone. (Not a global pgrep: other test runs may have their own brokers.)
        XCTAssertFalse(broker.isRunning, "this test's mosquitto should have stopped")

        super.tearDown()
    }

    /// Sends R/c0ffee000001/keepalive over MQTT the way the app will: through ReadOnlyPublisher.
    private func sendKeepalive(_ payload: String) {
        let client = mqtt!
        let publisher = try! ReadOnlyPublisher(portalId: "c0ffee000001") { topic, body in
            client.publish(topic, withString: body, qos: .qos0, retained: false)
        }
        try! publisher.publish(topic: "R/c0ffee000001/keepalive", payload: payload)
    }

    func testFullPublish() {
        let expectation = self.expectation(description: "Receive all fixture messages")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = false

        // Override callback for this test
        _ = mqtt.didReceiveMessage
        mqtt.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let self = self else { return }
            let payload = message.string ?? ""
            self.receivedMessages.append((topic: message.topic, payload: payload))

            // Check if we received full_publish_completed
            if message.topic == "N/c0ffee000001/full_publish_completed" {
                expectation.fulfill()
            }
        }


        // Keepalive over MQTT through ReadOnlyPublisher (the app's only way to publish)
        sendKeepalive("")

        waitForExpectations(timeout: expectationTimeout, handler: nil)

        // Verify we received all expected messages
        let fixtures = FixtureLoader.loadFixtures()
        print("Received messages count: (receivedMessages.count)")
        XCTAssertEqual(receivedMessages.count, fixtures.count + 1, "Should receive all fixture messages plus full_publish_completed")

        // Verify full_publish_completed is the last message
        guard let lastMessage = receivedMessages.last else {
            XCTFail("No messages received")
            return
        }
        print("Last message topic: (lastMessage.topic)")
        print("Last message payload: (lastMessage.payload)")
        XCTAssertEqual(lastMessage.topic, "N/c0ffee000001/full_publish_completed")
    }

    func testSuppressRepublish() {
        // Clear messages before test
        receivedMessages = []

        // Override callback for this test
        _ = mqtt.didReceiveMessage
        
        mqtt.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let self = self else { return }
            if message.topic.hasPrefix("N/c0ffee000001/") && !message.topic.contains("full_publish_completed") {
                // If we receive any fixture messages, the test will fail due to the assertion below
            }
        }

        // Keepalive over MQTT through ReadOnlyPublisher, with suppress-republish
        sendKeepalive("{\"keepalive-options\":[\"suppress-republish\"]}")

        // Wait for potential messages
        Thread.sleep(forTimeInterval: 1.0)
        
        // Verify no fixture messages were received
        let fixtureMessages = receivedMessages.filter { $0.topic.hasPrefix("N/c0ffee000001/") && !$0.topic.contains("full_publish_completed") }
        XCTAssertEqual(fixtureMessages.count, 0, "Should not receive fixture messages with suppress-republish")
    }

    func testFullPublishCompletedEcho() {
        let expectation = self.expectation(description: "Receive full_publish_completed with echo id")

        // Override callback for this test
        _ = mqtt.didReceiveMessage
        mqtt.didReceiveMessage = { [weak self] mqtt, message, id in
            guard let self = self else { return }
            if message.topic == "N/c0ffee000001/full_publish_completed" {
                let payload = message.string ?? ""
                XCTAssertTrue(payload.contains("echo-test-id"), "Should contain echo id in payload")
                expectation.fulfill()
            }
        }

        // Keepalive over MQTT through ReadOnlyPublisher, with an echo id
        sendKeepalive("{\"keepalive-options\":[{\"full-publish-completed-echo\":\"echo-test-id\"}]}")

        waitForExpectations(timeout: expectationTimeout, handler: nil)
    }
}
