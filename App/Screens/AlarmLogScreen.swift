//
// AlarmLogScreen.swift
//
// Alarm log screen showing active alarms and alarm history.
//

import SwiftUI
import VictronKit

/// Alarm log screen showing active alarms and alarm history
public struct AlarmLogScreen: View {
    /// The alarm store providing alarm data
    @ObservedObject public var alarmStore: AlarmStore
    
    /// Filter for alarm level
    @State private var filterLevel: AlarmLevelFilter = .all
    
    /// Search text for filtering alarms
    @State private var searchText = ""
    
    // Initialize with alarm store
    public init(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
    }
    
    public var body: some View {
        List {
            // Active alarms section
            Section {
                if filteredActiveAlarms.isEmpty {
                    Text("No active alarms")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredActiveAlarms) { alarm in
                        AlarmRow(alarm: alarm)
                    }
                }
            } header: {
                HStack {
                    Text("Active Alarms")
                    
                    Spacer()
                    
                    // Active alarm badge
                    if !alarmStore.active.isEmpty {
                        Text("\("+" + String(alarmStore.active.count))")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
            }
            
            // Alarm log section
            Section("Alarm Log") {
                if alarmStore.log.isEmpty {
                    Text("No alarm events yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredLogEntries) { alarm in
                        AlarmLogRow(alarm: alarm)
                    }
                }
            }
        }
        .navigationTitle("Alarm Log")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                FilterMenu(selectedFilter: $filterLevel)
            }
        }
    }
    
    /// Filter for alarm level
    enum AlarmLevelFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case warnings = "Warnings"
        case alarms = "Alarms"
        
        var id: String { rawValue }
        
        var alarmLevel: AlarmLevel? {
            switch self {
            case .all: return nil
            case .warnings: return .warning
            case .alarms: return .alarm
            }
        }
    }
    
    /// Filter active alarms based on search and level filter
    private var filteredActiveAlarms: [AlarmState] {
        alarmStore.active.filter { alarm in
            // Apply level filter
            if let filterLevel = filterLevel.alarmLevel {
                guard alarm.level == filterLevel else { return false }
            }
            
            // Apply search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let serviceLower = alarm.service.lowercased()
                let nameLower = alarm.name.lowercased()
                return serviceLower.contains(searchLower) || nameLower.contains(searchLower)
            }
            
            return true
        }
    }
    
    /// Filter log entries based on search and level filter
    private var filteredLogEntries: [AlarmState] {
        alarmStore.log.filter { alarm in
            // Apply level filter
            if let filterLevel = filterLevel.alarmLevel {
                guard alarm.level == filterLevel else { return false }
            }
            
            // Apply search filter
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let serviceLower = alarm.service.lowercased()
                let nameLower = alarm.name.lowercased()
                return serviceLower.contains(searchLower) || nameLower.contains(searchLower)
            }
            
            return true
        }
    }
}

/// Filter menu for alarm levels
private struct FilterMenu: View {
    @Binding var selectedFilter: AlarmLogScreen.AlarmLevelFilter
    
    var body: some View {
        Menu {
            ForEach(AlarmLogScreen.AlarmLevelFilter.allCases) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    Label(filter.rawValue, systemImage: filter == selectedFilter ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

/// Alarm row for active alarms
private struct AlarmRow: View {
    let alarm: AlarmState
    
    var body: some View {
        HStack {
            // Alarm level indicator
            Circle()
                .fill(alarmLevelColor)
                .frame(width: 12, height: 12)
                
            VStack(alignment: .leading, spacing: 4) {
                // Device and alarm name
                Text("\("+" + alarm.service.capitalized + " " + alarm.instance + ": " + alarm.name)")
                    .font(.subheadline)
                    .bold()
                
                // Time since alarm
                Text("Since: " + TimeFormatter.formatTimeSince(alarm.since))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Alarm level badge
            Text(alarm.level.displayString)
                .font(.caption)
                .bold()
                .padding(4)
                .background(alarmLevelColor)
                .foregroundStyle(.white)
                .cornerRadius(6)
        }
        .padding(.vertical, 8)
    }
    
    private var alarmLevelColor: Color {
        switch alarm.level {
        case .alarm:
            return Color.red
        case .warning:
            return Color.orange
        case .ok:
            return Color.green
        }
    }
}

/// Alarm log row for historical alarms
private struct AlarmLogRow: View {
    let alarm: AlarmState
    
    var body: some View {
        HStack {
            // Alarm level indicator
            Circle()
                .fill(alarmLevelColor)
                .frame(width: 12, height: 12)
                
            VStack(alignment: .leading, spacing: 4) {
                // Device and alarm name
                Text("\("+" + alarm.service.capitalized + " " + alarm.instance + ": " + alarm.name)")
                    .font(.subheadline)
                
                // Time and level
                HStack {
                    Text(TimeFormatter.timeFormatter.string(from: alarm.since))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(alarm.level.displayString)
                        .font(.caption)
                        .bold()
                        .padding(4)
                        .background(alarmLevelColor)
                        .foregroundStyle(.white)
                        .cornerRadius(6)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var alarmLevelColor: Color {
        switch alarm.level {
        case .alarm:
            return Color.red
        case .warning:
            return Color.orange
        case .ok:
            return Color.green
        }
    }
}

// Preview for Xcode
#if DEBUG
struct AlarmLogScreen_Previews: PreviewProvider {
    static var previews: some View {
        let alarmStore = createSampleAlarmStore()
        
        Group {
            AlarmLogScreen(alarmStore: alarmStore)
                .previewDisplayName("Light Mode")
            
            AlarmLogScreen(alarmStore: alarmStore)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
    
    static func createSampleAlarmStore() -> AlarmStore {
        let alarmStore = AlarmStore(now: { Date() })
        
        // Add some sample alarms
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        var callCount = 0
        let store = AlarmStore(now: {
            callCount += 1
            return callCount == 1 ? twoHoursAgo : 
                   callCount == 2 ? oneHourAgo : now
        })
        
        let messages = [
            (topic: "N/c0ffee000001/battery/279/Alarms/LowSoc", payload: ["value": 1]),
            (topic: "N/c0ffee000001/vebus/276/Alarms/L1/Overload", payload: ["value": 2]),
            (topic: "N/c0ffee000001/vebus/276/Alarms/L1/HighTemperature", payload: ["value": 1]),
            (topic: "N/c0ffee000001/battery/279/Alarms/LowVoltage", payload: ["value": 2]),
            (topic: "N/c0ffee000001/battery/279/Alarms/LowSoc", payload: ["value": 0]),  // Cleared
            (topic: "N/c0ffee000001/battery/279/Alarms/HighTemperature", payload: ["value": 1])
        ]
        
        for messageTuple in messages {
            if let payloadData = try? JSONSerialization.data(withJSONObject: messageTuple.payload) {
                store.handle(topic: messageTuple.topic, payload: payloadData)
            }
        }
        
        return store
    }
}
#endif
