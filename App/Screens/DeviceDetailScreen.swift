//
// DeviceDetailScreen.swift
//
// Device detail pages for battery, solar charger, and inverter/charger
//

import SwiftUI
import VictronKit

/// Device detail screen
public struct DeviceDetailScreen: View {
    let device: DeviceRow
    @ObservedObject var store: LiveDataStore
    
    public init(device: DeviceRow, store: LiveDataStore) {
        self.device = device
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OffgridTheme.tileGap) {
                // Header
                DeviceHeader(device: device)
                    .padding(.bottom)
                
                // Device-specific details
                switch device.type {
                case .battery:
                    if let battery = store.batteries[device.id] {
                        BatteryDetailView(battery: battery)
                    }
                case .solarCharger:
                    if let solarCharger = store.solarChargers[device.id] {
                        SolarChargerDetailView(solarCharger: solarCharger)
                    }
                case .inverter:
                    if let inverter = store.inverters[device.id] {
                        InverterDetailView(inverter: inverter)
                    }
                }
            }
            .padding()
            .scrollContentBackground(.hidden)
            .background(OffgridTheme.background)
            .navigationTitle(device.productName ?? "Device")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}

/// Device header view
private struct DeviceHeader: View {
    let device: DeviceRow
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: deviceIcon(for: device.type))
                .font(.largeTitle)
                .foregroundStyle(deviceColor(for: device.type))
                .frame(width: 60, alignment: .center)
            
            VStack(alignment: .leading, spacing: 8) {
                // Device type
                Text(device.type.displayName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                // Status
                StatusIndicator(status: device.status)
                
                // Power/SOC
                if let power = device.power {
                    HStack(spacing: 16) {
                        if let soc = device.soc {
                            MetricView(label: "Power", value: String(format: "%.0f W", power))
                            MetricView(label: "SOC", value: String(format: "%.0f%%", soc))
                        } else {
                            MetricView(label: "Power", value: String(format: "%.0f W", power))
                        }
                    }
                } else if let soc = device.soc {
                    MetricView(label: "SOC", value: String(format: "%.0f%%", soc))
                }
            }
            
            Spacer()
        }
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

/// Battery detail view
private struct BatteryDetailView: View {
    let battery: BatteryModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main metrics
            HStack(spacing: 16) {
                if let voltage = battery.voltage {
                    MetricView(label: "Voltage", value: String(format: "%.1f V", voltage))
                }
                
                if let current = battery.current {
                    MetricView(label: "Current", value: String(format: "%.1f A", current))
                }
                
                if let power = battery.power {
                    MetricView(label: "Power", value: String(format: "%.0f W", power))
                }
            }
            
            Divider()
            
            // Additional metrics
            HStack(spacing: 16) {
                if let soc = battery.soc {
                    MetricView(label: "State of Charge", value: String(format: "%.0f%%", soc))
                }
                
                if let timeToGo = battery.timeToGo {
                    MetricView(label: "Time to Go", value: timeToGo > 86400 ? ">1 day" : formattedTime(timeToGo))
                }
                
                if let consumed = battery.consumedAmphours {
                    MetricView(label: "Consumed", value: String(format: "%.1f Ah", consumed))
                }
            }
        }
    }
    
    /// Format time in hours and minutes
    private func formattedTime(_ seconds: Double) -> String {
        // Return "–" for non-finite, negative, or excessively large values
        guard seconds.isFinite && seconds >= 0 else { return "–" }
        let maxDays = Double(100 * 24 * 3600)
        guard seconds <= maxDays else { return "–" }
        
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

/// Solar charger detail view
private struct SolarChargerDetailView: View {
    let solarCharger: SolarChargerModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main metrics
            HStack(spacing: 16) {
                if let pvVoltage = solarCharger.pvVoltage {
                    MetricView(label: "PV Voltage", value: String(format: "%.1f V", pvVoltage))
                }
                
                if let dcVoltage = solarCharger.dcVoltage {
                    MetricView(label: "DC Voltage", value: String(format: "%.1f V", dcVoltage))
                }
                
                if let dcCurrent = solarCharger.dcCurrent {
                    MetricView(label: "DC Current", value: String(format: "%.1f A", dcCurrent))
                }
            }
            
            Divider()
            
            // Additional metrics
            HStack(spacing: 16) {
                if let yieldPower = solarCharger.yieldPower {
                    MetricView(label: "Yield Power", value: String(format: "%.0f W", yieldPower))
                }
                
                if let state = solarCharger.state {
                    MetricView(label: "State", value: stateDisplay(state))
                }
            }
        }
    }
    
    /// Get state display text
    private func stateDisplay(_ state: Int) -> String {
        switch state {
        case 0: return "Off"
        case 2: return "Fault"
        case 3: return "Bulk"
        case 4: return "Absorption"
        case 5: return "Float"
        case 6: return "Storage"
        case 7: return "Equalize"
        case 252: return "External Control"
        default: return "Unknown"
        }
    }
}

/// Inverter detail view
private struct InverterDetailView: View {
    let inverter: InverterModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main metrics
            HStack(spacing: 16) {
                if let acInputPower = inverter.acInputPower {
                    MetricView(label: "AC Input", value: String(format: "%.0f W", acInputPower))
                }
                
                if let acOutputPower = inverter.acOutputPower {
                    MetricView(label: "AC Output", value: String(format: "%.0f W", acOutputPower))
                }
            }
            
            Divider()
            
            // Additional metrics
            HStack(spacing: 16) {
                if let mode = inverter.mode {
                    MetricView(label: "Mode", value: modeDisplay(mode))
                }
                
                if let state = inverter.state {
                    MetricView(label: "State", value: stateDisplay(state))
                }
            }
        }
    }
    
    /// Get mode display text
    private func modeDisplay(_ mode: Int) -> String {
        switch mode {
        case 1: return "Charger Only"
        case 2: return "Inverter Only"
        case 3: return "On"
        case 4: return "Off"
        default: return "Unknown"
        }
    }
    
    /// Get state display text
    private func stateDisplay(_ state: Int) -> String {
        switch state {
        case 0: return "Off"
        case 1: return "Low Power"
        case 2: return "Fault"
        case 3: return "Bulk"
        case 4: return "Absorption"
        case 5: return "Float"
        case 6: return "Storage"
        case 7: return "Equalize"
        case 8: return "Passthru"
        case 9: return "Inverting"
        case 10: return "Power Assist"
        case 11: return "Power Supply"
        case 244: return "Sustain"
        case 252: return "External Control"
        default: return "Unknown"
        }
    }
}

/// Metric view for displaying a single metric
private struct MetricView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(OffgridTheme.textSecondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(OffgridTheme.textPrimary)
        }
        .frame(minWidth: 100)
        .padding(12)
        .background(OffgridTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: OffgridTheme.tileRadius))
    }
}
