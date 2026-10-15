import XCTest
@testable import VictronKit

final class TopicFloodTests: XCTestCase {

    func testTopicCountCappedAtMaxTopics() {
        let store = LiveDataStore()
        let maxTopics = LiveDataStore.maxTopics
        
        // Generate 10,000 unique topics
        for i in 0..<10_000 {
            let topic = "N/test/device/123/field/unique\(i)"
            let payload: [String: Any] = ["value": i]
            let payloadData = try! JSONSerialization.data(withJSONObject: payload)
            
            store.handle(topic: topic, payload: payloadData)
        }
        
        // Verify that the count is capped at maxTopics
        XCTAssertEqual(store.receivedTopics.count, maxTopics, "Received topics should be capped at maxTopics")
        XCTAssertEqual(store.droppedTopicCount, 10_000 - maxTopics, "Dropped topic count should be 10,000 - maxTopics")
    }
    
    func testDroppedTopicCountIncrements() {
        let store = LiveDataStore()
        let maxTopics = LiveDataStore.maxTopics
        
        // Fill up to the limit
        for i in 0..<maxTopics {
            let topic = "N/test/device/123/field/unique\(i)"
            let payload: [String: Any] = ["value": i]
            let payloadData = try! JSONSerialization.data(withJSONObject: payload)
            
            store.handle(topic: topic, payload: payloadData)
        }
        
        XCTAssertEqual(store.receivedTopics.count, maxTopics)
        XCTAssertEqual(store.droppedTopicCount, 0)
        
        // Add one more topic - should be dropped
        let extraTopic = "N/test/device/123/field/extra"
        let extraPayload: [String: Any] = ["value": 99999]
        let extraPayloadData = try! JSONSerialization.data(withJSONObject: extraPayload)
        
        store.handle(topic: extraTopic, payload: extraPayloadData)
        
        XCTAssertEqual(store.receivedTopics.count, maxTopics, "Count should remain at maxTopics")
        XCTAssertEqual(store.droppedTopicCount, 1, "Dropped topic count should increment by 1")
    }
    
    func testExistingTopicUpdateDoesNotCountAsDrop() {
        let store = LiveDataStore()
        let maxTopics = LiveDataStore.maxTopics
        
        // Fill up to the limit
        for i in 0..<maxTopics {
            let topic = "N/test/device/123/field/unique\(i)"
            let payload: [String: Any] = ["value": i]
            let payloadData = try! JSONSerialization.data(withJSONObject: payload)
            
            store.handle(topic: topic, payload: payloadData)
        }
        
        XCTAssertEqual(store.receivedTopics.count, maxTopics)
        XCTAssertEqual(store.droppedTopicCount, 0)
        
        // Update an existing topic - should not be dropped
        let existingTopic = "N/test/device/123/field/unique0"
        let updatedPayload: [String: Any] = ["value": 999]
        let updatedPayloadData = try! JSONSerialization.data(withJSONObject: updatedPayload)
        
        store.handle(topic: existingTopic, payload: updatedPayloadData)
        
        XCTAssertEqual(store.receivedTopics.count, maxTopics, "Count should remain unchanged")
        XCTAssertEqual(store.droppedTopicCount, 0, "Dropped topic count should not increment")
    }
    
    func testTopicLookupPerformanceWithIndex() {
        let store = LiveDataStore()
        let maxTopics = LiveDataStore.maxTopics
        
        // Add many topics
        for i in 0..<maxTopics {
            let topic = "N/test/device/123/field/unique\(i)"
            let payload: [String: Any] = ["value": i]
            let payloadData = try! JSONSerialization.data(withJSONObject: payload)
            
            store.handle(topic: topic, payload: payloadData)
        }
        
        // Update a topic that exists - should be fast with index
        let startTime = Date()
        for i in 0..<1000 {
            let topic = "N/test/device/123/field/unique\(i)"
            let payload: [String: Any] = ["value": i + 1000]
            let payloadData = try! JSONSerialization.data(withJSONObject: payload)
            
            store.handle(topic: topic, payload: payloadData)
        }
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        // With indexing, this should complete quickly (less than 1 second)
        XCTAssertLessThan(duration, 1.0, "Topic updates should be fast with indexing")
    }

    // MARK: - HistoryStore Tests

    func testHistoryStoreIgnoresDayOffsetsOutsideRange() {
        let store = HistoryStore()
        
        // Test with day offset 9999 (should be ignored)
        let topic9999 = "N/test/solarcharger/278/History/Daily/9999/Yield"
        let payload9999: [String: Any] = ["value": 123.45]
        let payloadData9999 = try! JSONSerialization.data(withJSONObject: payload9999)
        
        store.handle(topic: topic9999, payload: payloadData9999)
        
        // Verify no data was stored
        XCTAssertTrue(store.solarDays.isEmpty, "Day offset 9999 should be ignored")
    }
    
    func testHistoryStoreAcceptsValidDayOffsets() {
        let store = HistoryStore()
        
        // Test with valid day offsets (0, 1, 364, 365)
        let validOffsets = [0, 1, 364, 365]
        
        for offset in validOffsets {
            let topic = "N/test/solarcharger/278/History/Daily/\(offset)/Yield"
            let payload: [String: Any] = ["value": Double(offset) * 10]
            let payloadData = try! JSONSerialization.data(withJSONObject: payload)
            
            store.handle(topic: topic, payload: payloadData)
        }
        
        // Verify data was stored for valid offsets
        XCTAssertEqual(store.solarDays["278"]?.count, 4, "Should store data for valid day offsets")
        XCTAssertEqual(store.solarDays["278"]?[0]?.yield, 0.0, "Day 0 should be stored")
        XCTAssertEqual(store.solarDays["278"]?[1]?.yield, 10.0, "Day 1 should be stored")
        XCTAssertEqual(store.solarDays["278"]?[364]?.yield, 3640.0, "Day 364 should be stored")
        XCTAssertEqual(store.solarDays["278"]?[365]?.yield, 3650.0, "Day 365 should be stored")
    }
    
    func testHistoryStoreIgnoresNegativeDayOffsets() {
        let store = HistoryStore()
        
        // Test with negative day offset (should be ignored)
        let topic = "N/test/solarcharger/278/History/Daily/-1/Yield"
        let payload: [String: Any] = ["value": 123.45]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        store.handle(topic: topic, payload: payloadData)
        
        // Verify no data was stored
        XCTAssertTrue(store.solarDays.isEmpty, "Negative day offset should be ignored")
    }
    
    func testHistoryStoreIgnoresDayOffset366() {
        let store = HistoryStore()
        
        // Test with day offset 366 (should be ignored)
        let topic = "N/test/solarcharger/278/History/Daily/366/Yield"
        let payload: [String: Any] = ["value": 123.45]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        
        store.handle(topic: topic, payload: payloadData)
        
        // Verify no data was stored
        XCTAssertTrue(store.solarDays.isEmpty, "Day offset 366 should be ignored")
    }
}