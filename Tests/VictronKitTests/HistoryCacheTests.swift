import XCTest
import SwiftData
@testable import VictronKit

/// T-45: the SwiftData history cache. Expected values always come from the fixture, matched by calendar date.
final class HistoryCacheTests: XCTestCase {
    private let portal = "c0ffee000001"
    private let calendar = Calendar.current

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

    private func day(_ offset: Int, before fetch: Date) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: fetch))!
    }

    func testStoresEveryFixtureDayByCalendarDate() throws {
        let (store, expected) = try fixture()
        let cache = HistoryCache(inMemory: true)
        let fetchedAt = Date()
        cache.store(store, portalId: portal, fetchedAt: fetchedAt)

        let records = cache.days(portalId: portal, instance: "278")
        XCTAssertEqual(records.count, 30)
        XCTAssertEqual(records.map(\.date), records.map(\.date).sorted(), "days() is sorted by date")
        let byDate = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        for (offset, fields) in expected {
            let record = try XCTUnwrap(byDate[day(offset, before: fetchedAt)], "day \(offset)")
            XCTAssertEqual(record.yield, fields["Yield"], "day \(offset) Yield")
            XCTAssertEqual(record.maxPower, fields["MaxPower"], "day \(offset) MaxPower")
            XCTAssertEqual(record.maxPvVoltage, fields["MaxPvVoltage"], "day \(offset) MaxPvVoltage")
            XCTAssertEqual(record.timeInBulk, fields["TimeInBulk"], "day \(offset) TimeInBulk")
        }
    }

    func testFetchingOneDayLaterAddsOneDayAndUpdatesOverlap() throws {
        let (store, expected) = try fixture()
        let cache = HistoryCache(inMemory: true)
        let first = Date()
        let second = calendar.date(byAdding: .day, value: 1, to: first)!
        cache.store(store, portalId: portal, fetchedAt: first)
        cache.store(store, portalId: portal, fetchedAt: second)

        let records = cache.days(portalId: portal, instance: "278")
        XCTAssertEqual(records.count, 31, "30 days plus the one new day, no duplicates")
        let byDate = Dictionary(uniqueKeysWithValues: records.map { ($0.date, $0) })
        // The new fetch's day 0 is a brand-new calendar day.
        XCTAssertEqual(byDate[day(0, before: second)]?.yield, expected[0]?["Yield"])
        // The first fetch's day 0 is the second fetch's day 1, so it was overwritten with day-1 values.
        XCTAssertEqual(byDate[day(0, before: first)]?.yield, expected[1]?["Yield"])
        // The oldest day of the first fetch is outside the second fetch, so it is unchanged.
        XCTAssertEqual(byDate[day(29, before: first)]?.yield, expected[29]?["Yield"])
    }

    func testOtherPortalsAndInstancesAreSeparate() throws {
        let (store, _) = try fixture()
        let cache = HistoryCache(inMemory: true)
        cache.store(store, portalId: portal, fetchedAt: Date())
        XCTAssertTrue(cache.days(portalId: "otherportal", instance: "278").isEmpty)
        XCTAssertTrue(cache.days(portalId: portal, instance: "999").isEmpty)
    }
}
