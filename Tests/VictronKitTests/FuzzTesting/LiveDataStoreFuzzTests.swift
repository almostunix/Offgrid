//
// LiveDataStoreFuzzTests.swift
//
// Fuzz tests for LiveDataStore packet handling with random and malformed inputs.
//

import XCTest
@testable import VictronKit

final class LiveDataStoreFuzzTests: XCTestCase {
    // MARK: - Deterministic Fuzz Testing

    /// Fuzz test for LiveDataStore.handle() with random inputs
    /// Tests that the LiveDataStore can handle random MQTT messages without crashing
    func testLiveDataStoreHandlingWithRandomInputs() {
        let seeds: [UInt64] = [0, 1, 12345, 65536]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let liveDataStore = LiveDataStore()

            // Test 50 random messages per seed
            for _ in 0..<50 {
                let topic = rng.randomTopic()
                let payloadData = rng.randomJSONPayload()

                // Handling should never crash or hang
                liveDataStore.handle(topic: topic, payload: payloadData)
            }
        }
    }

    /// Fuzz test for LiveDataStore with truncated payloads
    func testLiveDataStoreHandlingWithTruncatedPayloads() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let liveDataStore = LiveDataStore()

            // Test with valid payloads that get truncated
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

                        // Handling should never crash or hang
                        liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: truncatedData)
                    }
                } catch {
                    continue
                }
            }
        }
    }

    /// Fuzz test for LiveDataStore with corrupted payloads
    func testLiveDataStoreHandlingWithCorruptedPayloads() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let liveDataStore = LiveDataStore()

            // Test with valid payloads that get corrupted
            let validPayloads: [[String: Any]] = [
                ["value": 78.5],
                ["value": "HQ212200XA"],
                ["value": NSNull()],
                ["value": [1, 2, 3]]
            ]

            for payload in validPayloads {
                do {
                    let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])

                    // Test various corruption points
                    for _ in 0..<10 {
                        let corruptedData = rng.corruptedData(from: payloadData)

                        // Handling should never crash or hang
                        liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: corruptedData)
                    }
                } catch {
                    continue
                }
            }
        }
    }

    // MARK: - Edge Case Tests

    /// Test LiveDataStore handling with empty inputs
    func testLiveDataStoreHandlingWithEmptyInputs() {
        let liveDataStore = LiveDataStore()

        // Empty payload means device disappeared
        liveDataStore.handle(topic: "N/c0ffee000001/battery/279/Soc", payload: Data())
        
        // Empty topic and payload
        liveDataStore.handle(topic: "", payload: Data())
        liveDataStore.handle(topic: "", payload: Data())

        // Invalid topics with empty payloads
        liveDataStore.handle(topic: "R/test/keepalive", payload: Data())
        liveDataStore.handle(topic: "invalid", payload: Data())
    }

    /// Test LiveDataStore handling with malformed JSON
    func testLiveDataStoreHandlingWithMalformedJSON() {
        let liveDataStore = LiveDataStore()

        // Malformed JSON strings
        let malformedJSONs = [
            "",
            "{",
            "}",
            "[",
            "]",
            "{value: 1}",
            "{\"value\":}",
            "{\"value\": }",
            "{\"value\": ,}",
        ]

        for jsonString in malformedJSONs {
            if let data = jsonString.data(using: .utf8) {
                // Handling should never crash or hang
                liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: data)
            }
        }
    }

    /// Test LiveDataStore handling with very long inputs
    func testLiveDataStoreHandlingWithVeryLongInputs() {
        let liveDataStore = LiveDataStore()

        // Very long topic
        let longTopic = "N/" + String(repeating: "a", count: 1000) + "/" + String(repeating: "b", count: 1000)
        let longPayload: [String: Any] = ["value": String(repeating: "x", count: 10000)]

        do {
            let payloadData = try JSONSerialization.data(withJSONObject: longPayload, options: [])
            
            // Handling should never crash or hang
            liveDataStore.handle(topic: longTopic, payload: payloadData)
        } catch {
            XCTFail("Should be able to handle long inputs")
        }
    }

    /// Test LiveDataStore handling with topics containing wildcards
    func testLiveDataStoreHandlingWithWildcardTopics() {
        let liveDataStore = LiveDataStore()

        // Topics with wildcards
        let wildcardTopics = [
            "N/+/system/0/Serial",
            "N/c0ffee000001/+/0/Serial",
            "N/#",
            "N/c0ffee000001/#",
        ]

        let payload: [String: Any] = ["value": 42]
        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])

            for topic in wildcardTopics {
                // Handling should never crash or hang
                liveDataStore.handle(topic: topic, payload: payloadData)
            }
        } catch {
            XCTFail("Should be able to handle wildcard topics")
        }
    }

    /// Test LiveDataStore handling with invalid UTF-8 data
    func testLiveDataStoreHandlingWithInvalidUTF8() {
        let liveDataStore = LiveDataStore()

        // Invalid UTF-8 sequences
        let invalidUTF8Data = Data([0xFF, 0xFE, 0xFD, 0x80, 0x81, 0x82])
        let mixedData = Data([0x48, 0x65, 0xFF, 0x6C, 0x6C, 0x6F]) // "Hell" + invalid + "lo"

        // Handling should never crash or hang
        liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: invalidUTF8Data)
        liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: mixedData)
    }

    // MARK: - Stress Tests

    /// Stress test with many rapid handling operations
    func testStressManyRapidHandlingOperations() {
        let liveDataStore = LiveDataStore()
        var rng = SplitMix64(seed: 42)

        // Test 100 rapid handling operations
        for _ in 0..<100 {
            let topic = rng.randomTopic()
            let payloadData = rng.randomJSONPayload()

            // Rapid handling should not cause issues
            liveDataStore.handle(topic: topic, payload: payloadData)
        }
    }

    /// Stress test with alternating empty and non-empty payloads
    func testStressAlternatingEmptyAndNonEmptyPayloads() {
        let liveDataStore = LiveDataStore()

        // Alternate between empty and non-empty payloads
        for i in 0..<50 {
            if i % 2 == 0 {
                // Non-empty payload
                let payload: [String: Any] = ["value": Double(i)]
                do {
                    let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
                    liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: payloadData)
                } catch {
                    continue
                }
            } else {
                // Empty payload (device disappeared)
                liveDataStore.handle(topic: "N/c0ffee000001/system/0/Serial", payload: Data())
            }
        }
    }

    /// Stress test with rapid topic switching
    func testStressRapidTopicSwitching() {
        let liveDataStore = LiveDataStore()
        let payload: [String: Any] = ["value": 42]

        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])

            // Rapidly switch between different topics
            let topics = [
                "N/c0ffee000001/system/0/Serial",
                "N/c0ffee000001/battery/279/Voltage",
                "N/c0ffee000001/solarcharger/250/Current",
                "N/c0ffee000001/vebus/300/State",
                "N/c0ffee000001/system/0/Dc/Battery/Soc",
                "N/c0ffee000001/full_publish_completed"
            ]

            for _ in 0..<100 {
                for topic in topics {
                    liveDataStore.handle(topic: topic, payload: payloadData)
                }
            }
        } catch {
            XCTFail("Should be able to handle rapid topic switching")
        }
    }

    /// Test that LiveDataStore doesn't crash with concurrent portal IDs
    func testLiveDataStoreWithMultiplePortalIDs() {
        let liveDataStore = LiveDataStore()
        let payload: [String: Any] = ["value": 42]

        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])

            // Handle messages from different portal IDs
            let topics = [
                "N/c0ffee000001/system/0/Serial",
                "N/c0ffee000002/battery/279/Voltage",
                "N/c0ffee000003/solarcharger/250/Current"
            ]

            for topic in topics {
                liveDataStore.handle(topic: topic, payload: payloadData)
            }

            // The store keeps the FIRST portal ID it sees and ignores other installations (T-17 design).
            XCTAssertEqual(liveDataStore.portalId, "c0ffee000001")

            // Repeating them changes nothing: other portals stay ignored
            for topic in topics {
                liveDataStore.handle(topic: topic, payload: payloadData)
            }
        } catch {
            XCTFail("Should be able to handle multiple portal IDs")
        }
    }
}
