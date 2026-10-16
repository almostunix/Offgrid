//
// RollingBufferTests.swift
//
// Tests for rolling buffer functionality.
//

import XCTest
@testable import VictronKit

final class RollingBufferTests: XCTestCase {
    
    func testEmptyBufferReturnsNilForStats() {
        let buffer = RollingBuffer()
        let window = buffer.getFiveMinuteWindow()
        
        XCTAssertNil(window.min)
        XCTAssertNil(window.max)
        XCTAssertNil(window.avg)
        XCTAssertTrue(window.samples.isEmpty)
    }
    
    func testSingleSampleReturnsSameValueForStats() {
        let timestamp = Date()
        let sample = Sample(timestamp: timestamp, value: 42.0)
        let buffer = RollingBuffer()
        buffer.addSample(sample)
        
        let window = buffer.getFiveMinuteWindow()
        
        XCTAssertEqual(window.min, 42.0)
        XCTAssertEqual(window.max, 42.0)
        XCTAssertEqual(window.avg, 42.0)
        XCTAssertEqual(window.samples.count, 1)
        XCTAssertEqual(window.samples.first?.value, 42.0)
    }
    
    func testMultipleSamplesCalculateCorrectStats() {
        let timestamp = Date()
        let buffer = RollingBuffer()
        
        // Add samples with values 10, 20, 30, 40, 50
        for value in [10.0, 20.0, 30.0, 40.0, 50.0] {
            let sample = Sample(timestamp: timestamp, value: value)
            buffer.addSample(sample)
        }
        
        let window = buffer.getFiveMinuteWindow()
        
        XCTAssertEqual(window.min, 10.0)
        XCTAssertEqual(window.max, 50.0)
        XCTAssertEqual(window.avg, 30.0)
        XCTAssertEqual(window.samples.count, 5)
    }
    
    // Samples are added in time order (as they arrive live), with clear margins around the window edge,
    // so a few microseconds between creating samples and reading the window can't change the result.

    func testFiveMinuteWindowTrimsOldSamples() {
        let now = Date()
        let buffer = RollingBuffer()
        for (age, value) in [(400.0, 1.0), (310.0, 2.0), (290.0, 3.0), (100.0, 4.0), (5.0, 5.0)] {
            buffer.addSample(Sample(timestamp: now.addingTimeInterval(-age), value: value))
        }
        let window = buffer.getFiveMinuteWindow(at: now)
        XCTAssertEqual(window.samples.map(\.value), [3.0, 4.0, 5.0])
    }

    func testFiveMinuteWindowDropsSamplesOlderThan300Seconds() {
        let now = Date()
        let buffer = RollingBuffer()
        buffer.addSample(Sample(timestamp: now.addingTimeInterval(-301.0), value: 10.0))
        buffer.addSample(Sample(timestamp: now.addingTimeInterval(-299.0), value: 20.0))
        let window = buffer.getFiveMinuteWindow(at: now)
        XCTAssertEqual(window.samples.map(\.value), [20.0])
    }

    func testOneHourWindowTrimsOldSamples() {
        let now = Date()
        let buffer = RollingBuffer()
        for (age, value) in [(4000.0, 1.0), (3610.0, 2.0), (3500.0, 3.0), (3000.0, 4.0), (60.0, 5.0)] {
            buffer.addSample(Sample(timestamp: now.addingTimeInterval(-age), value: value))
        }
        let window = buffer.getOneHourWindow(at: now)
        XCTAssertEqual(window.samples.map(\.value), [3.0, 4.0, 5.0])
    }

    func testOneHourWindowDropsSamplesOlderThan3600Seconds() {
        let now = Date()
        let buffer = RollingBuffer()
        buffer.addSample(Sample(timestamp: now.addingTimeInterval(-3601.0), value: 10.0))
        buffer.addSample(Sample(timestamp: now.addingTimeInterval(-3599.0), value: 20.0))
        let window = buffer.getOneHourWindow(at: now)
        XCTAssertEqual(window.samples.map(\.value), [20.0])
    }

    func testFiveMinuteSampleStillInHourWindow() {
        let now = Date()
        let buffer = RollingBuffer()
        buffer.addSample(Sample(timestamp: now.addingTimeInterval(-900.0), value: 7.0))
        XCTAssertTrue(buffer.getFiveMinuteWindow(at: now).samples.isEmpty)
        XCTAssertEqual(buffer.getOneHourWindow(at: now).samples.map(\.value), [7.0])
    }

    func testBothWindowsMaintainIndependentBuffers() {
        let currentTime = Date()
        let buffer = RollingBuffer()
        
        // Add a sample that's 301 seconds old (outside 5-minute window, inside 1-hour window)
        let sample = Sample(timestamp: currentTime.addingTimeInterval(-301.0), value: 42.0)
        buffer.addSample(sample)
        
        let fiveMinuteWindow = buffer.getFiveMinuteWindow(at: currentTime)
        let oneHourWindow = buffer.getOneHourWindow(at: currentTime)
        
        // 5-minute window should be empty
        XCTAssertEqual(fiveMinuteWindow.samples.count, 0)
        
        // 1-hour window should have the sample
        XCTAssertEqual(oneHourWindow.samples.count, 1)
        XCTAssertEqual(oneHourWindow.samples.first?.value, 42.0)
    }
    
    func testRollingBufferTrimsOnInsert() {
        let buffer = RollingBuffer()
        let startTime = Date()
        
        // Add 10,000 samples one second apart without calling a getter
        for i in 0..<10000 {
            let sample = Sample(timestamp: startTime.addingTimeInterval(TimeInterval(i)), value: Double(i))
            buffer.addSample(sample)
        }
        
        // After adding samples, buffers should be trimmed automatically
        // 5-minute buffer should contain at most 301 samples (300 seconds + 1 current)
        // 1-hour buffer should contain at most 3601 samples (3600 seconds + 1 current)
        XCTAssertLessThanOrEqual(buffer.fiveMinuteCount, 301)
        XCTAssertLessThanOrEqual(buffer.oneHourCount, 3601)
    }
    
    func testSampleEquality() {
        let timestamp1 = Date()
        let timestamp2 = timestamp1.addingTimeInterval(1.0)
        
        let sample1a = Sample(timestamp: timestamp1, value: 10.0)
        let sample1b = Sample(timestamp: timestamp1, value: 10.0)
        let sample2 = Sample(timestamp: timestamp2, value: 10.0)
        let sample3 = Sample(timestamp: timestamp1, value: 20.0)
        
        XCTAssertEqual(sample1a, sample1b)
        XCTAssertNotEqual(sample1a, sample2)
        XCTAssertNotEqual(sample1a, sample3)
    }
    
    func testRollingWindowEquality() {
        let timestamp = Date()
        let sample1 = Sample(timestamp: timestamp, value: 10.0)
        let sample2 = Sample(timestamp: timestamp, value: 20.0)
        
        let window1a = RollingWindow(samples: [sample1, sample2])
        let window1b = RollingWindow(samples: [sample1, sample2])
        let window2 = RollingWindow(samples: [sample1])
        
        XCTAssertEqual(window1a, window1b)
        XCTAssertNotEqual(window1a, window2)
    }
}