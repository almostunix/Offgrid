//
// LiveSeriesRecorderTests.swift
//
// Tests for LiveSeriesRecorder
//

import XCTest
import Combine
@testable import VictronKit

final class LiveSeriesRecorderTests: XCTestCase {
    private var store: LiveDataStore!
    private var parser: TopicParser!
    private var recorder: LiveSeriesRecorder!
    private var cancellables: Set<AnyCancellable>!
    private var testDate: Date!
    
    override func setUp() {
        super.setUp()
        store = LiveDataStore()
        parser = TopicParser()
        testDate = Date()
        recorder = LiveSeriesRecorder(store: store, now: { [weak self] in self?.testDate ?? Date() })   // a late debounced record must not touch a torn-down test
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        store = nil
        parser = nil
        recorder = nil
        cancellables = nil
        testDate = nil
        super.tearDown()
    }
    
    func testRecordInitialValues() throws {
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
        
        // Check each series has one sample with correct value
        let batteryPowerBuffer = recorder.buffer(for: .batteryPower)
        let batteryPowerWindow = batteryPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batteryPowerWindow.samples.count, 1)
        XCTAssertEqual(batteryPowerWindow.samples[0].value, 66.56)
        
        let batterySocBuffer = recorder.buffer(for: .batterySoc)
        let batterySocWindow = batterySocBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batterySocWindow.samples.count, 1)
        XCTAssertEqual(batterySocWindow.samples[0].value, 78.5)
        
        let pvPowerBuffer = recorder.buffer(for: .pvPower)
        let pvPowerWindow = pvPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(pvPowerWindow.samples.count, 1)
        XCTAssertEqual(pvPowerWindow.samples[0].value, 1250)
        
        let acConsumptionBuffer = recorder.buffer(for: .acConsumption)
        let acConsumptionWindow = acConsumptionBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(acConsumptionWindow.samples.count, 1)
        XCTAssertEqual(acConsumptionWindow.samples[0].value, 1500) // 1180 + 320
    }
    
    func testRecordMultipleSamples() throws {
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
        
        // Record first set of values
        recorder.record()
        
        // Advance time and change battery power
        testDate = Date(timeInterval: 10, since: testDate)
        let newPowerPayload: [String: Any] = ["value": 75.0]
        
        guard let newPowerMessage = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: newPowerPayload) else {
            XCTFail("Should be able to parse new power message")
            return
        }
        
        store.update(with: newPowerMessage)
        
        // Record second set of values
        recorder.record()
        
        // Check battery power has 2 samples
        let batteryPowerBuffer = recorder.buffer(for: .batteryPower)
        let batteryPowerWindow = batteryPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batteryPowerWindow.samples.count, 2)
        XCTAssertEqual(batteryPowerWindow.samples[0].value, 66.56)
        XCTAssertEqual(batteryPowerWindow.samples[1].value, 75.0)
    }
    
    func testSkipNilValues() throws {
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
        
        // Record first set of values
        recorder.record()
        
        // Set battery power to nil
        let nilPowerPayload: [String: Any] = ["value": NSNull()]
        
        guard let nilPowerMessage = parser.parseMessage(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: nilPowerPayload) else {
            XCTFail("Should be able to parse nil power message")
            return
        }
        
        store.update(with: nilPowerMessage)
        
        // Advance time
        testDate = Date(timeInterval: 10, since: testDate)
        
        // Record second set of values (should skip nil)
        recorder.record()
        
        // Check battery power still has only 1 sample
        let batteryPowerBuffer = recorder.buffer(for: .batteryPower)
        let batteryPowerWindow = batteryPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batteryPowerWindow.samples.count, 1)
    }
    
    func testFiveMinuteWindowTrimming() throws {
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
        
        // Record first set of values
        recorder.record()
        
        // Advance time by 6 minutes (360 seconds)
        testDate = Date(timeInterval: 360, since: testDate)
        
        // Record second set of values
        recorder.record()
        
        // Check battery power has only 1 sample (old one should be trimmed)
        let batteryPowerBuffer = recorder.buffer(for: .batteryPower)
        let batteryPowerWindow = batteryPowerBuffer.getFiveMinuteWindow(at: testDate)
        XCTAssertEqual(batteryPowerWindow.samples.count, 1)
    }
    
    func testStoreChangesTriggerARecordAfterTheDebounce() throws {
        var recorded = false
        recorder.objectWillChange.sink { recorded = true }.store(in: &cancellables)   // subscribe BEFORE changing the store
        let payload = try JSONSerialization.data(withJSONObject: ["value": 66.56])
        store.handle(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: payload)

        // The recorder debounces store changes by 1 s on the main queue, so let the main run loop turn for up to 3 s.
        let end = Date().addingTimeInterval(3)
        while !recorded && Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(recorded, "a store change should lead to a record within the debounce window")
        XCTAssertEqual(recorder.buffer(for: .batteryPower).getFiveMinuteWindow(at: testDate).samples.map(\.value), [66.56])
    }

    func testResetEmptiesEveryBuffer() throws {
        let store = LiveDataStore()
        let recorder = LiveSeriesRecorder(store: store)
        store.handle(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: try JSONSerialization.data(withJSONObject: ["value": 120.0]))
        recorder.record()
        XCTAssertFalse(recorder.buffer(for: .batteryPower).getFiveMinuteWindow().samples.isEmpty)

        recorder.reset()

        for series in LiveSeries.allCases {
            XCTAssertTrue(recorder.buffer(for: series).getFiveMinuteWindow().samples.isEmpty, "\(series) not cleared")
            XCTAssertTrue(recorder.buffer(for: series).getOneHourWindow().samples.isEmpty, "\(series) not cleared")
        }
    }
    
    func testRapidStoreChangesTriggerMultipleRecords() throws {
        // This test verifies that rapid store changes (like from a real Cerbo) 
        // trigger multiple records, not just one debounced record
        
        // Change store value every 200 ms (real time, as a Cerbo does) for 3 seconds (15 updates)
        let startTime = testDate!
        let endTime = startTime.addingTimeInterval(3.0)
        var iteration = 0
        
        while testDate! < endTime {
            let payload = try JSONSerialization.data(withJSONObject: ["value": Double(iteration * 10)])
            store.handle(topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: payload)
            
            // Advance time by 200ms
            testDate = testDate!.addingTimeInterval(0.2)
            
            // Give the run loop a chance to process
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            
            iteration += 1
        }
        
        // Wait a bit more for any pending operations
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        
        // With throttle, we should get multiple samples (at least 2) in the buffer
        // With debounce, we would only get 1 sample
        let batteryPowerBuffer = recorder.buffer(for: .batteryPower)
        let samples = batteryPowerBuffer.getFiveMinuteWindow(at: testDate).samples
        
        XCTAssertGreaterThanOrEqual(samples.count, 2, "Rapid store changes should trigger multiple records, got: \(samples.count)")
    }
}
