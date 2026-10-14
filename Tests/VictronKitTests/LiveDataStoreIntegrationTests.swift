//
// LiveDataStoreIntegrationTests.swift
//
// Integration tests for LiveDataStore with TopicParser.
//

import XCTest
@testable import VictronKit

final class LiveDataStoreIntegrationTests: XCTestCase {
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
    
    func testIntegrationWithTopicParser() throws {
        // Test that LiveDataStore works correctly with TopicParser
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload: [String: Any] = ["value": "HQ212200XA"]
        
        // Parse the message
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        // Update the store
        store.update(with: message)
        
        // Verify the result
        XCTAssertEqual(store.portalId, "c0ffee000001")
        XCTAssertEqual(store.system.serial, "HQ212200XA")
    }
    
    func testIntegrationWithMultipleMessages() throws {
        // Test that LiveDataStore correctly processes multiple messages
        let messages = [
            (topic: "N/c0ffee000001/system/0/Serial", payload: ["value": "HQ212200XA"]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "Victron SmartShunt 500A"]),
            (topic: "N/c0ffee000001/battery/279/Dc/0/Voltage", payload: ["value": 12.8]),
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/278/Pv/V", payload: ["value": 24.5]),
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/276/Ac/Out/L1/P", payload: ["value": 851])
        ]
        
        for messageTuple in messages {
            guard let message = parser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) else {
                XCTFail("Should be able to parse message: \(messageTuple.topic)")
                return
            }
            
            store.update(with: message)
        }
        
        // Verify all models are populated correctly
        XCTAssertEqual(store.portalId, "c0ffee000001")
        XCTAssertEqual(store.system.serial, "HQ212200XA")
        XCTAssertEqual(store.system.batterySoc, 78.5)
        XCTAssertEqual(store.batteries["279"]?.productName, "Victron SmartShunt 500A")
        XCTAssertEqual(store.batteries["279"]?.voltage, 12.8)
        XCTAssertEqual(store.solarChargers["278"]?.productName, "MPPT 150/70")
        XCTAssertEqual(store.solarChargers["278"]?.pvVoltage, 24.5)
        XCTAssertEqual(store.inverters["276"]?.productName, "MultiPlus-II 48/5000")
        XCTAssertEqual(store.inverters["276"]?.acOutputPower, 851)
    }
    
    func testIntegrationWithInvalidMessages() throws {
        // Test that LiveDataStore handles invalid messages gracefully
        let initialSystem = store.system
        let initialCount = store.batteries.count
        
        // Try to update with an invalid topic (should not crash)
        let invalidTopic = "R/c0ffee000001/keepalive"
        let payload: [String: Any] = ["value": 1]
        
        guard let message = parser.parseMessage(topic: invalidTopic, payload: payload) else {
            // Parser should reject invalid topic
            XCTAssertTrue(true) // Expected
            return
        }
        
        // If parser somehow accepted it, store should handle it gracefully
        store.update(with: message)
        
        // State should not change
        XCTAssertEqual(store.system, initialSystem)
        XCTAssertEqual(store.batteries.count, initialCount)
    }
    
    func testIntegrationWithUnknownService() throws {
        // Test that LiveDataStore ignores unknown services
        let initialCount = store.batteries.count + store.solarChargers.count + store.inverters.count
        
        let topic = "N/c0ffee000001/unknownservice/123/Field"
        let payload: [String: Any] = ["value": 42]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        store.update(with: message)
        
        // Count should not change
        let finalCount = store.batteries.count + store.solarChargers.count + store.inverters.count
        XCTAssertEqual(initialCount, finalCount)
    }
    
    func testIntegrationWithNullValues() throws {
        // Test that LiveDataStore handles null values correctly
        let topic = "N/c0ffee000001/system/0/OptionalField"
        let payload: [String: Any] = ["value": NSNull()]
        
        guard let message = parser.parseMessage(topic: topic, payload: payload) else {
            XCTFail("Should be able to parse message")
            return
        }
        
        // Should not crash
        store.update(with: message)
        
        // System should still be valid
        XCTAssertNotNil(store.system)
    }
}
