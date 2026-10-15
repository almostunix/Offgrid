//
// HistoryCache.swift
//
// Persistent history cache using SwiftData for offline access
//

import Foundation
import os
import SwiftData

/// A single day of solar charger history stored in SwiftData
@Model
public final class SolarDayRecord {
    /// The portal ID (Cerbo GX device identifier)
    public var portalId: String
    /// The instance ID of the solar charger
    public var instance: String
    /// The day offset from when it was fetched (0 = today when fetched)
    public var dayOffsetFetched: Int
    /// The calendar day (start of day)
    public var date: Date
    /// Yield in kWh
    public var yield: Double?
    /// Maximum power in watts
    public var maxPower: Double?
    /// Maximum PV voltage in volts
    public var maxPvVoltage: Double?
    /// Time in bulk mode in minutes
    public var timeInBulk: Double?

    /// Unique identifier for this record
    init(portalId: String, instance: String, dayOffsetFetched: Int, date: Date, yield: Double? = nil, maxPower: Double? = nil, maxPvVoltage: Double? = nil, timeInBulk: Double? = nil) {
        self.portalId = portalId
        self.instance = instance
        self.dayOffsetFetched = dayOffsetFetched
        self.date = date
        self.yield = yield
        self.maxPower = maxPower
        self.maxPvVoltage = maxPvVoltage
        self.timeInBulk = timeInBulk
    }

    /// Unique key for the record
    func uniqueKey() -> String {
        return "\(portalId)_\(instance)_\(date.timeIntervalSince1970)"
    }
}

/// Persistent cache for history data using SwiftData
private let historyCacheLog = Logger(subsystem: "com.almostunix.cerbo", category: "HistoryCache")

public final class HistoryCache: ObservableObject {
    private let container: ModelContainer
    private let context: ModelContext

    /// Initialize the HistoryCache
    /// - Parameter inMemory: If true, uses an in-memory container for testing
    public init(inMemory: Bool = false) {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try! ModelContainer(for: SolarDayRecord.self, configurations: config)
        context = ModelContext(container)
    }

    /// Store history data from a HistoryStore
    /// - Parameter store: The HistoryStore containing the data
    /// - Parameter portalId: The portal ID
    /// - Parameter fetchedAt: The date when the data was fetched
    public func store(_ store: HistoryStore, portalId: String, fetchedAt: Date) {
        // Get all instances from the store
        for (instance, days) in store.solarDays {
            // Process each day
            for (dayOffset, solarDay) in days {
                // Calculate the calendar day (start of day)
                let calendar = Calendar.current
                let startOfFetchedDay = calendar.startOfDay(for: fetchedAt)
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: startOfFetchedDay) else {
                    continue
                }

                // Check if a record with this unique key already exists
                let predicate = #Predicate<SolarDayRecord> { record in
                    record.portalId == portalId &&
                    record.instance == instance &&
                    record.date == date
                }

                let descriptor = FetchDescriptor<SolarDayRecord>(predicate: predicate)
                do {
                    let existingRecords = try context.fetch(descriptor)
                    
                    if let existingRecord = existingRecords.first {
                        // Update existing record
                        existingRecord.yield = solarDay.yield
                        existingRecord.maxPower = solarDay.maxPower
                        existingRecord.maxPvVoltage = solarDay.maxPvVoltage
                        existingRecord.timeInBulk = solarDay.timeInBulk
                    } else {
                        // Create new record
                        let record = SolarDayRecord(
                            portalId: portalId,
                            instance: instance,
                            dayOffsetFetched: dayOffset,
                            date: date,
                            yield: solarDay.yield,
                            maxPower: solarDay.maxPower,
                            maxPvVoltage: solarDay.maxPvVoltage,
                            timeInBulk: solarDay.timeInBulk
                        )
                        context.insert(record)
                    }
                } catch {
                    historyCacheLog.error("Error fetching or saving SolarDayRecord: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // Save changes
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            historyCacheLog.error("Error saving context: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Get all distinct instance IDs for a given portal
    /// - Parameter portalId: The portal ID
    /// - Returns: Array of distinct instance IDs sorted alphabetically
    public func instances(portalId: String) -> [String] {
        let predicate = #Predicate<SolarDayRecord> { record in
            record.portalId == portalId
        }

        let descriptor = FetchDescriptor<SolarDayRecord>(predicate: predicate)
        do {
            let records = try context.fetch(descriptor)
            let instances = Set(records.map { $0.instance })
            return instances.sorted()
        } catch {
            historyCacheLog.error("Error fetching instances: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Get all solar day records for a given portal and instance
    /// - Parameter portalId: The portal ID
    /// - Parameter instance: The instance ID
    /// - Returns: Array of SolarDayRecord sorted by date
    public func days(portalId: String, instance: String) -> [SolarDayRecord] {
        let predicate = #Predicate<SolarDayRecord> { record in
            record.portalId == portalId && record.instance == instance
        }

        let sort = SortDescriptor(\SolarDayRecord.date)
        let descriptor = FetchDescriptor<SolarDayRecord>(predicate: predicate, sortBy: [sort])

        do {
            return try context.fetch(descriptor)
        } catch {
            historyCacheLog.error("Error fetching SolarDayRecords: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}


