//
// OverviewTiles.swift
//
// The 2×2 metric tiles on the live overview (Night style, T-71): plain values, so the screen just draws them.
//

import Foundation

public enum OverviewTiles {
    public enum Tint: Equatable { case solar, battery, grid, home }

    public struct Tile: Equatable {
        public let icon: String
        public let label: String
        public let value: String
        public let unit: String
        public let tint: Tint
    }

    /// Solar, home loads (output + input-side loads), AC input (grid + generator) and today's solar yield.
    public static func tiles(system: SystemModel, solarTodayKWh: Double?, locale: Locale = .current) -> [Tile] {
        let solar = MetricFormat.watts(system.pvPower, locale: locale)
        let loads = MetricFormat.watts(system.acConsumptionTotal, locale: locale)
        let input = MetricFormat.watts(system.acInputPower, locale: locale)
        let today = MetricFormat.kWh(solarTodayKWh, locale: locale)
        return [
            Tile(icon: "sun.max", label: "Solar", value: solar.value, unit: solar.unit, tint: .solar),
            Tile(icon: "house", label: "Home loads", value: loads.value, unit: loads.unit, tint: .home),
            Tile(icon: "bolt", label: "AC input", value: input.value, unit: input.unit, tint: .grid),
            Tile(icon: "chart.bar", label: "Solar today", value: today.value, unit: today.unit, tint: .solar),
        ]
    }

    /// Today's yield of the first solar charger in the history cache, or nil (shown as "–") when there is none.
    public static func solarTodayKWh(historyCache: HistoryCache, portalId: String?, now: Date = Date()) -> Double? {
        guard let portalId, let instance = historyCache.instances(portalId: portalId).first else { return nil }
        return historyCache.days(portalId: portalId, instance: instance)
            .first { Calendar.current.isDate($0.date, inSameDayAs: now) }?.yield
    }
}
