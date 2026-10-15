//
// TimeRange.swift
//
// Time range options for charts
//

import Foundation

/// Time range options for charts
public enum TimeRange: String, CaseIterable, Identifiable {
    case fiveMinutes
    case oneHour
    
    public var id: String { rawValue }
    
    /// Display name for the time range
    public var displayName: String {
        switch self {
        case .fiveMinutes: return "5 min"
        case .oneHour: return "1 hour"
        }
    }
    
    /// Get the rolling window for the selected time range
    /// - Parameters:
    ///   - recorder: The series recorder
    ///   - series: The series to get window for
    /// - Returns: The rolling window
    public func getWindow(for recorder: LiveSeriesRecorder, series: LiveSeries) -> RollingWindow {
        let buffer = recorder.buffer(for: series)
        
        switch self {
        case .fiveMinutes:
            return buffer.getFiveMinuteWindow()
        case .oneHour:
            return buffer.getOneHourWindow()
        }
    }
}
