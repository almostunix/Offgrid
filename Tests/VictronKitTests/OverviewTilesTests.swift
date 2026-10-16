import XCTest
@testable import VictronKit

final class OverviewTilesTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testTilesShowSolarLoadsInputAndToday() {
        let system = SystemModel(pvPower: 1250, acConsumptionOnOutput: 1180, acConsumptionOnInput: 320,
                                 acGridPower: 300, acGensetPower: 2000)
        let tiles = OverviewTiles.tiles(system: system, solarTodayKWh: 2.5, locale: us)
        XCTAssertEqual(tiles.map(\.label), ["Solar", "Home loads", "AC input", "Solar today"])
        XCTAssertEqual(tiles.map(\.value), ["1,250", "1,500", "2,300", "2.5"])
        XCTAssertEqual(tiles.map(\.unit), ["W", "W", "W", "kWh"])
    }

    func testAcInputIsGridPlusGeneratorNotInputSideLoads() {
        // A 3 kW generator with no loads on the input side reads 3 kW, not 0 W.
        let system = SystemModel(acConsumptionOnInput: 0, acGensetPower: 3000)
        XCTAssertEqual(OverviewTiles.tiles(system: system, solarTodayKWh: nil, locale: us)[2].value, "3,000")
    }

    func testMissingValuesShowADash() {
        let tiles = OverviewTiles.tiles(system: SystemModel(), solarTodayKWh: nil, locale: us)
        XCTAssertEqual(tiles.map(\.value), ["–", "–", "–", "–"], "no value is ever shown as 0 or as another reading")
    }

    func testSolarTodayComesFromTheHistoryCache() throws {
        let cache = HistoryCache(inMemory: true)
        let store = HistoryStore()
        store.handle(topic: "N/c0ffee000001/solarcharger/278/History/Daily/0/Yield", payload: try JSONSerialization.data(withJSONObject: ["value": 2.5]))
        let now = Date()
        cache.store(store, portalId: "c0ffee000001", fetchedAt: now)
        XCTAssertEqual(OverviewTiles.solarTodayKWh(historyCache: cache, portalId: "c0ffee000001", now: now), 2.5)
        XCTAssertNil(OverviewTiles.solarTodayKWh(historyCache: cache, portalId: nil, now: now))
        XCTAssertNil(OverviewTiles.solarTodayKWh(historyCache: HistoryCache(inMemory: true), portalId: "c0ffee000001", now: now))
    }
}
