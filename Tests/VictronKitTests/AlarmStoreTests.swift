import XCTest
@testable import VictronKit

final class AlarmStoreTests: XCTestCase {

    func testAlarmStoreWithFixtures() throws {
        var callCount = 0
        let store = AlarmStore(now: {
            callCount += 1
            return Date(timeIntervalSince1970: 1000000 + Double(callCount))
        })
        
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "alarms", withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail("Could not find alarms.json")
            return
        }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let messages = json?["messages"] as? [[String: Any]] ?? []

        for message in messages {
            if let topic = message["topic"] as? String,
               let payload = message["payload"] as? [String: Any] {
                let payloadData = try JSONSerialization.data(withJSONObject: payload)
                store.handle(topic: topic, payload: payloadData)
            }
        }

        // Expected active alarms from the fixture:
        // - vebus 276 L1/Overload (alarm, level 2)
        // - battery 279 LowSoc (warning, level 1)
        // - vebus 276 L1/HighTemperature (warning, level 1)
        // Battery Alarms/Alarm is ignored (deprecated)
        // Ripple (null) is not active
        
        XCTAssertEqual(store.active.count, 3, "Should have 3 active alarms")
        
        // First alarm should be vebus 276 L1/Overload (alarm level)
        let firstAlarm = store.active[0]
        XCTAssertEqual(firstAlarm.service, "vebus")
        XCTAssertEqual(firstAlarm.instance, "276")
        XCTAssertEqual(firstAlarm.name, "L1/Overload")
        XCTAssertEqual(firstAlarm.level, .alarm)
        
        // Then the two warnings, newest first (the test clock advances per message, and HighTemperature comes later in the fixture)
        let secondAlarm = store.active[1]
        XCTAssertEqual(secondAlarm.service, "vebus")
        XCTAssertEqual(secondAlarm.instance, "276")
        XCTAssertEqual(secondAlarm.name, "L1/HighTemperature")
        XCTAssertEqual(secondAlarm.level, .warning)

