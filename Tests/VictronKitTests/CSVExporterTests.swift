//
// CSVExporterTests.swift
//
// Tests for CSVExporter functionality
//

import XCTest
@testable import VictronKit

final class CSVExporterTests: XCTestCase {

    func testLiveSeriesCSVExport() {
        // Create test data with partly overlapping timestamps
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        let timestamp1 = dateFormatter.date(from: "2023-01-01T10:00:00Z")!
        let timestamp2 = dateFormatter.date(from: "2023-01-01T10:05:00Z")!
        let timestamp3 = dateFormatter.date(from: "2023-01-01T10:10:00Z")!
        let timestamp4 = dateFormatter.date(from: "2023-01-01T10:15:00Z")!

        let series1 = (
            name: "Power",
            unit: "W",
            samples: [
                Sample(timestamp: timestamp1, value: 100),
                Sample(timestamp: timestamp2, value: 150),
                Sample(timestamp: timestamp3, value: 120)
            ]
        )

        let series2 = (
            name: "Voltage",
            unit: "V",
            samples: [
                Sample(timestamp: timestamp2, value: 12.5),
                Sample(timestamp: timestamp3, value: 12.8),
                Sample(timestamp: timestamp4, value: 12.6)
            ]
        )

        let csv = CSVExporter.csv(series: [series1, series2])

        let expected = "time,Power (W),Voltage (V)\r\n2023-01-01T10:00:00Z,100,\r\n2023-01-01T10:05:00Z,150,12.5\r\n2023-01-01T10:10:00Z,120,12.8\r\n2023-01-01T10:15:00Z,,12.6"

        XCTAssertEqual(csv, expected)
    }

    func testLiveSeriesWithSpecialCharacters() {
        // Test series name with comma and quote
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        let timestamp1 = dateFormatter.date(from: "2023-01-01T10:00:00Z")!

        let series = (
            name: "Battery,\"State\"",
            unit: "%",
            samples: [Sample(timestamp: timestamp1, value: 75)]
        )

        let csv = CSVExporter.csv(series: [series])

        // The name should be escaped: "Battery,\""State"" (%)
        let expected = #"time,"Battery,""State"" (%)""# + "\r\n" + "2023-01-01T10:00:00Z,75"   // RFC 4180: quote the field, double the quotes

        XCTAssertEqual(csv, expected)
    }

    func testSolarDaysCSVExport() {
        // Load fixture data
        guard let url = Bundle.module.url(forResource: "solarcharger_history", withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not find solarcharger_history.json")
            return
        }

        let historyStore = HistoryStore()
        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let messages = json?["messages"] as? [[String: Any]] ?? []

        for message in messages {
            if let topic = message["topic"] as? String,
               let payloadData = try? JSONSerialization.data(withJSONObject: message["payload"] ?? [:]) {
                historyStore.handle(topic: topic, payload: payloadData)
            }
        }

        // Create SolarDayRecord objects from the history store
        let portalId = "c0ffee000001"
        let instance = "278"
        let baseDate = Calendar.current.date(from: DateComponents(year: 2023, month: 1, day: 1))!

        var solarDays: [SolarDayRecord] = []
        if let days = historyStore.solarDays[instance] {
            for (dayOffset, solarDay) in days {
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: baseDate)!
                let record = SolarDayRecord(
                    portalId: portalId,
                    instance: instance,
                    dayOffsetFetched: dayOffset,
                    date: date,
                    yield: solarDay.yield,
                    maxPower: solarDay.maxPower,
                    maxPvVoltage: solarDay.maxPvVoltage,
                    timeInBulk: solarDay.timeInBulk
                )
                solarDays.append(record)
            }
        }

        let csv = CSVExporter.csv(solarDays: solarDays)

        // Check that we have the expected number of lines (header + 30 data rows)
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 31, "Expected 31 lines (header + 30 data rows)")

        // Check the first data row matches the oldest fixture day
        let firstDataLine = lines[1]
        let expectedFirstLine = "2023-01-01,2.5,450,32.5,450"
        XCTAssertEqual(firstDataLine, expectedFirstLine)
    }

    func testEmptySolarDaysCSVExport() {
        let csv = CSVExporter.csv(solarDays: [])
        let expected = "date,yield_kWh,max_power_W,max_pv_voltage_V,time_in_bulk_min"
        XCTAssertEqual(csv, expected)
    }

    func testEmptySeriesCSVExport() {
        let csv = CSVExporter.csv(series: [])
        XCTAssertEqual(csv, "time", "empty input gives just the header")
    }
}
