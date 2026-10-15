//
// LiveChartsTests.swift
//
// Tests for LiveChartsScreen and related functionality
//

import XCTest
import Combine
@testable import VictronKit

final class LiveChartsTests: XCTestCase {
    
    func testTimeRangeCases() {
        let ranges = TimeRange.allCases
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0].rawValue, "fiveMinutes")
        XCTAssertEqual(ranges[1].rawValue, "oneHour")
        // Test case
    }
    
    func testTimeRangeDisplayNames() {
        XCTAssertEqual(TimeRange.fiveMinutes.displayName, "5 min")
        XCTAssertEqual(TimeRange.oneHour.displayName, "1 hour")
    }
    
    func testTimeRangeGetWindow() {
        let store = LiveDataStore()
        let recorder = LiveSeriesRecorder(store: store, now: { Date() })
        
        // Test 5-minute window
        let fiveMinuteWindow = TimeRange.fiveMinutes.getWindow(for: recorder, series: .batterySoc)
        XCTAssertTrue(fiveMinuteWindow.samples.isEmpty)
        
        // Test 1-hour window
        let oneHourWindow = TimeRange.oneHour.getWindow(for: recorder, series: .batterySoc)
        XCTAssertTrue(oneHourWindow.samples.isEmpty)
    }
    
    func testLiveSeriesRecorderIntegration() {
        let store = LiveDataStore()
        let parser = TopicParser()
        let testDate = Date()
        let recorder = LiveSeriesRecorder(store: store, now: { testDate })
        
        // Feed system messages
        let messages = [
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": -1250.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1500.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 851.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 300.0])
        ]
        
        for (topic, payload) in messages {
            if let message = parser.parseMessage(topic: topic, payload: payload) {
                store.update(with: message)
            }
        }
        
        // Record values
        recorder.record()
        
        // Verify all series have samples
        let batterySocBuffer = recorder.buffer(for: .batterySoc)
        let batterySocWindow = batterySocBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batterySocWindow.samples.count, 1)
        XCTAssertEqual(batterySocWindow.samples[0].value, 78.5)
        
        let batteryPowerBuffer = recorder.buffer(for: .batteryPower)
        let batteryPowerWindow = batteryPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batteryPowerWindow.samples.count, 1)
        XCTAssertEqual(batteryPowerWindow.samples[0].value, -1250.0)
        
        let pvPowerBuffer = recorder.buffer(for: .pvPower)
        let pvPowerWindow = pvPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(pvPowerWindow.samples.count, 1)
        XCTAssertEqual(pvPowerWindow.samples[0].value, 1500.0)
        
        let acConsumptionBuffer = recorder.buffer(for: .acConsumption)
        let acConsumptionWindow = acConsumptionBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(acConsumptionWindow.samples.count, 1)
        XCTAssertEqual(acConsumptionWindow.samples[0].value, 1151.0) // 851 + 300
    }
    
    func testRollingWindowStats() {
        let timestamp = Date()
        let samples = [
            Sample(timestamp: timestamp, value: 10.0),
            Sample(timestamp: timestamp.addingTimeInterval(10), value: 20.0),
            Sample(timestamp: timestamp.addingTimeInterval(20), value: 30.0),
            Sample(timestamp: timestamp.addingTimeInterval(30), value: 40.0),
            Sample(timestamp: timestamp.addingTimeInterval(40), value: 50.0)
        ]
        
        let window = RollingWindow(samples: samples)
        
        XCTAssertEqual(window.min, 10.0)
        XCTAssertEqual(window.max, 50.0)
        XCTAssertEqual(window.avg, 30.0)
        XCTAssertEqual(window.samples.count, 5)
    }
    
    func testSampleEquality() {
        let timestamp = Date()
        let sample1 = Sample(timestamp: timestamp, value: 10.0)
        let sample2 = Sample(timestamp: timestamp, value: 10.0)
        let sample3 = Sample(timestamp: timestamp, value: 20.0)
        
        XCTAssertEqual(sample1, sample2)
        XCTAssertNotEqual(sample1, sample3)
    }
    
    func testLiveSeriesCases() {
        let series = LiveSeries.allCases
        XCTAssertEqual(series.count, 4)
        XCTAssertEqual(series[0].rawValue, "batteryPower")
        XCTAssertEqual(series[1].rawValue, "batterySoc")
        XCTAssertEqual(series[2].rawValue, "pvPower")
        XCTAssertEqual(series[3].rawValue, "acConsumption")
    }
    
    func testTimeRangeWithMultipleSamples() {
        let store = LiveDataStore()
        let parser = TopicParser()
        let testDate = Date()
        let recorder = LiveSeriesRecorder(store: store, now: { testDate })
        
        // Feed multiple values over time
        for i in 0..<5 {
            let socValue = 70.0 + Double(i) * 2.0
            let powerValue = -1000.0 + Double(i) * 50.0
            
            let socPayload: [String: Any] = ["value": socValue]
            let powerPayload: [String: Any] = ["value": powerValue]
            
            if let socMessage = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: socPayload),
               let powerMessage = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: powerPayload) {
                store.update(with: socMessage)
                store.update(with: powerMessage)
            }
            
            // Advance time
            let newDate = testDate.addingTimeInterval(Double(i) * 60)
            recorder.record()
        }
        
        // Test 5-minute window
        let fiveMinuteWindow = TimeRange.fiveMinutes.getWindow(for: recorder, series: .batterySoc)
        XCTAssertEqual(fiveMinuteWindow.samples.count, 5)
        XCTAssertEqual(fiveMinuteWindow.min, 70.0)
        XCTAssertEqual(fiveMinuteWindow.max, 78.0)
        XCTAssertEqual(fiveMinuteWindow.avg, 74.0)
        
        // Test 1-hour window
        let oneHourWindow = TimeRange.oneHour.getWindow(for: recorder, series: .batterySoc)
        XCTAssertEqual(oneHourWindow.samples.count, 5)
    }
    
    func testWindowTrimming() {
        let baseDate = Date()
        let buffer = RollingBuffer()
        
        // Add samples over 10 minutes
        for i in 0..<10 {
            let sampleTime = baseDate.addingTimeInterval(Double(i) * 60)
            let value = 70.0 + Double(i) * 2.0
            buffer.addSample(Sample(timestamp: sampleTime, value: value))
        }
        
        // Test 5-minute window should only have samples from last 300 seconds
        let fiveMinuteWindow = buffer.getFiveMinuteWindow(at: baseDate.addingTimeInterval(600))
        // Samples at 300, 360, 420, 480, 540 seconds should remain (5 samples)
        XCTAssertLessThanOrEqual(fiveMinuteWindow.samples.count, 5)
        
        // Test 1-hour window should have all samples
        let oneHourWindow = buffer.getOneHourWindow(at: baseDate.addingTimeInterval(600))
        XCTAssertEqual(oneHourWindow.samples.count, 10)
    }
    
    func testRollingWindowStatsForInteractiveChart() {
        let baseDate = Date()
        let samples = [
            Sample(timestamp: baseDate, value: 10.0),
            Sample(timestamp: baseDate.addingTimeInterval(60), value: 20.0),
            Sample(timestamp: baseDate.addingTimeInterval(120), value: 30.0),
            Sample(timestamp: baseDate.addingTimeInterval(180), value: 40.0),
            Sample(timestamp: baseDate.addingTimeInterval(240), value: 50.0)
        ]
        
        let window = RollingWindow(samples: samples)
        
        // Test stats used by InteractiveChart
        XCTAssertEqual(window.min, 10.0, "Min value should be 10.0")
        XCTAssertEqual(window.max, 50.0, "Max value should be 50.0")
        XCTAssertEqual(window.avg, 30.0, "Average value should be 30.0")
        XCTAssertEqual(window.samples.count, 5, "Should have 5 samples")
    }
    
    func testRollingWindowEmptyStats() {
        let window = RollingWindow(samples: [])
        
        // Test that empty window returns nil for stats
        XCTAssertNil(window.min, "Empty window should return nil for min")
        XCTAssertNil(window.max, "Empty window should return nil for max")
        XCTAssertNil(window.avg, "Empty window should return nil for avg")
        XCTAssertTrue(window.samples.isEmpty, "Empty window should have no samples")
    }
    
    func testRollingWindowSingleSampleStats() {
        let baseDate = Date()
        let samples = [Sample(timestamp: baseDate, value: 42.0)]
        let window = RollingWindow(samples: samples)
        
        // Test single sample stats
        XCTAssertEqual(window.min, 42.0, "Single sample min should be the sample value")
        XCTAssertEqual(window.max, 42.0, "Single sample max should be the sample value")
        XCTAssertEqual(window.avg, 42.0, "Single sample avg should be the sample value")
        XCTAssertEqual(window.samples.count, 1, "Should have 1 sample")
    }
    
    func testRollingWindowNegativeValues() {
        let baseDate = Date()
        let samples = [
            Sample(timestamp: baseDate, value: -10.0),
            Sample(timestamp: baseDate.addingTimeInterval(60), value: -5.0),
            Sample(timestamp: baseDate.addingTimeInterval(120), value: 0.0),
            Sample(timestamp: baseDate.addingTimeInterval(180), value: 5.0),
            Sample(timestamp: baseDate.addingTimeInterval(240), value: 10.0)
        ]
        
        let window = RollingWindow(samples: samples)
        
        // Test stats with negative values
        XCTAssertEqual(window.min, -10.0, "Min value should be -10.0")
        XCTAssertEqual(window.max, 10.0, "Max value should be 10.0")
        XCTAssertEqual(window.avg, 0.0, "Average value should be 0.0")
        XCTAssertEqual(window.samples.count, 5, "Should have 5 samples")
    }
    
    func testInteractiveChartIntegration() {
        let store = LiveDataStore()
        let parser = TopicParser()
        let testDate = Date()
        let recorder = LiveSeriesRecorder(store: store, now: { testDate })
        
        // Feed multiple values over time to create a window with stats
        for i in 0..<5 {
            let socValue = 70.0 + Double(i) * 5.0
            let socPayload: [String: Any] = ["value": socValue]
            
            if let socMessage = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: socPayload) {
                store.update(with: socMessage)
            }
            
            // Advance time and record
            let newDate = testDate.addingTimeInterval(Double(i) * 60)
            recorder.record()
        }
        
        // Test that the window has the expected stats
        let window = TimeRange.fiveMinutes.getWindow(for: recorder, series: .batterySoc)
        XCTAssertEqual(window.samples.count, 5, "Should have 5 samples")
        XCTAssertEqual(window.min, 70.0, "Min should be 70.0")
        XCTAssertEqual(window.max, 90.0, "Max should be 90.0")
        XCTAssertEqual(window.avg, 80.0, "Avg should be 80.0")
    }
    
    func testInteractiveChartEmptyState() {
        let store = LiveDataStore()
        let recorder = LiveSeriesRecorder(store: store, now: { Date() })
        
        // Test with no data
        let window = TimeRange.fiveMinutes.getWindow(for: recorder, series: .batterySoc)
        XCTAssertTrue(window.samples.isEmpty, "Empty window should have no samples")
        XCTAssertNil(window.min, "Empty window should return nil for min")
        XCTAssertNil(window.max, "Empty window should return nil for max")
        XCTAssertNil(window.avg, "Empty window should return nil for avg")
    }
}
