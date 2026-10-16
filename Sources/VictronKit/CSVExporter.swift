//
// CSVExporter.swift
//
// Exports chart data to CSV format
//

import Foundation

/// Exports data to CSV format
public enum CSVExporter {
    /// Date formatter for ISO 8601 timestamps (UTC, no fractional seconds)
    private static let iso8601DateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()

    /// A yyyy-MM-dd formatter for one time zone (made per call: DateFormatter isn't safe to share and mutate)
    private static func dateOnlyFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        return formatter
    }

    /// Number formatter for CSV values (en_US_POSIX locale, no grouping)
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    /// Escapes a CSV field value according to RFC 4180
    /// - Parameter value: The value to escape
    /// - Returns: The escaped value
    private static func escapeCSVField(_ value: String) -> String {
        // Check if the value contains any characters that need escaping
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            // Escape quotes by doubling them
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"" + escaped + "\""
        }
        return value
    }

    /// Formats a value for CSV output
    /// - Parameter value: The value to format
    /// - Returns: The formatted string
    private static func formatCSVValue(_ value: Any?) -> String {
        guard let value = value else {
            return ""
        }

        if let doubleValue = value as? Double {
            return numberFormatter.string(from: NSNumber(value: doubleValue)) ?? ""
        } else if let intValue = value as? Int {
            return numberFormatter.string(from: NSNumber(value: intValue)) ?? ""
        } else if let stringValue = value as? String {
            return escapeCSVField(stringValue)
        }

        return ""
    }

    /// Exports chart series data to CSV format
    /// - Parameter series: Array of series, each containing name, unit, and samples
    /// - Returns: CSV formatted string
    public static func csv(series: [(name: String, unit: String, samples: [Sample])]) -> String {
        guard !series.isEmpty else {
            return "time"   // header only
        }

        // Collect all unique timestamps and sort them
        var allTimestamps: [Date] = []
        for s in series {
            for sample in s.samples {
                allTimestamps.append(sample.timestamp)
            }
        }

        allTimestamps = Array(Set(allTimestamps)).sorted()   // one row per distinct time across all series

        // Create header
        var headerParts: [String] = ["time"]
        for s in series {
            headerParts.append(escapeCSVField(s.name + " (" + s.unit + ")"))   // names may contain commas or quotes
        }

        var lines: [String] = [headerParts.joined(separator: ",")]

        // Create data rows
        for timestamp in allTimestamps {
            var rowParts: [String] = [iso8601DateFormatter.string(from: timestamp)]

            for s in series {
                // Find sample for this timestamp
                if let sample = s.samples.first(where: { $0.timestamp == timestamp }) {
                    rowParts.append(formatCSVValue(sample.value))
                } else {
                    rowParts.append("")
                }
            }

            lines.append(rowParts.joined(separator: ","))
        }

        return lines.joined(separator: "\r\n")
    }

    /// Exports solar day records to CSV format
    /// - Parameter solarDays: Array of solar day records
    /// - Parameter timeZone: Time zone for formatting dates (default: .current)
    /// - Returns: CSV formatted string
    public static func csv(solarDays: [SolarDayRecord], timeZone: TimeZone = .current) -> String {
        // Sort by date
        let sortedDays = solarDays.sorted { $0.date < $1.date }

        // Create header
        let header = "date,yield_kWh,max_power_W,max_pv_voltage_V,time_in_bulk_min"
        var lines: [String] = [header]

        let dateFormatter = dateOnlyFormatter(timeZone: timeZone)

        // Create data rows
        for day in sortedDays {
            let dateString = dateFormatter.string(from: day.date)
            let yieldString = formatCSVValue(day.yield)
            let maxPowerString = formatCSVValue(day.maxPower)
            let maxPvVoltageString = formatCSVValue(day.maxPvVoltage)
            let timeInBulkString = formatCSVValue(day.timeInBulk)

            let row = dateString + "," + yieldString + "," + maxPowerString + "," + maxPvVoltageString + "," + timeInBulkString
            lines.append(row)
        }

        return lines.joined(separator: "\r\n")
    }
}
