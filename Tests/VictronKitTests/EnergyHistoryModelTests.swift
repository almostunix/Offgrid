//
// EnergyHistoryModelTests.swift
//
// Tests for EnergyHistoryModel helper functions
//

import XCTest
@testable import VictronKit

final class EnergyHistoryModelTests: XCTestCase {
    private let portal = "c0ffee000001"
    private let instance = "278"
    private let calendar = Calendar.current

    func testBarsWith7Days() throws {
        // Create test data using the fixture
        let (store, expected) = try fixture()
        let now = Date()
        
        // Store in cache
        let cache = HistoryCache(inMemory: true)
        cache.store(store, portalId: portal, fetchedAt: now)
        
        // Get records and convert to bars
        let records = cache.days(portalId: portal, instance: instance)
        let bars = EnergyHistoryModel.bars(from: records, lastDays: 7, now: now)
        
        // Should have exactly 7 bars
        XCTAssertEqual(bars.count, 7, "Should have exactly 7 bars for 7 days")
        
        // The last bar should be today
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        XCTAssertEqual(bars.last?.date, startOfToday, "Last bar should be today")
        
        // Check values match expected (oldest first)
        for (offset, bar) in bars.enumerated() {
            let expectedOffset = 6 - offset // Reverse order: 6, 5, 4, 3, 2, 1, 0
            let expectedYield = expected[expectedOffset]!["Yield"]!
            XCTAssertEqual(bar.kWh, expectedYield, "Bar at offset \(offset) should match expected value")
        }
    }

    func testBarsWith30Days() throws {
        // Create test data using the fixture
        let (store, _) = try fixture()
        let now = Date()
        
        // Store in cache
        let cache = HistoryCache(inMemory: true)
        cache.store(store, portalId: portal, fetchedAt: now)
        
        // Get records and convert to bars
        let records = cache.days(portalId: portal, instance: instance)
        let bars = EnergyHistoryModel.bars(from: records, lastDays: 30, now: now)
        
        // Should have exactly 30 bars
        XCTAssertEqual(bars.count, 30, "Should have exactly 30 bars for 30 days")
    }

    func testBarsFiltersByDateRange() throws {
        // Create test data using the fixture
        let (store, _) = try fixture()
        let now = Date()
        
        // Store in cache
        let cache = HistoryCache(inMemory: true)
        cache.store(store, portalId: portal, fetchedAt: now)
        
        // Get records and convert to bars for 7 days
        let records = cache.days(portalId: portal, instance: instance)
        let bars7 = EnergyHistoryModel.bars(from: records, lastDays: 7, now: now)
        
        // Should have exactly 7 bars
        XCTAssertEqual(bars7.count, 7, "Should have exactly 7 bars for 7 days")
        
        // Get records and convert to bars for 30 days
        let bars30 = EnergyHistoryModel.bars(from: records, lastDays: 30, now: now)
        
        // Should have exactly 30 bars
        XCTAssertEqual(bars30.count, 30, "Should have exactly 30 bars for 30 days")
        
        // Test that a record 8 days before now is excluded from 7-day view
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: startOfToday)!
        
        // Create a store with an 8-day-old record using handle method
        let testStore = HistoryStore()
        let topic = "N/\(portal)/solarcharger/\(instance)/History/Daily/8/Yield"
        let payload = ["value": 1.5] as [String : Any]
        testStore.handle(topic: topic, payload: try JSONSerialization.data(withJSONObject: payload))
        
        // Store it
        cache.store(testStore, portalId: portal, fetchedAt: now)
        
        // Should still only have 7 bars (8 days ago should be excluded)
        let barsAfterInsert = EnergyHistoryModel.bars(from: cache.days(portalId: portal, instance: instance), lastDays: 7, now: now)
        XCTAssertEqual(barsAfterInsert.count, 7, "Should still have exactly 7 bars even after adding an 8-day-old record")
    }

    func testBarsSkipsNilYield() throws {
        // Create test data with 30 days using the fixture
        let (store, _) = try fixture()
        let now = Date()
        
        // Store in cache
        let cache = HistoryCache(inMemory: true)
        cache.store(store, portalId: portal, fetchedAt: now)
        
        // Get records and convert to bars
        let records = cache.days(portalId: portal, instance: instance)
        let bars = EnergyHistoryModel.bars(from: records, lastDays: 30, now: now)
        
        // Should have 30 bars (fixture has valid yields)
        XCTAssertEqual(bars.count, 30, "Should have 30 bars")
    }

    func testInstances() throws {
        // Create test data using the fixture
        let (store, _) = try fixture()
        let now = Date()
        
        // Store in cache
        let cache = HistoryCache(inMemory: true)
        cache.store(store, portalId: portal, fetchedAt: now)
        
        // Should return ["278"] for the test portal
        let instances = cache.instances(portalId: portal)
        XCTAssertEqual(instances, ["278"], "Should return [\"278\"] for the test portal")
        
        // Should return empty array for a different portal
        let otherInstances = cache.instances(portalId: "different_portal")
        XCTAssertEqual(otherInstances, [], "Should return empty array for a different portal")
    }

    /// The fixture as a HistoryStore, plus the fixture's values per day offset (0 = the fetch day).
    private func fixture() throws -> (HistoryStore, [Int: [String: Double]]) {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "solarcharger_history", withExtension: "json", subdirectory: "Fixtures"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let store = HistoryStore()
        var expected: [Int: [String: Double]] = [:]
        for message in try XCTUnwrap(json["messages"] as? [[String: Any]]) {
            let topic = try XCTUnwrap(message["topic"] as? String)
            let payload = try XCTUnwrap(message["payload"] as? [String: Any])
            store.handle(topic: topic, payload: try JSONSerialization.data(withJSONObject: payload))
            let parts = topic.split(separator: "/")   // N/<id>/solarcharger/278/History/Daily/<n>/<Field>
            if parts.count == 8, let day = Int(parts[6]), let value = payload["value"] as? Double {
                expected[day, default: [:]][String(parts[7])] = value
            }
        }
        return (store, expected)
    }
}
