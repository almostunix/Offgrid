//
// DeviceListScreen.swift
//
// Device list screen showing all connected devices with their status
//

import SwiftUI
import VictronKit

/// Device list screen showing all connected devices
public struct DeviceListScreen: View {
    @ObservedObject var store: LiveDataStore
    @State private var selectedDevice: DeviceRow?
    
    public init(store: LiveDataStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            List(rows) { device in
                DeviceListRow(device: device)
                    .onTapGesture {
                        selectedDevice = device
                    }
            }
            .scrollContentBackground(.hidden)
            .background(OffgridTheme.background)
            .navigationTitle("Devices")
            .navigationDestination(item: $selectedDevice) { device in
                DeviceDetailScreen(device: device, store: store)
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView("No Devices", 
                                         systemImage: "powercord.batteryapple",
                                         description: Text("No devices connected"))
                }
            }
        }
    }
    
    private var rows: [DeviceRow] {
        return DeviceListModel.rows(from: store)
    }
}

/// Device list row view
public struct DeviceListRow: View {
    public let device: DeviceRow
    
    public var body: some View {
        HStack {
            // Device icon
            Image(systemName: deviceIcon(for: device.type))
                .font(.title2)
                .foregroundStyle(deviceColor(for: device.type))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                // Device name
                Text(device.productName ?? "Unknown Device")
                    .font(.headline)
                
                // Device type and status
                HStack {
                    Text(device.type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Status indicator
                    StatusIndicator(status: device.status)
                }
            }
            
            Spacer()
            
            // Power/SOC display
            if let power = device.power {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f W", power))
                        .font(.subheadline)
                        .monospacedDigit()
                    
                    if let soc = device.soc {
                        Text(String(format: "%.0f%%", soc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let soc = device.soc {
                Text(String(format: "%.0f%%", soc))
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
    }
    
    /// Get icon for device type
    private func deviceIcon(for type: DeviceType) -> String {
        switch type {
        case .battery: return "battery.100"
        case .solarCharger: return "sun.max"
        case .inverter: return "poweroutlet.type.f"
        }
    }
    
    /// Get color for device type
    private func deviceColor(for type: DeviceType) -> Color {
        switch type {
        case .battery: return OffgridTheme.battery
        case .solarCharger: return OffgridTheme.solar
        case .inverter: return OffgridTheme.grid
        }
    }
}

/// Status indicator view
public struct StatusIndicator: View {
    let status: String
    
    public var body: some View {
        Text(status)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: status))
            .foregroundStyle(statusTextColor(for: status))
            .cornerRadius(12)
    }
    
    /// Get color for status
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "good", "float", "storage": return OffgridTheme.battery
        case "fair", "bulk", "absorption": return OffgridTheme.warning
        case "low", "fault", "critical": return OffgridTheme.alarm
        default: return OffgridTheme.textSecondary
        }
    }
    
    /// Get text color for status
    private func statusTextColor(for status: String) -> Color {
        switch status.lowercased() {
        case "good", "float", "storage": return .white
        case "fair", "bulk", "absorption": return .white
        case "low", "fault", "critical": return .white
        default: return .primary
        }
    }
}
