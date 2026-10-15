//
// CSVDocumentTests.swift
//
// Tests for CSVDocument functionality
//

import XCTest
@testable import VictronKit

final class CSVDocumentTests: XCTestCase {
    private var store: LiveDataStore!
    private var parser: TopicParser!
    private var recorder: LiveSeriesRecorder!
    private var testDate: Date!

    override func setUp() {
        super.setUp()
        store = LiveDataStore()
        parser = TopicParser()
        testDate = Date()
        recorder = LiveSeriesRecorder(store: store, now: { [weak self] in self?.testDate ?? Date() })
    }

    override func tearDown() {
        store = nil
        parser = nil
        recorder = nil
        testDate = nil
        super.tearDown()
    }

    func testLiveCSVDocumentCreation() {
        // Feed system messages directly
        let messages = [
            (topic: "N/c0ffee000001/system/0/Serial", payload: ["value": "HQ212200XA"]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": 66.56]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1250]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 1180]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 320])
        ]

        // Feed messages through store
        for (topic, payload) in messages {
            guard let message = parser.parseMessage(topic: topic, payload: payload) else {
                XCTFail("Should be able to parse message: \(topic)")
                continue
            }
            store.update(with: message)
        }

        // Record values
        recorder.record()

        // Create CSVDocument for 5-minute range
        let document = CSVDocument.live(recorder: recorder, timeRange: .fiveMinutes, now: testDate)

        // Check filename
        XCTAssertEqual(document.filename, "cerbo-live-fiveMinutes.csv")

        // Check that the CSV text matches what CSVExporter would produce
        let expectedSeries = LiveSeries.allCases.map { series -> (name: String, unit: String, samples: [Sample]) in
            let window = TimeRange.fiveMinutes.getWindow(for: recorder, series: series)
            let unit = series == .batterySoc ? "%" : "W"
            return (name: series.rawValue, unit: unit, samples: window.samples)
        }

        let expectedCSV = CSVExporter.csv(series: expectedSeries)
        XCTAssertEqual(document.text, expectedCSV)

        // Check that header contains all series names
        let lines = document.text.components(separatedBy: "\r\n")
        XCTAssertFalse(lines.isEmpty)
        let header = lines[0]
        
        for series in LiveSeries.allCases {
            let unit = series == .batterySoc ? "%" : "W"
            let expectedHeaderPart = series.rawValue + " (" + unit + ")"
            XCTAssertTrue(header.contains(expectedHeaderPart), "Header should contain " + series.rawValue + " (" + unit + ")")
        }
    }

    func testLiveCSVDocumentDifferentTimeRanges() {
        // Feed system messages directly
        let messages = [
            (topic: "N/c0ffee000001/system/0/Serial", payload: ["value": "HQ212200XA"]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": 66.56]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1250]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 1180]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 320])
        ]

        // Feed messages through store
        for (topic, payload) in messages {
            guard let message = parser.parseMessage(topic: topic, payload: payload) else {
                XCTFail("Should be able to parse message: \(topic)")
                continue
            }
            store.update(with: message)
        }

        // Record values
        recorder.record()

        // Test both time ranges
        for timeRange in TimeRange.allCases {
            let document = CSVDocument.live(recorder: recorder, timeRange: timeRange, now: testDate)
            XCTAssertEqual(document.filename, "cerbo-live-" + timeRange.rawValue + ".csv")
            
            // Verify CSV is not empty
            XCTAssertFalse(document.text.isEmpty)
            
            // Verify it has a header
            let lines = document.text.components(separatedBy: "\r\n")
            XCTAssertFalse(lines.isEmpty)
            XCTAssertTrue(lines[0].contains("time"))
        }
    }

    func testHistoryCSVDocumentCreation() {
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

        // Create CSVDocument
        let document = CSVDocument.history(solarDays)

        // Check filename
        XCTAssertEqual(document.filename, "cerbo-history.csv")

        // Check that the CSV text matches what CSVExporter would produce
        let expectedCSV = CSVExporter.csv(solarDays: solarDays)
        XCTAssertEqual(document.text, expectedCSV)

        // Check that we have the expected number of lines
        let lines = document.text.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 31, "Expected 31 lines (header + 30 data rows)")
    }

    func testHistoryCSVDocumentEmpty() {
        let document = CSVDocument.history([])
        XCTAssertEqual(document.filename, "cerbo-history.csv")
        
        // Should have header only
        let lines = document.text.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0], "date,yield_kWh,max_power_W,max_pv_voltage_V,time_in_bulk_min")
    }
}
