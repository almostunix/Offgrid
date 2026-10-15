//
// TopicExplorerTests.swift
//
// Tests for topic explorer functionality including ReceivedTopic tracking.
//

import XCTest
@testable import VictronKit

final class TopicExplorerTests: XCTestCase {
    var parser: TopicParser!
    var store: LiveDataStore!
    
    override func setUp() {
        super.setUp()
        parser = TopicParser()
        store = LiveDataStore()
    }
    
    override func tearDown() {
        parser = nil
        store = nil
        super.tearDown()
    }
    
    func testReceivedTopicsTracking() {
        // Initially, no topics should be tracked
        XCTAssertTrue(store.receivedTopics.isEmpty)
        
        // Add a topic
        let message1 = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", 
                                           payload: ["value": 78.5])
        guard let message1 = message1 else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message1)
        
        // Should now have 1 topic
        XCTAssertEqual(store.receivedTopics.count, 1)
        XCTAssertEqual(store.receivedTopics[0].topic, "N/c0ffee000001/system/0/Dc/Battery/Soc")
        XCTAssertEqual(store.receivedTopics[0].rawValue, "78.5")
    }
    
    func testReceivedTopicsWithMultipleValues() {
        // Add multiple topics
        let messages = [
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": -1250.0]),
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "SmartShunt 500A"])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            store.update(with: message)
        }
        
        // Should have 3 topics
        XCTAssertEqual(store.receivedTopics.count, 3)
        
        // Check each topic
        let topicsByName = Dictionary(uniqueKeysWithValues: store.receivedTopics.map { ($0.topic, $0) })
        
        XCTAssertNotNil(topicsByName["N/c0ffee000001/system/0/Dc/Battery/Soc"])
        XCTAssertEqual(topicsByName["N/c0ffee000001/system/0/Dc/Battery/Soc"]?.rawValue, "78.5")
        
        XCTAssertNotNil(topicsByName["N/c0ffee000001/system/0/Dc/Battery/Power"])
        XCTAssertEqual(topicsByName["N/c0ffee000001/system/0/Dc/Battery/Power"]?.rawValue, "-1250")
        
        XCTAssertNotNil(topicsByName["N/c0ffee000001/battery/279/ProductName"])
        XCTAssertEqual(topicsByName["N/c0ffee000001/battery/279/ProductName"]?.rawValue, "SmartShunt 500A")
    }
    
    func testReceivedTopicsUpdateOnRepeat() {
        // Add a topic
        let message1 = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", 
                                           payload: ["value": 78.5])
        guard let message1 = message1 else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message1)
        
        let firstTimestamp = store.receivedTopics[0].timestamp
        
        // Update the same topic with a new value
        let message2 = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", 
                                           payload: ["value": 80.0])
        guard let message2 = message2 else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message2)
        
        // Should still have only 1 topic (updated, not added)
        XCTAssertEqual(store.receivedTopics.count, 1)
        XCTAssertEqual(store.receivedTopics[0].topic, "N/c0ffee000001/system/0/Dc/Battery/Soc")
        XCTAssertEqual(store.receivedTopics[0].rawValue, "80")
        
        // Timestamp should be updated
        let secondTimestamp = store.receivedTopics[0].timestamp
        XCTAssertGreaterThanOrEqual(secondTimestamp.timeIntervalSince1970, 
                                    firstTimestamp.timeIntervalSince1970)
    }
    
    func testReceivedTopicsWithStringValues() {
        // Test with string values
        let message = parser.parseMessage(topic: "N/c0ffee000001/battery/279/ProductName", 
                                          payload: ["value": "SmartShunt 500A"])
        guard let message = message else {
            XCTFail("Should be able to parse message")
            return
        }
        store.update(with: message)
        
        XCTAssertEqual(store.receivedTopics.count, 1)
        XCTAssertEqual(store.receivedTopics[0].rawValue, "SmartShunt 500A")
    }
    
    func testReceivedTopicsWithNumberValues() {
        // Test with various number formats
        let messages = [
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": -1250.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1500]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 5])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            store.update(with: message)
        }
        
        XCTAssertEqual(store.receivedTopics.count, 4)
        
        let topicsByName = Dictionary(uniqueKeysWithValues: store.receivedTopics.map { ($0.topic, $0) })
        XCTAssertEqual(topicsByName["N/c0ffee000001/system/0/Dc/Battery/Soc"]?.rawValue, "78.5")
        XCTAssertEqual(topicsByName["N/c0ffee000001/system/0/Dc/Battery/Power"]?.rawValue, "-1250")
        XCTAssertEqual(topicsByName["N/c0ffee000001/system/0/Dc/Pv/Power"]?.rawValue, "1500")
        XCTAssertEqual(topicsByName["N/c0ffee000001/solarcharger/278/State"]?.rawValue, "5")
    }
    
    func testReceivedTopicIdentifiable() {
        // Test that ReceivedTopic conforms to Identifiable
        let topic = ReceivedTopic(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", 
                                  rawValue: "78.5", timestamp: Date())
        
        XCTAssertNotNil(topic.id)
        XCTAssertEqual(topic.id, topic.topic)
    }
    
    func testReceivedTopicEquatable() {
        // Test that ReceivedTopic conforms to Equatable
        let date = Date()
        let topic1 = ReceivedTopic(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", 
                                  rawValue: "78.5", timestamp: date)
        let topic2 = ReceivedTopic(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", 
                                  rawValue: "78.5", timestamp: date)
        let topic3 = ReceivedTopic(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", 
                                  rawValue: "-1250.0", timestamp: date)
        
        XCTAssertEqual(topic1, topic2)
        XCTAssertNotEqual(topic1, topic3)
    }
}
