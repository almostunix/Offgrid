//
// AlarmStore.swift
//
// Manages Victron alarm state from MQTT topics (T-48).
// Only battery and vebus services are supported. Alarms are identified by
// "<service>/<instance>/<path after Alarms/">" and have levels: 0=OK, 1=warning, 2=alarm.
// Empty payloads clear the alarm. Changes to warning/alarm are logged.
//

import Foundation
import os

public enum AlarmLevel: Int, Comparable {
    case ok = 0
    case warning = 1
    case alarm = 2
    
    public static func < (lhs: AlarmLevel, rhs: AlarmLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct AlarmState: Identifiable, Equatable {
    public let id: String  // "<service>/<instance>/<path after Alarms/>"
    public let service: String
    public let instance: String
    public let name: String  // e.g., "LowSoc", "L1/Overload"
    public let level: AlarmLevel
    public let since: Date
}

public final class AlarmStore: ObservableObject {
    private let topicParser = TopicParser()
    private let now: () -> Date
    private let logger = Logger(subsystem: "com.victronenergy.cerbo", category: "AlarmStore")

    public private(set) var alarms: [String: AlarmState] = [:]
    public private(set) var log: [AlarmState] = []

    public var active: [AlarmState] {
        alarms.values.filter { $0.level > .ok }
            .sorted { a, b in
                if a.level != b.level { return a.level > b.level }
                if a.since != b.since { return a.since > b.since }
                return a.id < b.id   // deterministic order for equal level and time (dictionary order varies per run)
            }
    }

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public func handle(topic: String, payload: Data) {
        // Parse the topic
        guard let parsedTopic = topicParser.parseTopic(topic) else {
            return
        }

        // Only handle battery and vebus services
        guard parsedTopic.service == "battery" || parsedTopic.service == "vebus" else {
            return
        }

        // Only handle Alarms paths
        guard parsedTopic.path.first == "Alarms" else {
            return
        }

        // Build the alarm ID and name
        let alarmPath = parsedTopic.path.dropFirst()
        
        // Ignore deprecated Alarms/Alarm path
        if alarmPath.count == 1 && alarmPath.first == "Alarm" {
            return
        }
        
        let alarmId = "\(parsedTopic.service)/\(parsedTopic.instance)/\(alarmPath.joined(separator: "/"))"
        let alarmName = alarmPath.joined(separator: "/")

        // Parse the payload
        let payloadDict: [String: Any]
        if payload.isEmpty {
            // Empty payload means device gone - clear the alarm
            alarms.removeValue(forKey: alarmId)
            return
        }

        do {
            payloadDict = try JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] ?? [:]
        } catch {
            logger.error("Failed to parse payload for topic \(topic): \(error)")
            return
        }

        guard let value = payloadDict["value"] else {
            return
        }

        // Handle null values - clear the alarm
        if value is NSNull {
            alarms.removeValue(forKey: alarmId)
            return
        }

        // Only handle numeric values
        guard let levelInt = value as? Int, levelInt >= 0 && levelInt <= 2 else {
            return
        }

        let level = AlarmLevel(rawValue: levelInt) ?? .ok

        // Check if this is a new alarm or a change in level
        let currentAlarm = alarms[alarmId]
        let isNewOrChanged = currentAlarm == nil || currentAlarm?.level != level

        // Update or add the alarm
        let alarmState = AlarmState(
            id: alarmId,
            service: parsedTopic.service,
            instance: parsedTopic.instance,
            name: alarmName,
            level: level,
            since: now()
        )

        alarms[alarmId] = alarmState

        // Log if level changed to warning or alarm
        if isNewOrChanged && level > .ok {
            log.insert(alarmState, at: 0)
            if log.count > 200 {
                log.removeLast()
            }
        }
    }
}
