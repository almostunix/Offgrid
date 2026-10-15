import Foundation

/// Display strings for measured values: (number, unit). A missing value shows "–". The sign is kept, so a
/// discharging battery reads "-400" (screens add "Charging"/"Discharging" from the sign).
public enum MetricFormat {
    public static func watts(_ value: Double?, locale: Locale = .current) -> (value: String, unit: String) {
        guard let value, value.isFinite else { return ("–", "") }
        if abs(value) >= 10_000 { return (number(value / 1000, digits: 1, locale: locale), "kW") }
        return (number(value, digits: 0, locale: locale), "W")
    }

    public static func percent(_ value: Double?, locale: Locale = .current) -> (value: String, unit: String) {
        guard let value, value.isFinite else { return ("–", "") }
        return (number(value, digits: 0, locale: locale), "%")
    }

    public static func kWh(_ value: Double?, locale: Locale = .current) -> (value: String, unit: String) {
        guard let value, value.isFinite else { return ("–", "") }
        return (number(value, digits: 1, locale: locale), "kWh")
    }

    /// Grouped, rounded half away from zero (50.5 -> 51, not banker's rounding).
    private static func number(_ value: Double, digits: Int, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).rounded(rule: .toNearestOrAwayFromZero).grouping(.automatic).locale(locale))
    }
}
