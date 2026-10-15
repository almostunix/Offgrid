import XCTest
@testable import VictronKit

final class HistoryStoreTests: XCTestCase {

    func testParsesSolarChargerDailyHistory() throws {
        let store = HistoryStore()
        let bundle = Bundle(for: HistoryStoreTests.self)
        guard let url = Bundle.module.url(forResource: "solarcharger_history", withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail("Could not find solarcharger_history.json")
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

        // Check that we have solar days for instance 278
        XCTAssertNotNil(store.solarDays["278"], "Should have solar days for instance 278")
        let days = store.solarDays["278"]
        XCTAssertEqual(days?.count, 30, "Should have 30 days of history")

        // Check specific days
        if let day0 = days?[0] {
            XCTAssertEqual(day0.yield, 2.5)
            XCTAssertEqual(day0.maxPower, 450)
            XCTAssertEqual(day0.maxPvVoltage, 32.5)
            XCTAssertEqual(day0.timeInBulk, 450)
        }

        // Every day and field must match the fixture file itself (no hand-copied numbers).
        let fixtureMessages = (json?["messages"] as? [[String: Any]]) ?? []
        var expected: [Int: [String: Double]] = [:]
        for message in fixtureMessages {
            guard let topic = message["topic"] as? String,
                  let value = (message["payload"] as? [String: Any])?["value"] as? Double else { continue }
            let parts = topic.split(separator: "/")   // N/<id>/solarcharger/278/History/Daily/<n>/<Field>
            guard parts.count == 8, let day = Int(parts[6]) else { continue }
            expected[day, default: [:]][String(parts[7])] = value
        }
        XCTAssertEqual(expected.count, 30)
        for (n, fields) in expected {
            XCTAssertEqual(days?[n]?.yield, fields["Yield"], "day \(n) Yield")
            XCTAssertEqual(days?[n]?.maxPower, fields["MaxPower"], "day \(n) MaxPower")
            XCTAssertEqual(days?[n]?.maxPvVoltage, fields["MaxPvVoltage"], "day \(n) MaxPvVoltage")
            XCTAssertEqual(days?[n]?.timeInBulk, fields["TimeInBulk"], "day \(n) TimeInBulk")
        }
    }

    func testParsesBatteryHistory() throws {
        let store = HistoryStore()
        let bundle = Bundle(for: HistoryStoreTests.self)
        guard let url = Bundle.module.url(forResource: "battery_history", withExtension: "json", subdirectory: "Fixtures") else {
            XCTFail("Could not find battery_history.json")
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

        // Check that we have battery totals for instance 279
        XCTAssertNotNil(store.batteryTotals["279"], "Should have battery totals for instance 279")
        let totals = store.batteryTotals["279"]
        XCTAssertEqual(totals?.count, 8, "Should have 8 battery history fields")

        // Check specific fields
        XCTAssertEqual(totals?["ChargeCycles"], 125)
        XCTAssertEqual(totals?["DeepestDischarge"], 22.5)
        XCTAssertEqual(totals?["AverageDischarge"], 15.3)
        XCTAssertEqual(totals?["DischargedEnergy"], 45000)
        XCTAssertEqual(totals?["ChargedEnergy"], 52000)
        XCTAssertEqual(totals?["TotalAhDrawn"], 1850)
        XCTAssertEqual(totals?["MinimumVoltage"], 11.8)
        XCTAssertEqual(totals?["MaximumVoltage"], 14.6)
    }

    func testIgnoresNonHistoryTopics() {
        let store = HistoryStore()
        let topic = "N/c0ffee000001/system/0/Serial"
        let payload = ["value": "test123"]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)

        store.handle(topic: topic, payload: payloadData)

        XCTAssertTrue(store.solarDays.isEmpty)
        XCTAssertTrue(store.batteryTotals.isEmpty)
    }

    func testHandlesInvalidPayloads() {
        let store = HistoryStore()
        let topic = "N/c0ffee000001/solarcharger/278/History/Daily/0/Yield"
        let invalidPayload = ["invalid": "data"]
        let payloadData = try! JSONSerialization.data(withJSONObject: invalidPayload)

        store.handle(topic: topic, payload: payloadData)

        XCTAssertTrue(store.solarDays.isEmpty)
    }
}