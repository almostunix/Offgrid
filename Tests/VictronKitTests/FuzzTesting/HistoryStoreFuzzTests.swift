
//
// HistoryStoreFuzzTests.swift
//
// Fuzz tests for HistoryStore with random and malformed inputs.
//

import XCTest
@testable import VictronKit

final class HistoryStoreFuzzTests: XCTestCase {
    // MARK: - Deterministic Fuzz Testing

    /// Fuzz test for history store with random inputs
    /// Uses a deterministic random generator with fixed seeds to ensure reproducibility
    func testHistoryStoreWithRandomInputs() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let historyStore = HistoryStore()

            // Test 100 random messages per seed
            for _ in 0..<100 {
                let topic = rng.randomTopic()
                let payloadData = rng.randomJSONPayload()

                // Handling should never crash or hang
                historyStore.handle(topic: topic, payload: payloadData)

                // Verify the store is in a valid state
                XCTAssertNotNil(historyStore.solarDays, "Solar days should not be nil")
                XCTAssertNotNil(historyStore.batteryTotals, "Battery totals should not be nil")

                // Verify no empty keys in dictionaries
                for (key, _) in historyStore.solarDays {
                    XCTAssertFalse(key.isEmpty, "Solar days should not have empty keys")
                }
                for (key, _) in historyStore.batteryTotals {
                    XCTAssertFalse(key.isEmpty, "Battery totals should not have empty keys")
                }
            }
        }
    }

    /// Fuzz test for history store with truncated inputs
    func testHistoryStoreWithTruncatedInputs() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let historyStore = HistoryStore()

            // Test with valid history topics that get truncated
            let validTopics = [
                "N/c0ffee000001/solarcharger/279/History/Daily/0/Yield",
                "N/c0ffee000001/battery/279/History/TotalConsumed",
                "N/c0ffee000001/solarcharger/279/History/Daily/1/MaxPower"
            ]

            for topic in validTopics {
                // Test various truncation points
                for truncation in 0..<topic.count {
                    let truncatedTopic = String(topic.prefix(truncation))
                    let payloadData = rng.randomJSONPayload()

                    // Handling should never crash or hang
                    historyStore.handle(topic: truncatedTopic, payload: payloadData)
                }
            }
        }
    }

    /// Fuzz test for history store with corrupted payloads
    func testHistoryStoreWithCorruptedPayloads() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let historyStore = HistoryStore()

            // Test with valid history topics and corrupted payloads
            let validTopics = [
                "N/c0ffee000001/solarcharger/279/History/Daily/0/Yield",
                "N/c0ffee000001/battery/279/History/TotalConsumed"
            ]

            for topic in validTopics {
                let payloadData = rng.randomJSONPayload()
                let corruptedData = rng.corruptedData(from: payloadData)

                // Handling should never crash or hang
                historyStore.handle(topic: topic, payload: corruptedData)
            }
        }
    }

    /// Test history store with empty and minimal inputs
    func testHistoryStoreEdgeCaseEmptyAndMinimalInputs() {
        let historyStore = HistoryStore()

        // Empty inputs
        let emptyTopic = ""
        let emptyPayload = Data()

        // Should not crash
        historyStore.handle(topic: emptyTopic, payload: emptyPayload)

        // Minimal topics
        let minimalTopics = ["N", "N/", "N//", "N///", "N/test", "N/test/"]
        for topic in minimalTopics {
            historyStore.handle(topic: topic, payload: emptyPayload)
        }

        // Verify store is still in valid state
        XCTAssertNotNil(historyStore.solarDays)
        XCTAssertNotNil(historyStore.batteryTotals)
    }

    /// Test history store with malformed JSON structures
    func testHistoryStoreEdgeCaseMalformedJSON() {
        let historyStore = HistoryStore()

        // Malformed JSON strings that might be encountered
        let malformedJSONs = [
            "",
            "{",
            "}",
            "[{\"}",
            "{\"value\":}",
            "{\"value\": }",
            "{\"value\": ,}",
            "{\"value\": 1, }",
            "{\"value\": 1,,}",
        ]

        let validTopic = "N/c0ffee000001/solarcharger/279/History/Daily/0/Yield"

        for jsonString in malformedJSONs {
            // Should not crash
            if let data = jsonString.data(using: .utf8) {
                historyStore.handle(topic: validTopic, payload: data)
            }
        }

        // Verify store is still in valid state
        XCTAssertNotNil(historyStore.solarDays)
        XCTAssertNotNil(historyStore.batteryTotals)
    }

    /// Test history store with very long inputs
    func testHistoryStoreEdgeCaseVeryLongInputs() {
        let historyStore = HistoryStore()

        // Very long topic
        let longTopic = "N/" + String(repeating: "a", count: 1000) + "/solarcharger/" + String(repeating: "b", count: 1000) + "/History/Daily/0/Yield"

        // Very long JSON payload
        var longPayload = [String: Any]()
        longPayload["value"] = String(repeating: "x", count: 10000)

        do {
            let data = try JSONSerialization.data(withJSONObject: longPayload, options: [])

            // Should not crash
            historyStore.handle(topic: longTopic, payload: data)

            // Verify store is still in valid state
            XCTAssertNotNil(historyStore.solarDays)
            XCTAssertNotNil(historyStore.batteryTotals)
        } catch {
            XCTFail("Should be able to handle long JSON payloads")
        }
    }

    /// Test history store with topics containing wildcards
    func testHistoryStoreEdgeCaseWildcardTopics() {
        let historyStore = HistoryStore()

        // Topics with wildcards
        let wildcardTopics = [
            "N/+/solarcharger/279/History/Daily/0/Yield",
            "N/c0ffee000001/+/History/Daily/0/Yield",
            "N/c0ffee000001/solarcharger/#",
            "N/#",
            "N/+/+/+/+/+/+"
        ]

        let payloadData = try! JSONSerialization.data(withJSONObject: ["value": 123.45], options: [])

        for topic in wildcardTopics {
            // Should not crash
            historyStore.handle(topic: topic, payload: payloadData)
        }

        // Verify store is still in valid state
        XCTAssertNotNil(historyStore.solarDays)
        XCTAssertNotNil(historyStore.batteryTotals)
    }

    /// Stress test with many rapid history store operations
    func testHistoryStoreStressManyRapidOperations() {
        let historyStore = HistoryStore()
        var rng = SplitMix64(seed: 42)

        // Test 1000 rapid operations
        for _ in 0..<1000 {
            let topic = rng.randomTopic()
            let payloadData = rng.randomJSONPayload()

            // Rapid operations should not cause issues
            historyStore.handle(topic: topic, payload: payloadData)
        }

        // Verify store is still in valid state
        XCTAssertNotNil(historyStore.solarDays)
        XCTAssertNotNil(historyStore.batteryTotals)
    }

    /// Test history store with valid solar charger history data
    func testHistoryStoreValidSolarChargerData() {
        let historyStore = HistoryStore()

        // Valid solar charger history topics
        let topics = [
            ("N/c0ffee000001/solarcharger/279/History/Daily/0/Yield", 12.5),
            ("N/c0ffee000001/solarcharger/279/History/Daily/0/MaxPower", 1500.0),
            ("N/c0ffee000001/solarcharger/279/History/Daily/0/MaxPvVoltage", 24.5),
            ("N/c0ffee000001/solarcharger/279/History/Daily/0/TimeInBulk", 3600.0),
            ("N/c0ffee000001/solarcharger/279/History/Daily/1/Yield", 8.3),
        ]

        for (topic, value) in topics {
            let payload = try! JSONSerialization.data(withJSONObject: ["value": value], options: [])
            historyStore.handle(topic: topic, payload: payload)
        }

        // Verify data was stored correctly
        XCTAssertEqual(historyStore.solarDays.count, 1)
        XCTAssertEqual(historyStore.solarDays["279"]?.count, 2) // Days 0 and 1
        
        if let day0 = historyStore.solarDays["279"]?[0] {
            XCTAssertEqual(day0.yield, 12.5)
            XCTAssertEqual(day0.maxPower, 1500.0)
            XCTAssertEqual(day0.maxPvVoltage, 24.5)
            XCTAssertEqual(day0.timeInBulk, 3600.0)
        }
        
        if let day1 = historyStore.solarDays["279"]?[1] {
            XCTAssertEqual(day1.yield, 8.3)
        }
    }

    /// Test history store with valid battery history data
    func testHistoryStoreValidBatteryData() {
        let historyStore = HistoryStore()

        // Valid battery history topics
        let topics = [
            ("N/c0ffee000001/battery/279/History/TotalConsumed", 1250.5),
            ("N/c0ffee000001/battery/279/History/TotalProduced", 850.3),
            ("N/c0ffee000001/battery/279/History/TotalReturned", 200.7),
        ]

        for (topic, value) in topics {
            let payload = try! JSONSerialization.data(withJSONObject: ["value": value], options: [])
            historyStore.handle(topic: topic, payload: payload)
        }

        // Verify data was stored correctly
        XCTAssertEqual(historyStore.batteryTotals.count, 1)
        XCTAssertEqual(historyStore.batteryTotals["279"]?.count, 3)
        
        XCTAssertEqual(historyStore.batteryTotals["279"]?["TotalConsumed"], 1250.5)
        XCTAssertEqual(historyStore.batteryTotals["279"]?["TotalProduced"], 850.3)
        XCTAssertEqual(historyStore.batteryTotals["279"]?["TotalReturned"], 200.7)
    }

    /// Test history store with invalid numeric values
    func testHistoryStoreInvalidNumericValues() {
        let historyStore = HistoryStore()

        let topic = "N/c0ffee000001/solarcharger/279/History/Daily/0/Yield"

        // Test with string value (should be ignored)
        let stringPayload = try! JSONSerialization.data(withJSONObject: ["value": "not a number"], options: [])
        historyStore.handle(topic: topic, payload: stringPayload)

        // Test with null value (should be ignored)
        let nullPayload = try! JSONSerialization.data(withJSONObject: ["value": NSNull()], options: [])
        historyStore.handle(topic: topic, payload: nullPayload)

        // Test with array value (should be ignored)
        let arrayPayload = try! JSONSerialization.data(withJSONObject: ["value": [1, 2, 3]], options: [])
        historyStore.handle(topic: topic, payload: arrayPayload)

        // Verify no data was stored (non-numeric values should not be stored)
        XCTAssertTrue(historyStore.solarDays.isEmpty, "Non-numeric values should not be stored in solarDays")
    }
}