        let thirdAlarm = store.active[2]
        XCTAssertEqual(thirdAlarm.service, "battery")
        XCTAssertEqual(thirdAlarm.instance, "279")
        XCTAssertEqual(thirdAlarm.name, "LowSoc")
        XCTAssertEqual(thirdAlarm.level, .warning)
    }

    func testAlarmClearedWhenPayloadIsEmpty() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Add an alarm
        let topic = "N/test/battery/279/Alarms/LowSoc"
        let payload = ["value": 1]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.active.count, 1)
        
        // Clear it with empty payload
        store.handle(topic: topic, payload: Data())
        
        XCTAssertEqual(store.active.count, 0)
        XCTAssertNil(store.alarms["battery/279/LowSoc"])
    }

    func testAlarmClearedWhenValueIsNull() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Add an alarm
        let topic = "N/test/battery/279/Alarms/LowSoc"
        let payload = ["value": 1]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.active.count, 1)
        
        // Clear it with null value
        let nullPayload = ["value": NSNull()] as [String: Any]
        let nullPayloadData = try JSONSerialization.data(withJSONObject: nullPayload)
        store.handle(topic: topic, payload: nullPayloadData)
        
        XCTAssertEqual(store.active.count, 0)
        XCTAssertNil(store.alarms["battery/279/LowSoc"])
    }

    func testAlarmLevelChangeUpdatesSince() throws {
        let now1 = Date(timeIntervalSince1970: 1000000)
        let now2 = Date(timeIntervalSince1970: 2000000)
        var callCount = 0
        let store = AlarmStore(now: {
            callCount += 1
            return callCount == 1 ? now1 : now2
        })
        
        let topic = "N/test/battery/279/Alarms/LowSoc"
        
        // Set to warning
        var payload = ["value": 1]
        var payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        let firstAlarm = store.alarms["battery/279/LowSoc"]
        XCTAssertEqual(firstAlarm?.level, .warning)
        XCTAssertEqual(firstAlarm?.since, now1)
        
        // Change to alarm
        payload = ["value": 2]
        payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        let secondAlarm = store.alarms["battery/279/LowSoc"]
        XCTAssertEqual(secondAlarm?.level, .alarm)
        XCTAssertEqual(secondAlarm?.since, now2)
    }

    func testLogContainsOnlyWarningAndAlarmChanges() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        let topic = "N/test/battery/279/Alarms/LowSoc"
        
        // Set to warning - should be logged
        var payload = ["value": 1]
        var payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.log.count, 1)
        
        // Change to alarm - should be logged
        payload = ["value": 2]
        payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.log.count, 2)
        
        // Change back to warning - should be logged
        payload = ["value": 1]
        payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.log.count, 3)
        
        // Set to OK - should NOT be logged
        payload = ["value": 0]
        payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.log.count, 3)
    }

    func testLogIsCappedAt200Entries() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Add 201 warning alarms
        for i in 0..<201 {
            let topic = "N/test/battery/279/Alarms/Warning\(i)"
            let payload = ["value": 1]
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            store.handle(topic: topic, payload: payloadData)
        }
        
        XCTAssertEqual(store.log.count, 200)
    }

    func testNonNumericValuesAreIgnored() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        let topic = "N/test/battery/279/Alarms/LowSoc"
        
        // String value - should be ignored
        var payload = ["value": "warning"]
        var payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.active.count, 0)
        
        // Out of range value - should be ignored
        let outOfRangePayload = ["value": 5] as [String : Any]
        payloadData = try JSONSerialization.data(withJSONObject: outOfRangePayload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.active.count, 0)
    }

    func testDeprecatedAlarmPathIsIgnored() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Battery Alarms/Alarm is deprecated and should be ignored
        let topic = "N/test/battery/279/Alarms/Alarm"
        let payload = ["value": 2]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.active.count, 0)
    }

    func testNonBatteryAndVebusServicesAreIgnored() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Solarcharger alarms should be ignored
        let topic = "N/test/solarcharger/278/Alarms/HighTemperature"
        let payload = ["value": 2]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        XCTAssertEqual(store.active.count, 0)
    }

    func testAlarmIdFormat() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        let topic = "N/test/battery/279/Alarms/LowSoc"
        let payload = ["value": 1]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        let alarm = store.alarms["battery/279/LowSoc"]
        XCTAssertNotNil(alarm)
        XCTAssertEqual(alarm?.id, "battery/279/LowSoc")
        XCTAssertEqual(alarm?.service, "battery")
        XCTAssertEqual(alarm?.instance, "279")
        XCTAssertEqual(alarm?.name, "LowSoc")
    }

    func testAlarmIdWithNestedPath() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        let topic = "N/test/vebus/276/Alarms/L1/Overload"
        let payload = ["value": 2]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        let alarm = store.alarms["vebus/276/L1/Overload"]
        XCTAssertNotNil(alarm)
        XCTAssertEqual(alarm?.id, "vebus/276/L1/Overload")
        XCTAssertEqual(alarm?.name, "L1/Overload")
    }

    func testPublishedPropertiesNotifyOnChange() {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Test that alarms property is published by checking objectWillChange
        let expectation = XCTestExpectation(description: "Alarms should be published")
        let observer = store.objectWillChange.sink { _ in
            expectation.fulfill()
        }
        
        // Add an alarm to trigger changes
        let topic = "N/test/battery/279/Alarms/LowSoc"
        let payload = ["value": 2]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        store.handle(topic: topic, payload: payloadData)
        
        // Wait for expectation
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up observer
        observer.cancel()
    }

    func testAlarmPreservesStartTimeWhenLevelUnchanged() throws {
        // Use a controlled clock
        var callCount = 0
        let store = AlarmStore(now: {
            callCount += 1
            return Date(timeIntervalSince1970: Double(callCount * 1000))
        })
        
        let topic = "N/test/battery/279/Alarms/LowSoc"
        let alarmId = "battery/279/LowSoc"   // AlarmStore keys by <service>/<instance>/<name>
        let payload1 = ["value": 1]  // Warning level
        let payloadData1 = try JSONSerialization.data(withJSONObject: payload1)
        
        // First alarm with warning level
        store.handle(topic: topic, payload: payloadData1)
        let firstAlarm = store.alarms[alarmId]
        XCTAssertNotNil(firstAlarm?.since)
        let firstSince = firstAlarm?.since
        
        // Wait a bit (simulated by callCount increment)
        callCount += 1
        
        // Same alarm with same warning level (should preserve original start time)
        store.handle(topic: topic, payload: payloadData1)
        let sameLevelAlarm = store.alarms[alarmId]
        let sameLevelSince = sameLevelAlarm?.since
        
        // Start times should be the same
        XCTAssertEqual(firstSince, sameLevelSince)
        
        // Change to alarm level (should update start time)
        let payload2 = ["value": 2]  // Alarm level
        let payloadData2 = try JSONSerialization.data(withJSONObject: payload2)
        store.handle(topic: topic, payload: payloadData2)
        let levelChangedAlarm = store.alarms[alarmId]
        let levelChangedSince = levelChangedAlarm?.since
        
        // Start time should be different (new)
        XCTAssertNotEqual(firstSince, levelChangedSince)
        
        // Change back to warning level (should update start time again)
        callCount += 1
        store.handle(topic: topic, payload: payloadData1)
        let backToWarningAlarm = store.alarms[alarmId]
        let backToWarningSince = backToWarningAlarm?.since
        
        // Start time should be different from alarm level
        XCTAssertNotEqual(levelChangedSince, backToWarningSince)
    }
    
    func testResetClearsAlarmsAndLog() throws {
        let store = AlarmStore(now: { Date(timeIntervalSince1970: 1000000) })
        
        // Add some alarms
        let topic1 = "N/test/battery/279/Alarms/LowSoc"
        let payload1 = ["value": 2]
        let payloadData1 = try JSONSerialization.data(withJSONObject: payload1)
        store.handle(topic: topic1, payload: payloadData1)
        
        let topic2 = "N/test/vebus/276/Alarms/L1/Overload"
        let payload2 = ["value": 1]
        let payloadData2 = try JSONSerialization.data(withJSONObject: payload2)
        store.handle(topic: topic2, payload: payloadData2)
        
        // Verify alarms are present
        XCTAssertEqual(store.alarms.count, 2)
        XCTAssertEqual(store.active.count, 2)
        XCTAssertEqual(store.log.count, 2)
        
        // Reset the store
        store.reset()
        
        // Verify everything is cleared
        XCTAssertTrue(store.alarms.isEmpty)
        XCTAssertTrue(store.active.isEmpty)
        XCTAssertTrue(store.log.isEmpty)
    }
}
