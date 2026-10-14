//
// TopicParserTests.swift
//
// Tests for TopicParser functionality.
//

import XCTest
@testable import VictronKit

final class TopicParserTests: XCTestCase {
    var parser: TopicParser!
    
    override func setUp() {
        super.setUp()
        parser = TopicParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Portal ID Detection Tests
    
    func testPortalIdDetectionFromFirstMessage() throws {
        // Parser should learn portal ID from first valid N/portalId/... message
        let topic = "N/c0ffee000001/system/0/Serial"
        let parsed = parser.parseTopic(topic)
        XCTAssertNotNil(parsed)
        
        XCTAssertEqual(parser.detectedPortalId, "c0ffee000001")
    }
    
    func testPortalIdDetectionFromMultipleMessages() throws {
        // Parser should learn portal ID from first message
        let topic1 = "N/c0ffee000001/system/0/Serial"
        let topic2 = "N/c0ffee000001/battery/279/Voltage"
        
        let parsed1 = parser.parseTopic(topic1)
        let parsed2 = parser.parseTopic(topic2)
        XCTAssertNotNil(parsed1)
        XCTAssertNotNil(parsed2)
        
        // Should still be the first portal ID
        XCTAssertEqual(parser.detectedPortalId, "c0ffee000001")
    }
    
    func testPortalIdNotDetectedFromNonNTopic() {
        // Parser should not learn portal ID from non-N topics
        let topic = "R/c0ffee000001/keepalive"
        let parsed = parser.parseTopic(topic)
        XCTAssertNil(parsed)
        
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testPortalIdNotDetectedFromNPlusTopic() {
        // Parser should not learn portal ID from N/+ topics (portal ID is empty)
        let topic = "N/+/system/0/Serial"
        let parsed = parser.parseTopic(topic)
        XCTAssertNil(parsed)
        
        XCTAssertNil(parser.detectedPortalId)
    }
    
    // MARK: - Topic Parsing Tests
    
    func testValidTopicParsing() throws {
        let topic = "N/c0ffee000001/system/0/Serial"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNotNil(parsed)
        
        let parsedTopic = try XCTUnwrap(parsed)
        XCTAssertEqual(parsedTopic.portalId, "c0ffee000001")
        XCTAssertEqual(parsedTopic.service, "system")
        XCTAssertEqual(parsedTopic.instance, "0")
        XCTAssertEqual(parsedTopic.path, ["Serial"])
        XCTAssertEqual(parsedTopic.fullTopic, topic)
    }
    
    func testTopicWithMultiplePathComponents() throws {
        let topic = "N/c0ffee000001/system/0/Dc/Battery/Soc"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNotNil(parsed)
        
        let parsedTopic = try XCTUnwrap(parsed)
        XCTAssertEqual(parsedTopic.portalId, "c0ffee000001")
        XCTAssertEqual(parsedTopic.service, "system")
        XCTAssertEqual(parsedTopic.instance, "0")
        XCTAssertEqual(parsedTopic.path, ["Dc", "Battery", "Soc"])
    }
    
    func testSpecialTopicParsing() throws {
        // Special topics like full_publish_completed have only 3 parts
        let topic = "N/c0ffee000001/full_publish_completed"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNotNil(parsed)
        
        let parsedTopic = try XCTUnwrap(parsed)
        XCTAssertEqual(parsedTopic.portalId, "c0ffee000001")
        XCTAssertEqual(parsedTopic.service, "full_publish_completed")
        XCTAssertEqual(parsedTopic.instance, "")
        XCTAssertEqual(parsedTopic.path, [])
    }
    
    func testInvalidTopicWithEmptyPortalId() {
        let topic = "N//battery/279/Soc"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicWithEmptyService() {
        let topic = "N/c0ffee000001//279/Soc"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicWithEmptyInstance() {
        let topic = "N/c0ffee000001/battery//Soc"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicNotStartingWithN() {
        let topic = "R/c0ffee000001/keepalive"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicNOnly() {
        let topic = "N"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicNWithSlash() {
        let topic = "N/"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicNWithPortalIdOnly() {
        let topic = "N/c0ffee000001"
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testInvalidTopicEmpty() {
        let topic = ""
        let parsed = parser.parseTopic(topic)
        
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId)
    }
    
    func testTopicWithEmptyPathComponents() throws {
        let topic = "N/c0ffee000001/system/0//Serial"
        let parsed = parser.parseTopic(topic)
        
        // Topics with empty path components should be invalid
        XCTAssertNil(parsed)
        XCTAssertNil(parser.detectedPortalId) // Should not learn from invalid topic
    }
    
    // MARK: - Payload Parsing Tests
    
    func testNumericPayloadParsing() throws {
        let payload: [String: Any] = ["value": 78.5]
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNotNil(parsed)
        
        if case .number(let value) = try XCTUnwrap(parsed) {
            XCTAssertEqual(value, 78.5)
        } else {
            XCTFail("Expected number payload")
        }
    }
    
    func testIntegerPayloadParsing() throws {
        let payload: [String: Any] = ["value": 1]
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNotNil(parsed)
        
        if case .number(let value) = try XCTUnwrap(parsed) {
            XCTAssertEqual(value, 1.0)
        } else {
            XCTFail("Expected number payload")
        }
    }
    
    func testStringPayloadParsing() throws {
        let payload: [String: Any] = ["value": "HQ212200XA"]
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNotNil(parsed)
        
        if case .string(let value) = try XCTUnwrap(parsed) {
            XCTAssertEqual(value, "HQ212200XA")
        } else {
            XCTFail("Expected string payload")
        }
    }
    
    func testNullPayloadParsing() throws {
        let payload: [String: Any] = ["value": NSNull()]
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNotNil(parsed)
        
        if case .null = try XCTUnwrap(parsed) {
            // Success
        } else {
            XCTFail("Expected null payload")
        }
    }
    
    func testArrayPayloadParsing() throws {
        let payload: [String: Any] = ["value": [1, 2, 3]]
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNotNil(parsed)
        
        if case .array(let values) = try XCTUnwrap(parsed) {
            XCTAssertEqual(values.count, 3)
            
            if case .number(let v1) = values[0] { XCTAssertEqual(v1, 1.0) }
            else { XCTFail("Expected number at index 0") }
            
            if case .number(let v2) = values[1] { XCTAssertEqual(v2, 2.0) }
            else { XCTFail("Expected number at index 1") }
            
            if case .number(let v3) = values[2] { XCTAssertEqual(v3, 3.0) }
            else { XCTFail("Expected number at index 2") }
        } else {
            XCTFail("Expected array payload")
        }
    }
    
    func testMixedArrayPayloadParsing() throws {
        let payload: [String: Any] = ["value": [1, "test", NSNull(), [2, 3]]]
        let parsed = parser.parsePayload(payload)
        
        // This should succeed because all types are supported
        XCTAssertNotNil(parsed)
        
        if case .array(let values) = try XCTUnwrap(parsed) {
            XCTAssertEqual(values.count, 4)
            
            if case .number(let v1) = values[0] { XCTAssertEqual(v1, 1.0) }
            else { XCTFail("Expected number at index 0") }
            
            if case .string(let v2) = values[1] { XCTAssertEqual(v2, "test") }
            else { XCTFail("Expected string at index 1") }
            
            if case .null = values[2] { /* Success */ }
            else { XCTFail("Expected null at index 2") }
            
            if case .array(let v3) = values[3] {
                XCTAssertEqual(v3.count, 2)
                if case .number(let n1) = v3[0] { XCTAssertEqual(n1, 2.0) }
                else { XCTFail("Expected number at nested index 0") }
                if case .number(let n2) = v3[1] { XCTAssertEqual(n2, 3.0) }
                else { XCTFail("Expected number at nested index 1") }
            }
            else { XCTFail("Expected array at index 3") }
        } else {
            XCTFail("Expected array payload")
        }
    }
    
    func testPayloadWithoutValueKey() {
        let payload: [String: Any] = ["otherKey": "value"]
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNil(parsed)
    }
    
    func testInvalidPayloadType() {
        let payload: [String: Any] = ["value": ["key": "value"]] // Dictionary instead of value
        let parsed = parser.parsePayload(payload)
        
        XCTAssertNil(parsed)
    }
    
    // MARK: - Full Message Parsing Tests
    
    func testFullMessageParsing() throws {
        let topic = "N/c0ffee000001/system/0/Dc/Battery/Soc"
        let payload: [String: Any] = ["value": 78.5]
        
        let parsed = parser.parseMessage(topic: topic, payload: payload)
        
        XCTAssertNotNil(parsed)
        
        let parsedMessage = try XCTUnwrap(parsed)
        XCTAssertEqual(parsedMessage.topic.portalId, "c0ffee000001")
        XCTAssertEqual(parsedMessage.topic.service, "system")
        XCTAssertEqual(parsedMessage.topic.instance, "0")
        XCTAssertEqual(parsedMessage.topic.path, ["Dc", "Battery", "Soc"])
        
        if case .number(let value) = parsedMessage.value {
            XCTAssertEqual(value, 78.5)
        } else {
            XCTFail("Expected number value")
        }
    }
    
    func testFullMessageParsingWithStringValue() throws {
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload: [String: Any] = ["value": "HQ212200XA"]
        
        let parsed = parser.parseMessage(topic: topic, payload: payload)
        
        XCTAssertNotNil(parsed)
        
        let parsedMessage = try XCTUnwrap(parsed)
        
        if case .string(let value) = parsedMessage.value {
            XCTAssertEqual(value, "HQ212200XA")
        } else {
            XCTFail("Expected string value")
        }
    }
    
    func testFullMessageParsingFailsWithInvalidTopic() {
        let topic = "R/c0ffee000001/keepalive"
        let payload: [String: Any] = ["value": 1]
        
        let parsed = parser.parseMessage(topic: topic, payload: payload)
        
        XCTAssertNil(parsed)
    }
    
    func testFullMessageParsingFailsWithInvalidPayload() {
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload: [String: Any] = ["otherKey": "value"]
        
        let parsed = parser.parseMessage(topic: topic, payload: payload)
        
        XCTAssertNil(parsed)
    }
    
    // MARK: - Fixture Tests
    
    func testParseAllFixtureMessages() throws {
        // Test that all fixture messages can be parsed
        let fixtureFiles = ["system", "battery", "solarcharger", "vebus", "full_publish_completed"]
        
        for filename in fixtureFiles {
            let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "Fixtures")
            XCTAssertNotNil(url, "Could not find fixture file: \"$filename.json\"")
            
            guard let url = url else { continue }
            
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            XCTAssertNotNil(json, "JSON should be a dictionary")
            
            guard let json = json else { continue }
            
            // Verify portal ID
            XCTAssertEqual(json["portalId"] as? String, "c0ffee000001")
            
            // Verify messages array
            guard let messages = json["messages"] as? [[String: Any]] else {
                XCTFail("Messages should be an array of dictionaries")
                continue
            }
            
            // Test parsing each message
            for message in messages {
                guard let topic = message["topic"] as? String else {
                    XCTFail("Message should have a topic")
                    continue
                }
                
                guard let payload = message["payload"] as? [String: Any] else {
                    XCTFail("Message should have a payload")
                    continue
                }
                
                let parsed = parser.parseMessage(topic: topic, payload: payload)
                XCTAssertNotNil(parsed, "Should be able to parse message: \"$topic\"")
                
                // Verify portal ID in parsed topic
                if let parsed = parsed {
                    XCTAssertEqual(parsed.topic.portalId, "c0ffee000001")
                }
            }
        }
        
        // Verify portal ID was detected
        XCTAssertEqual(parser.detectedPortalId, "c0ffee000001")
    }
    
    func testParseAllFixturesComprehensive() throws {
        // Load and parse every fixture file
        let fixtureFiles = ["system", "battery", "solarcharger", "vebus", "full_publish_completed", "battery_history", "solarcharger_history"]
        
        for filename in fixtureFiles {
            let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "Fixtures")
            XCTAssertNotNil(url, "Could not find fixture file: \"$filename.json\"")
            
            guard let url = url else { continue }
            
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            XCTAssertNotNil(json, "JSON should be a dictionary for file: \"$filename.json\"")
            
            guard let json = json else { continue }
            
            // Verify portal ID
            XCTAssertEqual(json["portalId"] as? String, "c0ffee000001")
            
            // Verify messages array
            guard let messages = json["messages"] as? [[String: Any]] else {
                XCTFail("Messages should be an array of dictionaries for file: \"$filename.json\"")
                continue
            }
            
            // Parse each message
            for message in messages {
                guard let topic = message["topic"] as? String else {
                    XCTFail("Message should have a topic in file: \"$filename.json\"")
                    continue
                }
                
                guard let payload = message["payload"] as? [String: Any] else {
                    XCTFail("Message should have a payload in file: \"$filename.json\"")
                    continue
                }
                
                let parsed = parser.parseMessage(topic: topic, payload: payload)
                XCTAssertNotNil(parsed, "Should be able to parse message: \"$topic\" in file: \"$filename.json\"")
                
                // Verify portal ID in parsed topic
                if let parsed = parsed {
                    XCTAssertEqual(parsed.topic.portalId, "c0ffee000001")
                }
            }
        }
        
        // Verify portal ID was detected from first message
        XCTAssertEqual(parser.detectedPortalId, "c0ffee000001")
    }
    
    func testParseUnknownService() throws {
        // Test parsing topics with unknown services
        let topic = "N/c0ffee000001/unknownservice/123/Field"
        let payload: [String: Any] = ["value": 42]
        
        let parsed = parser.parseMessage(topic: topic, payload: payload)
        
        XCTAssertNotNil(parsed)
        
        let parsedMessage = try XCTUnwrap(parsed)
        XCTAssertEqual(parsedMessage.topic.service, "unknownservice")
        XCTAssertEqual(parsedMessage.topic.instance, "123")
        
        if case .number(let value) = parsedMessage.value {
            XCTAssertEqual(value, 42.0)
        } else {
            XCTFail("Expected number value")
        }
    }
    
    func testParseEmptyValue() throws {
        // Test parsing with null value
        let topic = "N/c0ffee000001/system/0/OptionalField"
        let payload: [String: Any] = ["value": NSNull()]
        
        let parsed = parser.parseMessage(topic: topic, payload: payload)
        
        XCTAssertNotNil(parsed)
        
        let parsedMessage = try XCTUnwrap(parsed)
        if case .null = parsedMessage.value {
            // Success
        } else {
            XCTFail("Expected null value")
        }
    }
}
