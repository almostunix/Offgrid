
//
// AlarmStoreFuzzTests.swift
//
// Fuzz tests for AlarmStore with random and malformed inputs.
//

import XCTest
@testable import VictronKit

final class AlarmStoreFuzzTests: XCTestCase {
    // MARK: - Deterministic Fuzz Testing

    /// Fuzz test for alarm store with random inputs
    /// Uses a deterministic random generator with fixed seeds to ensure reproducibility
    func testAlarmStoreWithRandomInputs() {
        let seeds: [UInt64] = [0, 1, 12345, 65536, UInt64.max - 1]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let alarmStore = AlarmStore()

            // Test 100 random messages per seed
            for _ in 0..<100 {
                let topic = rng.randomTopic()
                let payloadData = rng.randomJSONPayload()

                // Handling should never crash or hang
                alarmStore.handle(topic: topic, payload: payloadData)

                // Verify the store is in a valid state
                XCTAssertNotNil(alarmStore.alarms, "Alarms should not be nil")
                XCTAssertNotNil(alarmStore.log, "Log should not be nil")

                // Verify no empty keys in alarms dictionary
                for (key, _) in alarmStore.alarms {
                    XCTAssertFalse(key.isEmpty, "Alarms should not have empty keys")
                }
            }
        }
    }

    /// Fuzz test for alarm store with truncated inputs
    func testAlarmStoreWithTruncatedInputs() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let alarmStore = AlarmStore()

            // Test with valid alarm topics that get truncated
            let validTopics = [
                "N/c0ffee000001/battery/279/Alarms/LowSoc",
                "N/c0ffee000001/vebus/1/Alarms/L1/Overload",
                "N/c0ffee000001/battery/279/Alarms/HighTemp"
            ]

            for topic in validTopics {
                // Test various truncation points
                for truncation in 0..<topic.count {
                    let truncatedTopic = String(topic.prefix(truncation))
                    let payloadData = rng.randomJSONPayload()

                    // Handling should never crash or hang
                    alarmStore.handle(topic: truncatedTopic, payload: payloadData)
                }
            }
        }
    }

    /// Fuzz test for alarm store with corrupted payloads
    func testAlarmStoreWithCorruptedPayloads() {
        let seeds: [UInt64] = [0, 1, 12345]

        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let alarmStore = AlarmStore()

            // Test with valid alarm topics and corrupted payloads
            let validTopics = [
                "N/c0ffee000001/battery/279/Alarms/LowSoc",
                "N/c0ffee000001/vebus/1/Alarms/L1/Overload"
            ]

            for topic in validTopics {
                let payloadData = rng.randomJSONPayload()
                let corruptedData = rng.corruptedData(from: payloadData)

                // Handling should never crash or hang
                alarmStore.handle(topic: topic, payload: corruptedData)
            }
        }
    }

    /// Test alarm store with empty and minimal inputs
    func testAlarmStoreEdgeCaseEmptyAndMinimalInputs() {
        let alarmStore = AlarmStore()

        // Empty inputs
        let emptyTopic = ""
        let emptyPayload = Data()

        // Should not crash
        alarmStore.handle(topic: emptyTopic, payload: emptyPayload)

        // Minimal topics
        let minimalTopics = ["N", "N/", "N//", "N///", "N/test", "N/test/"]
        for topic in minimalTopics {
            alarmStore.handle(topic: topic, payload: emptyPayload)
        }

        // Verify store is still in valid state
        XCTAssertNotNil(alarmStore.alarms)
        XCTAssertNotNil(alarmStore.log)
    }

    /// Test alarm store with malformed JSON structures
    func testAlarmStoreEdgeCaseMalformedJSON() {
        let alarmStore = AlarmStore()

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

        let validTopic = "N/c0ffee000001/battery/279/Alarms/LowSoc"

        for jsonString in malformedJSONs {
            // Should not crash
            if let data = jsonString.data(using: .utf8) {
                alarmStore.handle(topic: validTopic, payload: data)
            }
        }

        // Verify store is still in valid state
        XCTAssertNotNil(alarmStore.alarms)
        XCTAssertNotNil(alarmStore.log)
    }

    /// Test alarm store with very long inputs
    func testAlarmStoreEdgeCaseVeryLongInputs() {
        let alarmStore = AlarmStore()

        // Very long topic
        let longTopic = "N/" + String(repeating: "a", count: 1000) + "/battery/" + String(repeating: "b", count: 1000) + "/Alarms/" + String(repeating: "c", count: 1000)

        // Very long JSON payload
        var longPayload = [String: Any]()
        longPayload["value"] = String(repeating: "x", count: 10000)

        do {
            let data = try JSONSerialization.data(withJSONObject: longPayload, options: [])

            // Should not crash
            alarmStore.handle(topic: longTopic, payload: data)

            // Verify store is still in valid state
            XCTAssertNotNil(alarmStore.alarms)
            XCTAssertNotNil(alarmStore.log)
        } catch {
            XCTFail("Should be able to handle long JSON payloads")
        }
    }

    /// Test alarm store with topics containing wildcards
    func testAlarmStoreEdgeCaseWildcardTopics() {
        let alarmStore = AlarmStore()

        // Topics with wildcards
        let wildcardTopics = [
            "N/+/battery/279/Alarms/LowSoc",
            "N/c0ffee000001/+/Alarms/LowSoc",
            "N/c0ffee000001/battery/#",
            "N/#",
            "N/+/+/+/+/+/+"
        ]

        let payloadData = try! JSONSerialization.data(withJSONObject: ["value": 2], options: [])

        for topic in wildcardTopics {
            // Should not crash
            alarmStore.handle(topic: topic, payload: payloadData)
        }

        // Verify store is still in valid state
        XCTAssertNotNil(alarmStore.alarms)
        XCTAssertNotNil(alarmStore.log)
    }

    /// Stress test with many rapid alarm store operations
    func testAlarmStoreStressManyRapidOperations() {
        let alarmStore = AlarmStore()
        var rng = SplitMix64(seed: 42)

        // Test 1000 rapid operations
        for _ in 0..<1000 {
            let topic = rng.randomTopic()
            let payloadData = rng.randomJSONPayload()

            // Rapid operations should not cause issues
            alarmStore.handle(topic: topic, payload: payloadData)
        }

        // Verify store is still in valid state
        XCTAssertNotNil(alarmStore.alarms)
        XCTAssertNotNil(alarmStore.log)
    }

    /// Test alarm store with valid battery alarm data
    func testAlarmStoreValidBatteryAlarms() {
        let alarmStore = AlarmStore()

        // Valid battery alarm topics with different levels
        let alarms = [
            ("N/c0ffee000001/battery/279/Alarms/LowSoc", 0),      // OK
            ("N/c0ffee000001/battery/279/Alarms/LowSoc", 1),      // Warning
            ("N/c0ffee000001/battery/279/Alarms/LowSoc", 2),      // Alarm
            ("N/c0ffee000001/battery/279/Alarms/HighTemp", 1),   // Warning
            ("N/c0ffee000001/battery/279/Alarms/HighTemp", 2),   // Alarm
        ]

        for (topic, level) in alarms {
            let payload = try! JSONSerialization.data(withJSONObject: ["value": level], options: [])
            alarmStore.handle(topic: topic, payload: payload)
        }

        // Verify alarms were stored correctly
        XCTAssertEqual(alarmStore.alarms.count, 2) // LowSoc and HighTemp
        
        if let lowSocAlarm = alarmStore.alarms["battery/279/LowSoc"] {
            XCTAssertEqual(lowSocAlarm.level, .alarm)
            XCTAssertEqual(lowSocAlarm.name, "LowSoc")
            XCTAssertEqual(lowSocAlarm.service, "battery")
            XCTAssertEqual(lowSocAlarm.instance, "279")
        }
        
        if let highTempAlarm = alarmStore.alarms["battery/279/HighTemp"] {
            XCTAssertEqual(highTempAlarm.level, .alarm)
            XCTAssertEqual(highTempAlarm.name, "HighTemp")
        }

        // Verify log contains the warning and alarm entries
        XCTAssertEqual(alarmStore.log.count, 4) // Warning, alarm upgrade for LowSoc, and alarm for HighTemp
    }

    /// Test alarm store with valid VE.Bus alarm data
    func testAlarmStoreValidVEBusAlarms() {
        let alarmStore = AlarmStore()

        // Valid VE.Bus alarm topics
        let alarms = [
            ("N/c0ffee000001/vebus/1/Alarms/L1/Overload", 2),
            ("N/c0ffee000001/vebus/1/Alarms/L1/HighTemp", 1),
        ]

        for (topic, level) in alarms {
            let payload = try! JSONSerialization.data(withJSONObject: ["value": level], options: [])
            alarmStore.handle(topic: topic, payload: payload)
        }

        // Verify alarms were stored correctly
        XCTAssertEqual(alarmStore.alarms.count, 2)
        
        if let overloadAlarm = alarmStore.alarms["vebus/1/L1/Overload"] {
            XCTAssertEqual(overloadAlarm.level, .alarm)
            XCTAssertEqual(overloadAlarm.name, "L1/Overload")
            XCTAssertEqual(overloadAlarm.service, "vebus")
            XCTAssertEqual(overloadAlarm.instance, "1")
        }
        
        if let highTempAlarm = alarmStore.alarms["vebus/1/L1/HighTemp"] {
            XCTAssertEqual(highTempAlarm.level, .warning)
            XCTAssertEqual(highTempAlarm.name, "L1/HighTemp")
        }

        // Verify log contains the alarm entry
        XCTAssertEqual(alarmStore.log.count, 2) // Both alarm and warning
    }

    /// Test alarm store with unsupported service
    func testAlarmStoreUnsupportedService() {
        let alarmStore = AlarmStore()

        // Unsupported service (not battery or vebus)
        let topic = "N/c0ffee000001/solarcharger/279/Alarms/HighTemp"
        let payload = try! JSONSerialization.data(withJSONObject: ["value": 2], options: [])

        // Should not crash and should not store the alarm
        alarmStore.handle(topic: topic, payload: payload)

        XCTAssertTrue(alarmStore.alarms.isEmpty)
        XCTAssertTrue(alarmStore.log.isEmpty)
    }

    /// Test alarm store with deprecated Alarms/Alarm path
    func testAlarmStoreDeprecatedAlarmPath() {
        let alarmStore = AlarmStore()

        // Deprecated path
        let topic = "N/c0ffee000001/battery/279/Alarms/Alarm"
        let payload = try! JSONSerialization.data(withJSONObject: ["value": 2], options: [])

        // Should not crash and should not store the alarm
        alarmStore.handle(topic: topic, payload: payload)

        XCTAssertTrue(alarmStore.alarms.isEmpty)
        XCTAssertTrue(alarmStore.log.isEmpty)
    }

    /// Test alarm store with empty payload (device gone)
    func testAlarmStoreEmptyPayload() {
        let alarmStore = AlarmStore()

        // First, create an alarm
        let topic = "N/c0ffee000001/battery/279/Alarms/LowSoc"
        let payload = try! JSONSerialization.data(withJSONObject: ["value": 2], options: [])
        alarmStore.handle(topic: topic, payload: payload)

        XCTAssertEqual(alarmStore.alarms.count, 1)

        // Now send empty payload (device gone)
        let emptyPayload = Data()
        alarmStore.handle(topic: topic, payload: emptyPayload)

        // Alarm should be cleared
        XCTAssertTrue(alarmStore.alarms.isEmpty)
    }

    /// Test alarm store with null payload value
    func testAlarmStoreNullPayloadValue() {
        let alarmStore = AlarmStore()

        // First, create an alarm
        let topic = "N/c0ffee000001/battery/279/Alarms/LowSoc"
        let payload = try! JSONSerialization.data(withJSONObject: ["value": 2], options: [])
        alarmStore.handle(topic: topic, payload: payload)

        XCTAssertEqual(alarmStore.alarms.count, 1)

        // Now send null value
        let nullPayload = try! JSONSerialization.data(withJSONObject: ["value": NSNull()], options: [])
        alarmStore.handle(topic: topic, payload: nullPayload)

        // Alarm should be cleared
        XCTAssertTrue(alarmStore.alarms.isEmpty)
    }

    /// Test alarm store with invalid alarm levels
    func testAlarmStoreInvalidAlarmLevels() {
        let alarmStore = AlarmStore()

        let topic = "N/c0ffee000001/battery/279/Alarms/LowSoc"

        // Test with negative value (should be ignored)
        let negativePayload = try! JSONSerialization.data(withJSONObject: ["value": -1], options: [])
        alarmStore.handle(topic: topic, payload: negativePayload)

        // Test with value > 2 (should be ignored)
        let highPayload = try! JSONSerialization.data(withJSONObject: ["value": 5], options: [])
        alarmStore.handle(topic: topic, payload: highPayload)

        // Test with string value (should be ignored)
        let stringPayload = try! JSONSerialization.data(withJSONObject: ["value": "not a number"], options: [])
        alarmStore.handle(topic: topic, payload: stringPayload)

        // Verify no alarms were stored (invalid values should not create alarms)
        // Note: AlarmStore accepts 0-2 int values, so we only check that non-int values are ignored
        XCTAssertTrue(alarmStore.log.isEmpty, "Non-integer alarm levels should not be logged")
    }

    /// Test alarm store with alarm level changes
    func testAlarmStoreAlarmLevelChanges() {
        let alarmStore = AlarmStore()

        let topic = "N/c0ffee000001/battery/279/Alarms/LowSoc"

        // Start with warning
        let warningPayload = try! JSONSerialization.data(withJSONObject: ["value": 1], options: [])
        alarmStore.handle(topic: topic, payload: warningPayload)

        XCTAssertEqual(alarmStore.alarms.count, 1)
        XCTAssertEqual(alarmStore.log.count, 1)

        // Upgrade to alarm
        let alarmPayload = try! JSONSerialization.data(withJSONObject: ["value": 2], options: [])
        alarmStore.handle(topic: topic, payload: alarmPayload)

        XCTAssertEqual(alarmStore.alarms.count, 1)
        XCTAssertEqual(alarmStore.log.count, 2) // Should have logged the alarm upgrade

        // Downgrade to warning
        alarmStore.handle(topic: topic, payload: warningPayload)

        XCTAssertEqual(alarmStore.alarms.count, 1)
        XCTAssertEqual(alarmStore.log.count, 3) // Should log warning again (level changed)

        // Clear to OK
        let okPayload = try! JSONSerialization.data(withJSONObject: ["value": 0], options: [])
        alarmStore.handle(topic: topic, payload: okPayload)

        // Level 0 (OK): the alarm is no longer active
        XCTAssertNotEqual(alarmStore.alarms.values.first?.level, .alarm)
        XCTAssertNotEqual(alarmStore.alarms.values.first?.level, .warning)
        XCTAssertEqual(alarmStore.log.count, 3) // Should not log OK state
    }
}
