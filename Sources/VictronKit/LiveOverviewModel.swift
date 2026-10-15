//
// LiveOverviewModel.swift
//
// Helper model for LiveOverview screen formatting and calculations.
//

import Foundation

/// Charge state representation for display
public enum ChargeState: String, CaseIterable {
    case discharging = "Discharging"
    case charging = "Charging"
    case idle = "Idle"
    case unknown = "Unknown"
    
    /// Determine charge state based on battery power
    /// - Parameter batteryPower: Battery power in watts (positive = charging, negative = discharging)
    public static func from(batteryPower: Double?) -> ChargeState {
        guard let power = batteryPower else { return .unknown }
        if power > 0 {
            return .charging
        } else if power < 0 {
            return .discharging
        } else {
            return .idle
        }
    }
}

/// Device state representation for display
public enum DeviceState: String, CaseIterable {
    case off = "Off"
    case fault = "Fault"
    case bulk = "Bulk"
    case absorption = "Absorption"
    case float = "Float"
    case storage = "Storage"
    case equalize = "Equalize"
    case externalControl = "External Control"
    case lowPower = "Low Power"
    case passthru = "Passthru"
    case inverting = "Inverting"
    case powerAssist = "Power Assist"
    case powerSupply = "Power Supply"
    case sustain = "Sustain"
    case unknown = "Unknown"
    
    /// Create device state from raw state code
    public static func from(rawState: Int?) -> DeviceState {
        guard let state = rawState else { return .unknown }
        switch state {
        case 0: return .off
        case 1: return .lowPower
        case 2: return .fault
        case 3: return .bulk
        case 4: return .absorption
        case 5: return .float
        case 6: return .storage
        case 7: return .equalize
        case 8: return .passthru
        case 9: return .inverting
        case 10: return .powerAssist
        case 11: return .powerSupply
        case 244: return .sustain
        case 252: return .externalControl
        default: return .unknown
        }
    }
}

/// Helper functions for formatting power values
public struct PowerFormatter {
    /// Format power value for display
    /// - Parameter value: Power value in watts
    /// - Returns: Formatted string (e.g., "1.5 kW" or "1200 W")
    public static func formatPower(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1000 {
            return String(format: "%.1f kW", value / 1000)
        } else {
            return String(format: "%.0f W", value)
        }
    }
}

/// Helper functions for formatting time values
public struct TimeFormatter {
    /// Format time-to-go value for display
    /// - Parameter seconds: Time in seconds
    /// - Returns: Formatted string (e.g., "2:30h")
    public static func formatTimeToGo(_ seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%d:%02dh", hours, minutes)
    }
}

/// Helper functions for battery status calculations
public struct BatteryStatusHelper {
    /// Get battery SoC for display
    /// - Parameters:
    ///   - system: System model
    ///   - batteries: Batteries dictionary
    /// - Returns: State of charge percentage
    public static func batterySoc(from system: SystemModel, batteries: [String: BatteryModel]) -> Double? {
        return system.batterySoc ?? batteries.values.first?.soc
    }
    
    /// Get time-to-go for display
    /// - Parameters:
    ///   - system: System model
    ///   - batteries: Batteries dictionary
    /// - Returns: Time to go in seconds
    public static func timeToGo(from system: SystemModel, batteries: [String: BatteryModel]) -> Double? {
        return system.timeToGo ?? batteries.values.first?.timeToGo
    }
    
    /// Get charge state for display
    /// - Parameters:
    ///   - system: System model
    ///   - batteries: Batteries dictionary
    /// - Returns: Charge state enum
    public static func chargeState(from system: SystemModel, batteries: [String: BatteryModel]) -> ChargeState {
        return ChargeState.from(batteryPower: system.batteryPower ?? batteries.values.first?.power)
    }
}
