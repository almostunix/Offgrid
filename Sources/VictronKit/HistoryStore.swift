//
// HistoryStore.swift
//
// Stores and parses history data from Cerbo GX devices.
//

import Foundation

/// Represents daily solar charger history data
public struct SolarDay: Equatable {
    /// Yield in kWh
    public var yield: Double?
    /// Maximum power in watts
    public var maxPower: Double?
    /// Maximum PV voltage in volts
    public var maxPvVoltage: Double?
    /// Time in bulk mode in minutes
    public var timeInBulk: Double?

    public init(yield: Double? = nil, maxPower: Double? = nil, maxPvVoltage: Double? = nil, timeInBulk: Double? = nil) {
        self.yield = yield
        self.maxPower = maxPower
        self.maxPvVoltage = maxPvVoltage
        self.timeInBulk = timeInBulk
    }
}

/// Stores history data from Cerbo GX devices
public final class HistoryStore {
    /// Solar charger daily history, keyed by instance ID
    public private(set) var solarDays: [String: [Int: SolarDay]] = [:]
    /// Battery history totals, keyed by instance ID
    public private(set) var batteryTotals: [String: [String: Double]] = [:]

    private let topicParser = TopicParser()

    public init() {}

    /// Handle an incoming MQTT message and update history data
    /// - Parameter topic: The MQTT topic
    /// - Parameter payload: The payload data
    public func handle(topic: String, payload: Data) {
        // Parse the topic
        let parts = topic.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 6, parts[0] == "N" else {
            return
        }

        _ = String(parts[1])  // portalId
        let service = String(parts[2])
        let instance = String(parts[3])

        // Parse the payload
        guard let payloadDict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any],
              let value = payloadDict["value"] else {
            return
        }

        let numericValue: Double?
        if let num = value as? Double {
            numericValue = num
        } else if let int = value as? Int {
            numericValue = Double(int)
        } else {
            return
        }

        // Handle solar charger daily history
        if service == "solarcharger" && parts[4] == "History" && parts[5] == "Daily" {
            guard parts.count >= 7 else { return }
            let dayIndex = Int(parts[6])
            let field = String(parts[7])

            if let dayIndex = dayIndex {
                var days = solarDays[instance] ?? [:]
                var day = days[dayIndex] ?? SolarDay()

                switch field {
                case "Yield":
                    day.yield = numericValue
                case "MaxPower":
                    day.maxPower = numericValue
                case "MaxPvVoltage":
                    day.maxPvVoltage = numericValue
                case "TimeInBulk":
                    day.timeInBulk = numericValue
                default:
                    break
                }

                days[dayIndex] = day
                solarDays[instance] = days
            }
        }
        // Handle battery history
        else if service == "battery" && parts[4] == "History" {
            guard parts.count >= 6 else { return }
            let field = String(parts[5])

            var totals = batteryTotals[instance] ?? [:]
            totals[field] = numericValue
            batteryTotals[instance] = totals
        }
    }
}