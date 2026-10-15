//
// EnergyHistoryModel.swift
//
// Helper functions for energy history charts
//

import Foundation

/// Energy history model helper
public enum EnergyHistoryModel {
    /// Convert solar day records to bar chart data
    /// - Parameters:
    ///   - records: Array of SolarDayRecord
    ///   - lastDays: Number of days to include (7 or 30)
    ///   - now: Current date for filtering
    /// - Returns: Array of (date, kWh) tuples for the specified period
    public static func bars(from records: [SolarDayRecord], lastDays: Int, now: Date) -> [(date: Date, kWh: Double)] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -(lastDays - 1), to: startOfToday)
        
        return records
            .compactMap { record -> (date: Date, kWh: Double)? in
                // Skip records with nil yield
                guard let yield = record.yield else { return nil }
                
                // Use the calendar date (start of day)
                let date = calendar.startOfDay(for: record.date)
                
                // Filter by date range
                guard let startDate = startDate else { return nil }
                if date < startDate || date > startOfToday {
                    return nil
                }
                return (date: date, kWh: yield)
            }
            .sorted { $0.date < $1.date }
    }
}
