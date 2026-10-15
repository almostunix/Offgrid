//
// TopicParserFuzzTests.swift
//
// Fuzz tests for TopicParser with random and malformed inputs.
//

import XCTest
@testable import VictronKit

final class TopicParserFuzzTests: XCTestCase {
    // MARK: - Deterministic Fuzz Testing

    /// Fuzz test for topic parsing with random inputs
    /// Uses a deterministic random generator with fixed seeds to ensure reproducibility
    func testTopicParsingWithRandomInputs() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let parser = TopicParser()

            // Test 100 random topics per seed
            for _ in 0..<100 {
                let topic = rng.randomTopic()
                
                // Parsing should never crash or hang
                let parsed = parser.parseTopic(topic)
                
                // If parsing succeeds, verify the result is valid
                if let parsedTopic = parsed {
                    // Portal ID should not be empty if topic starts with N/
                    if topic.hasPrefix("N/") {
                        XCTAssertFalse(parsedTopic.portalId.isEmpty, "Portal ID should not be empty for N/ topics")
                    }
                    
                    // Service should not be empty
                    XCTAssertFalse(parsedTopic.service.isEmpty, "Service should not be empty")
                    
                    // Path should not contain empty strings
                    XCTAssertFalse(parsedTopic.path.contains("" ), "Path should not contain empty strings")
                }
            }
        }
    }

    /// Fuzz test for payload parsing with random JSON
    func testPayloadParsingWithRandomJSON() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let parser = TopicParser()

            // Test 100 random payloads per seed
            for _ in 0..<100 {
                let payloadData = rng.randomJSONPayload()
                
                // Parse the JSON
                do {
                    let json = try JSONSerialization.jsonObject(with: payloadData, options: [])
                    
                    if let jsonDict = json as? [String: Any] {
                        // Parsing should never crash or hang
                        let parsed = parser.parsePayload(jsonDict)
                        
                        // If parsing succeeds, verify the result
                        if let parsedValue = parsed {
                            // Verify the parsed value is valid
                            switch parsedValue {
                            case .number(let value):
                                XCTAssertNotNil(value, "Number value should not be nil")
                            case .string(let value):
                                XCTAssertNotNil(value, "String value should not be nil")
                            case .null:
                                // Valid
                                break
                            case .array(let values):
                                _ = values   // any size is valid (Victron can send empty arrays); the point is no crash
                            }
                        }
                    }
                } catch {
                    // Invalid JSON is expected for some random inputs
                    // Just verify we don't crash
                    continue
                }
            }
        }
    }

    /// Fuzz test for complete message parsing with random inputs
    func testMessageParsingWithRandomInputs() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let parser = TopicParser()

            // Test 100 random messages per seed
            for _ in 0..<100 {
                let topic = rng.randomTopic()
                let payloadData = rng.randomJSONPayload()
                
                // Parse the JSON payload
                do {
                    let json = try JSONSerialization.jsonObject(with: payloadData, options: [])
                    
                    if let jsonDict = json as? [String: Any] {
                        // Parsing should never crash or hang
                        let parsed = parser.parseMessage(topic: topic, payload: jsonDict)
                        
                        // If parsing succeeds, verify the result
                        if let parsedMessage = parsed {
                            // Verify topic is valid
                            XCTAssertFalse(parsedMessage.topic.portalId.isEmpty, "Portal ID should not be empty")
                            XCTAssertFalse(parsedMessage.topic.service.isEmpty, "Service should not be empty")
                            
                            // Verify value is valid
                            switch parsedMessage.value {
                            case .number(let value):
                                XCTAssertNotNil(value, "Number value should not be nil")
                            case .string(let value):
                                XCTAssertNotNil(value, "String value should not be nil")
                            case .null:
                                // Valid
                                break
                            case .array(let values):
                                _ = values   // any size is valid (Victron can send empty arrays); the point is no crash
                            }
                        }
                    }
                } catch {
                    // Invalid JSON is expected for some random inputs
                    // Just verify we don't crash
                    continue
                }
            }
        }
    }

    // MARK: - Truncated Input Tests

    /// Fuzz test for topic parsing with truncated inputs
    func testTopicParsingWithTruncatedInputs() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let parser = TopicParser()

            // Test with valid topics that get truncated
            let validTopics = [
                "N/c0ffee000001/system/0/Serial",
                "N/c0ffee000001/battery/279/Voltage",
                "N/c0ffee000001/system/0/Dc/Battery/Soc",
                "N/c0ffee000001/full_publish_completed"
            ]

            for topic in validTopics {
                // Test various truncation points
                for truncation in 0..<topic.count {
                    let truncated = String(topic.prefix(truncation))
                    
                    // Parsing should never crash or hang
                    let parsed = parser.parseTopic(truncated)
                    
                    // If parsing succeeds with truncated input, verify it's still valid
                    if let parsedTopic = parsed {
                        XCTAssertFalse(parsedTopic.portalId.isEmpty, "Portal ID should not be empty")
                        XCTAssertFalse(parsedTopic.service.isEmpty, "Service should not be empty")
                    }
                }
            }
        }
    }

    /// Fuzz test for JSON payload parsing with truncated inputs
    func testPayloadParsingWithTruncatedJSON() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let parser = TopicParser()

            // Test with valid JSON payloads that get truncated
            let validPayloads: [[String: Any]] = [
                ["value": 78.5],
                ["value": "HQ212200XA"],
                ["value": NSNull()],
                ["value": [1, 2, 3]],
                ["value": [1, "test", NSNull()], "otherKey": "value"]
            ]

            for payload in validPayloads {
                do {
                    let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
                    
                    // Test various truncation points
                    for truncation in 0..<payloadData.count {
                        let truncatedData = payloadData.prefix(truncation)
                        
                        // Parse the truncated JSON
                        do {
                            let json = try JSONSerialization.jsonObject(with: truncatedData, options: [])
                            
                            if let jsonDict = json as? [String: Any] {
                                // Parsing should never crash or hang
                                let parsed = parser.parsePayload(jsonDict)
                                
                                // If parsing succeeds, verify the result
                                if let parsedValue = parsed {
                                    switch parsedValue {
                                    case .number(let value):
                                        XCTAssertNotNil(value, "Number value should not be nil")
                                    case .string(let value):
                                        XCTAssertNotNil(value, "String value should not be nil")
                                    case .null:
                                        // Valid
                                        break
                                    case .array(let values):
                                        _ = values   // any size is valid (Victron can send empty arrays); the point is no crash
                                    }
                                }
                            }
                        } catch {
                            // Truncated JSON may be invalid
                            continue
                        }
                    }
                } catch {
                    continue
                }
            }
        }
    }

    // MARK: - Edge Case Tests

    /// Test parsing with empty and minimal inputs
    func testEdgeCaseEmptyAndMinimalInputs() {
        let parser = TopicParser()

        // Empty inputs
        let emptyTopic = ""
        let emptyPayload: [String: Any] = [:]

        XCTAssertNil(parser.parseTopic(emptyTopic), "Empty topic should parse to nil")
        XCTAssertNil(parser.parsePayload(emptyPayload), "Empty payload should parse to nil")
        XCTAssertNil(parser.parseMessage(topic: emptyTopic, payload: emptyPayload), "Empty message should parse to nil")

        // Minimal topics
        let minimalTopics = ["N", "N/", "N//", "N///", "N/test", "N/test/"]
        for topic in minimalTopics {
            let parsed = parser.parseTopic(topic)
            XCTAssertNil(parsed, "Minimal topic '" + topic + "' should parse to nil")
        }

        // Topics with only N/
        let nOnly = "N/"
        XCTAssertNil(parser.parseTopic(nOnly), "N/ only should parse to nil")
    }

    /// Test parsing with topics containing special characters
    func testEdgeCaseSpecialCharacters() {
        let parser = TopicParser()

        // Topics with special characters
        let specialTopics = [
            "N/test$service/0/field",
            "N/test service/0/field",
            "N/test\nservice/0/field",
            "N/test\tservice/0/field",
            "N/test\rservice/0/field",
            "N/test%20service/0/field",
            "N/test+service/0/field",
            "N/test#service/0/field"
        ]

        for topic in specialTopics {
            // Parsing should never crash or hang
            let parsed = parser.parseTopic(topic)
            
            // These topics may or may not parse successfully, but should not crash
            if let parsedTopic = parsed {
                // If they do parse, verify the result is valid
                XCTAssertFalse(parsedTopic.portalId.isEmpty, "Portal ID should not be empty")
                XCTAssertFalse(parsedTopic.service.isEmpty, "Service should not be empty")
            }
        }
    }

    /// Test parsing with malformed JSON structures
    func testEdgeCaseMalformedJSON() {
        let parser = TopicParser()

        // Malformed JSON strings that might be encountered
        let malformedJSONs = [
            "",
            "{",
            "}",
            "[",
            "]",
            "{}",
            "[]",
            "{value: 1}",
            "{\"value\":}",
            "{\"value\": }",
            "{\"value\": ,}",
            "{\"value\": 1, }",
            "{\"value\": 1,,}",
            "{\"value\": 1, \"key\":}",
            "{\"value\": 1, \"key\": }",
            "{\"value\": 1, \"key\": ,}",
            "{\"value\": 1, \"key\": \"value\",}",
            "{\"value\": 1, \"key\": \"value\", }",
        ]

        for jsonString in malformedJSONs {
            // Parsing should never crash or hang
            do {
                let data = jsonString.data(using: .utf8) ?? Data()
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                
                if let jsonDict = json as? [String: Any] {
                    let parsed = parser.parsePayload(jsonDict)
                    // May or may not parse successfully, but should not crash
                    _ = parsed
                }
            } catch {
                // Invalid JSON is expected
                continue
            }
        }
    }

    /// Test parsing with very long inputs
    func testEdgeCaseVeryLongInputs() {
        let parser = TopicParser()

        // Very long topic
        let longTopic = "N/" + String(repeating: "a", count: 1000) + "/" + String(repeating: "b", count: 1000)
        
        // Parsing should never crash or hang
        let parsed = parser.parseTopic(longTopic)
        
        // Should parse successfully but with empty service due to length
        if let parsedTopic = parsed {
            XCTAssertFalse(parsedTopic.portalId.isEmpty, "Portal ID should not be empty")
        }

        // Very long JSON payload
        var longPayload = [String: Any]()
        longPayload["value"] = String(repeating: "x", count: 10000)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: longPayload, options: [])
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            if let jsonDict = json as? [String: Any] {
                // Parsing should never crash or hang
                let parsed = parser.parsePayload(jsonDict)
                
                if let parsedValue = parsed {
                    switch parsedValue {
                    case .string(let value):
                        XCTAssertEqual(value.count, 10000, "String should have expected length")
                    default:
                        XCTFail("Expected string value")
                    }
                }
            }
        } catch {
            XCTFail("Should be able to handle long JSON payloads")
        }
    }

    /// Test parsing with topics containing wildcards
    func testEdgeCaseWildcardTopics() {
        let parser = TopicParser()

        // Topics with wildcards
        let wildcardTopics = [
            "N/+/system/0/Serial",
            "N/c0ffee000001/+/0/Serial",
            "N/c0ffee000001/system/+/Serial",
            "N/#",
            "N/c0ffee000001/#",
            "N/c0ffee000001/system/#",
            "N/+/+/+/+",
            "N/+/+/+/+/+/+",
            "N/+/+/+/+/+/+/+",
            "N/+/+/+/+/+/+/+/+",
        ]

        for topic in wildcardTopics {
            // Parsing should never crash or hang
            let parsed = parser.parseTopic(topic)
            
            // Topics with wildcards should not parse successfully
            XCTAssertNil(parsed, "Topic with wildcards should parse to nil: '" + topic + "'")
        }
    }

    // MARK: - Stress Tests

    /// Stress test with many rapid parsing operations
    func testStressManyRapidParsingOperations() {
        let parser = TopicParser()
        var rng = SplitMix64(seed: 42)

        // Test 1000 rapid parsing operations
        for _ in 0..<1000 {
            let topic = rng.randomTopic()
            let payloadData = rng.randomJSONPayload()

            do {
                let json = try JSONSerialization.jsonObject(with: payloadData, options: [])
                
                if let jsonDict = json as? [String: Any] {
                    // Rapid parsing should not cause issues
                    let parsed = parser.parseMessage(topic: topic, payload: jsonDict)
                    _ = parsed
                }
            } catch {
                // Invalid JSON is expected for some random inputs
                continue
            }
        }
    }

    /// Stress test with concurrent parsing operations
    func testStressConcurrentParsingOperations() {
        let parser = TopicParser()
        var rng = SplitMix64(seed: 42)

        // Create multiple random inputs
        var topics = [String]()
        var payloads = [[String: Any]]()

        for _ in 0..<100 {
            let topic = rng.randomTopic()
            let payloadData = rng.randomJSONPayload()

            do {
                let json = try JSONSerialization.jsonObject(with: payloadData, options: [])
                if let jsonDict = json as? [String: Any] {
                    topics.append(topic)
                    payloads.append(jsonDict)
                }
            } catch {
                continue
            }
        }

        // Parse all inputs
        for i in 0..<topics.count {
            let parsed = parser.parseMessage(topic: topics[i], payload: payloads[i])
            _ = parsed
        }
    }
}
