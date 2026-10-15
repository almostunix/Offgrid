
//
// ReadOnlyPublisherFuzzTests.swift
//
// Fuzz tests for ReadOnlyPublisher with random and malformed inputs.
//

import XCTest
@testable import VictronKit

final class ReadOnlyPublisherFuzzTests: XCTestCase {
    // MARK: - Deterministic Fuzz Testing

    /// Fuzz test for ReadOnlyPublisher with random topics
    /// Tests that random topics never crash and valid topics follow R/<portalId>/ pattern
    func testReadOnlyPublisherWithRandomTopics() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]
        let portalId = "c0ffee000001"

        var acceptedTopics: [String] = []

        for seed in seeds {
            var rng = SplitMix64(seed: seed)

            // Test 1000 random topics per seed (10,000 total)
            for n in 0..<1000 {
                // every 4th input starts with the allowed prefix, so the accept path is exercised too
                let topic = n % 4 == 0 ? "R/" + portalId + "/" + rng.randomTopic() : rng.randomTopic()

                do {
                    let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }
                    try publisher.publish(topic: topic, payload: "test")

                    // If topic was accepted, verify it follows the required pattern
                    acceptedTopics.append(topic)

                } catch {
                    // Topic should be rejected - this is expected for most random topics
                    continue
                }
            }
        }

        // Verify property: all accepted topics must start with R/<portalId>/
        let requiredPrefix = "R/" + portalId + "/"
        for topic in acceptedTopics {
            XCTAssertTrue(topic.hasPrefix(requiredPrefix), "Accepted topic must start with R/<portalId>/: '" + topic + "'")
            
            // Verify no forbidden characters in accepted topics
            XCTAssertFalse(topic.contains("+"), "Accepted topic must not contain +: '" + topic + "'")
            XCTAssertFalse(topic.contains("#"), "Accepted topic must not contain #: '" + topic + "'")
            XCTAssertFalse(topic.contains("\0"), "Accepted topic must not contain NUL: '" + topic + "'")
        }

        // Should have accepted at least some topics (the ones we manually construct)
        XCTAssertGreaterThan(acceptedTopics.count, 0, "Should accept at least some valid topics")
    }

    /// Fuzz test for ReadOnlyPublisher initialization with random portal IDs
    func testReadOnlyPublisherInitializationWithRandomPortalIds() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)

            // Test 100 random portal IDs per seed
            for _ in 0..<100 {
                let portalId = rng.randomString(length: 20, allowEmpty: true)

                // Initialization should never crash
                do {
                    _ = try ReadOnlyPublisher(portalId: portalId) { _, _ in }
                } catch {
                    // Invalid portal IDs should throw errors - this is expected
                    continue
                }
            }
        }
    }

    /// Fuzz test for ReadOnlyPublisher with truncated inputs
    func testReadOnlyPublisherWithTruncatedInputs() {
        let seeds: [UInt64] = [0, 1, 12345]
        let portalId = "c0ffee000001"

        for seed in seeds {
            var rng = SplitMix64(seed: seed)

            // Test with valid topics that get truncated
            let validTopics = [
                "R/c0ffee000001/system/0/Serial",
                "R/c0ffee000001/battery/279/Voltage",
                "R/c0ffee000001/system/0/Dc/Battery/Soc",
                "R/c0ffee000001/full_publish_completed"
            ]

            for topic in validTopics {
                // Test various truncation points
                for truncation in 0..<topic.count {
                    let truncated = String(topic.prefix(truncation))

                    do {
                        let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }
                        try publisher.publish(topic: truncated, payload: "test")

                        // If it accepts truncated input, verify it still follows the pattern
                        XCTAssertTrue(truncated.hasPrefix("R/" + portalId + "/"), "Accepted truncated topic must still follow pattern: '" + truncated + "'")

                    } catch {
                        // Truncated topics should be rejected - this is expected
                        continue
                    }
                }
            }
        }
    }

    /// Test ReadOnlyPublisher with empty and minimal inputs
    func testReadOnlyPublisherEdgeCaseEmptyAndMinimalInputs() {
        let portalId = "c0ffee000001"

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }

            // Empty topic
            XCTAssertThrowsError(try publisher.publish(topic: "", payload: "test"))

            // Whitespace-only topic
            XCTAssertThrowsError(try publisher.publish(topic: "   ", payload: "test"))
            XCTAssertThrowsError(try publisher.publish(topic: "\t\n", payload: "test"))

            // Minimal topics
            let minimalTopics = ["R", "R/", "R//", "R///", "R/test", "R/test/"]
            for topic in minimalTopics {
                XCTAssertThrowsError(try publisher.publish(topic: topic, payload: "test"))
            }

        } catch {
            XCTFail("Should be able to initialize publisher: " + error.localizedDescription)
        }
    }

    func testReadOnlyPublisherEdgeCaseWildcardTopics() {
        let portalId = "c0ffee000001"

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }

            // Topics with wildcards
            let wildcardTopics = [
                "R/c0ffee000001/system/+/Serial",
                "R/c0ffee000001/system/0/+",
                "R/c0ffee000001/system/#",
                "R/#",
                "R/c0ffee000001/#",
                "R/+/+/+/+/+/+",
            ]

            for topic in wildcardTopics {
                // Should throw error for topics with wildcards
                XCTAssertThrowsError(try publisher.publish(topic: topic, payload: "test"))
            }

        } catch {
            XCTFail("Should be able to initialize publisher: " + error.localizedDescription)
        }
    }

    /// Test ReadOnlyPublisher with topics containing NUL characters
    func testReadOnlyPublisherEdgeCaseNulCharacters() {
        let portalId = "c0ffee000001"

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }

            // Topics with NUL characters
            let nulTopics = [
                "R/c0ffee000001/system\00/Serial",
                "R/c0ffee000001/system/0/Ser\0ial",
                "R/c0ffee000001/system\00/0/Serial",
                "R/\0c0ffee000001/system/0/Serial",
            ]

            for topic in nulTopics {
                // Should throw error for topics with NUL characters
                XCTAssertThrowsError(try publisher.publish(topic: topic, payload: "test"))
            }

        } catch {
            XCTFail("Should be able to initialize publisher: " + error.localizedDescription)
        }
    }

    /// Test ReadOnlyPublisher with very long inputs
    func testReadOnlyPublisherEdgeCaseVeryLongInputs() {
        let portalId = "c0ffee000001"

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }

            // Very long topic
            let longTopic = "R/" + portalId + "/" + String(repeating: "a", count: 1000) + "/" + String(repeating: "b", count: 1000)

            // Should not crash
            try publisher.publish(topic: longTopic, payload: "test")

            // Very long payload
            let longPayload = String(repeating: "x", count: 10000)
            try publisher.publish(topic: "R/" + portalId + "/test", payload: longPayload)

        } catch {
            XCTFail("Should be able to handle long inputs: " + error.localizedDescription)
        }
    }

    /// Test ReadOnlyPublisher with invalid portal IDs
    func testReadOnlyPublisherInvalidPortalIds() {
        // Empty portal ID
        XCTAssertThrowsError(try ReadOnlyPublisher(portalId: "") { _, _ in }) { error in
            if case ReadOnlyPublisher.Error.invalidPortalId(let portalId) = error {
                XCTAssertEqual(portalId, "")
            } else {
                XCTFail("Expected invalidPortalId error")
            }
        }

        // Portal ID with forbidden characters
        let invalidPortalIds = [
            "/test",
            "test/",
            "test+test",
            "test#test",
            "test test",
            "test\ttest",
            "test\ntest",
            "test\rtest",
            "test\0test",
        ]

        for portalId in invalidPortalIds {
            XCTAssertThrowsError(try ReadOnlyPublisher(portalId: portalId) { _, _ in }) { error in
                if case ReadOnlyPublisher.Error.invalidPortalId(let invalidPortalId) = error {
                    XCTAssertEqual(invalidPortalId, portalId)
                } else {
                    XCTFail("Expected invalidPortalId error for portalId: " + portalId)
                }
            }
        }
    }

    /// Test ReadOnlyPublisher with topics that don't match portal ID
    func testReadOnlyPublisherWrongPortalId() {
        let portalId = "c0ffee000001"

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }

            // Topics with different portal IDs
            let wrongTopics = [
                "R/different0001/system/0/Serial",
                "R/otherportal/system/0/Serial",
                "N/c0ffee000001/system/0/Serial",  // Wrong prefix
                "R/c0ffee000001",  // No trailing slash
                "R/",  // Just R/
            ]

            for topic in wrongTopics {
                // Should throw error for topics with wrong portal ID
                XCTAssertThrowsError(try publisher.publish(topic: topic, payload: "test"))
            }

        } catch {
            XCTFail("Should be able to initialize publisher: " + error.localizedDescription)
        }
    }

    /// Test ReadOnlyPublisher keepalive functionality
    func testReadOnlyPublisherKeepalive() {
        let portalId = "c0ffee000001"
        var keepaliveCalled = false

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { topic, payload in
                keepaliveCalled = true
                XCTAssertEqual(topic, "R/" + portalId + "/keepalive")
                XCTAssertEqual(payload, "")
            }

            // Should not crash
            try publisher.keepalive()

            // Verify keepalive was called
            XCTAssertTrue(keepaliveCalled)

        } catch {
            XCTFail("Should be able to send keepalive: " + error.localizedDescription)
        }
    }

    /// Stress test with many rapid publishing operations
    func testReadOnlyPublisherStressManyRapidOperations() {
        let portalId = "c0ffee000001"
        var messageCount = 0

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in
                messageCount += 1
            }

            // Test 1000 rapid publishing operations
            for i in 0..<1000 {
                let topic = "R/" + portalId + "/test/" + String(i)
                let payload = "Message " + String(i)

                // Rapid publishing should not cause issues
                try publisher.publish(topic: topic, payload: payload)
            }

            // Verify all messages were sent
            XCTAssertEqual(messageCount, 1000)

        } catch {
            XCTFail("Should be able to handle rapid operations: " + error.localizedDescription)
        }
    }

    /// Test ReadOnlyPublisher with valid topics
    func testReadOnlyPublisherValidTopics() {
        let portalId = "c0ffee000001"
        var sentTopics: [(String, String)] = []

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { topic, payload in
                sentTopics.append((topic, payload))
            }

            // Valid topics
            let validTopics = [
                ("R/c0ffee000001/system/0/Serial", "test1"),
                ("R/c0ffee000001/battery/279/Voltage", "test2"),
                ("R/c0ffee000001/system/0/Dc/Battery/Soc", "test3"),
                ("R/c0ffee000001/full_publish_completed", "test4"),
                ("R/c0ffee000001/very/nested/path/to/topic", "test5"),
            ]

            for (topic, payload) in validTopics {
                // Should not throw error for valid topics
                try publisher.publish(topic: topic, payload: payload)
            }

            // Verify all topics were sent
            XCTAssertEqual(sentTopics.count, 5)

            // Verify each sent topic matches what we sent
            for i in 0..<validTopics.count {
                XCTAssertEqual(sentTopics[i].0, validTopics[i].0)
                XCTAssertEqual(sentTopics[i].1, validTopics[i].1)
            }

        } catch {
            XCTFail("Should be able to publish valid topics: " + error.localizedDescription)
        }
    }

    /// Test ReadOnlyPublisher error types
    func testReadOnlyPublisherErrorTypes() {
        let portalId = "c0ffee000001"

        do {
            let publisher = try ReadOnlyPublisher(portalId: portalId) { _, _ in }

            // Test notAllowed error for invalid topic
            XCTAssertThrowsError(try publisher.publish(topic: "N/c0ffee000001/test", payload: "test")) { error in
                if case ReadOnlyPublisher.Error.notAllowed(let topic) = error {
                    XCTAssertEqual(topic, "N/c0ffee000001/test")
                } else {
                    XCTFail("Expected notAllowed error")
                }
            }

            // Test notAllowed error for topic with wildcard
            XCTAssertThrowsError(try publisher.publish(topic: "R/c0ffee000001/test/+", payload: "test")) { error in
                if case ReadOnlyPublisher.Error.notAllowed(let topic) = error {
                    XCTAssertEqual(topic, "R/c0ffee000001/test/+")
                } else {
                    XCTFail("Expected notAllowed error")
                }
            }

        } catch {
            XCTFail("Should be able to initialize publisher: " + error.localizedDescription)
        }
    }
}
