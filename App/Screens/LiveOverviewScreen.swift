//
// LiveOverviewScreen.swift
//
// Live overview screen showing watts in and out, battery SoC, time-to-go and charge state.
// Supports Dark mode and Dynamic Type.
//

import SwiftUI
import VictronKit

/// Live overview screen showing real-time Cerbo GX data
public struct LiveOverviewScreen: View {
    /// The live data store providing real-time data
    @ObservedObject public var store: LiveDataStore
    
    // Initialize with data store
    public init(store: LiveDataStore) {
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Battery Status Section
                BatteryStatusView(store: store)
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                
                // Power Flow Section
                PowerFlowView(store: store)
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                
                // Device States Section
                DeviceStatesView(store: store)
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 3)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Live Overview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Battery status view showing SoC, time-to-go, and charge state
private struct BatteryStatusView: View {
    @ObservedObject var store: LiveDataStore
    
    var batterySoc: Double? {
        return BatteryStatusHelper.batterySoc(from: store.system, batteries: store.batteries)
    }
    
    var timeToGo: Double? {
        return BatteryStatusHelper.timeToGo(from: store.system, batteries: store.batteries)
    }
    
    var chargeState: ChargeState {
        return BatteryStatusHelper.chargeState(from: store.system, batteries: store.batteries)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Battery Status")
                .font(.headline)
            
            HStack(spacing: 32) {
                // SoC
                VStack(alignment: .leading, spacing: 8) {
                    Text("State of Charge")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let soc = batterySoc {
                        Text(String(format: "%.1f%%", soc))
                            .font(.system(size: 48, weight: .bold))
                    } else {
                        Text("-")
                            .font(.system(size: 48, weight: .bold))
                    }
                }
                
                // Time to Go
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time to Go")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let timeToGo = timeToGo, timeToGo > 0 {
                        Text(TimeFormatter.formatTimeToGo(timeToGo))
                            .font(.system(size: 48, weight: .bold))
                    } else {
                        Text("-")
                            .font(.system(size: 48, weight: .bold))
                    }
                }
            }
            
            // Charge State
            HStack {
                Text("Charge State")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(chargeState.rawValue)
                    .font(.body)
                    .padding(8)
                    .background(chargeStateBackground)
                    .foregroundStyle(chargeStateForeground)
                    .cornerRadius(8)
            }
        }
    }
    
    var chargeStateBackground: Color {
        switch chargeState {
        case .charging:
            return Color.green
        case .discharging:
            return Color.orange
        case .idle:
            return Color.gray
        case .unknown:
            return Color.gray
        }
    }
    
    var chargeStateForeground: Color {
        switch chargeState {
        case .charging, .discharging, .idle:
            return Color.white
        case .unknown:
            return Color.primary
        }
    }
}

/// Power flow view showing watts in and out
private struct PowerFlowView: View {
    @ObservedObject var store: LiveDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Power Flow")
                .font(.headline)
            
            // Solar Input
            PowerItemView(title: "Solar Input", value: store.system.pvPower, color: .yellow)
            
            // Battery Power
            PowerItemView(title: "Battery", value: store.system.batteryPower, color: .purple)
            
            // AC Consumption
            PowerItemView(title: "AC Consumption", value: store.system.acConsumptionTotal, color: .blue)
            
            // AC Input
            PowerItemView(title: "AC Input", value: store.system.acConsumptionOnInput, color: .green)
            
            // AC Output
            PowerItemView(title: "AC Output", value: store.system.acConsumptionOnOutput, color: .cyan)
        }
    }
}

/// Individual power item view
private struct PowerItemView: View {
    let title: String
    let value: Double?
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let value = value {
                Text(PowerFormatter.formatPower(value))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(valueColor(value))
            } else {
                Text("-")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    func valueColor(_ value: Double) -> Color {
        if value > 0 {
            return color
        } else if value < 0 {
            return color.opacity(0.7)
        } else {
            return .secondary
        }
    }
}

/// Device states view showing battery, solar charger, and inverter states
private struct DeviceStatesView: View {
    @ObservedObject var store: LiveDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device States")
                .font(.headline)
            
            // Battery State
            if let battery = store.batteries.values.first {
                DeviceStateItemView(title: "Battery", state: DeviceState.from(rawState: nil), 
                                   productName: battery.productName)
            } else {
                DeviceStateItemView(title: "Battery", state: .unknown, productName: nil)
            }
            
            // Solar Charger States
            ForEach(Array(store.solarChargers.values.enumerated()), id: \.offset) { index, charger in
                DeviceStateItemView(title: "Solar Charger", state: DeviceState.from(rawState: charger.state), 
                                   productName: charger.productName)
            }
            
            // Inverter States
            ForEach(Array(store.inverters.values.enumerated()), id: \.offset) { index, inverter in
                DeviceStateItemView(title: "Inverter", state: DeviceState.from(rawState: inverter.state), 
                                   productName: inverter.productName)
            }
        }
    }
}

/// Individual device state item view
private struct DeviceStateItemView: View {
    let title: String
    let state: DeviceState
    let productName: String?
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(state.rawValue)
                .font(.body)
                .padding(6)
                .background(stateBackground)
                .foregroundStyle(stateForeground)
                .cornerRadius(6)
            
            if let productName = productName {
                Text(productName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    var stateBackground: Color {
        switch state {
        case .fault:
            return Color.red
        case .bulk, .absorption, .float:
            return Color.green
        case .off:
            return Color.gray
        case .externalControl, .inverting, .powerAssist, .powerSupply, .sustain:
            return Color.blue
        case .lowPower, .passthru, .storage, .equalize:
            return Color.orange
        case .unknown:
            return Color.gray
        }
    }
    
    var stateForeground: Color {
        switch state {
        case .fault, .bulk, .absorption, .float, .off, 
             .externalControl, .inverting, .powerAssist, .powerSupply, .sustain:
            return Color.white
        case .lowPower, .passthru, .storage, .equalize, .unknown:
            return Color.primary
        }
    }
}

// Preview for Xcode
#if DEBUG
struct LiveOverviewScreen_Previews: PreviewProvider {
    static var previews: some View {
        let store = populateStoreWithSampleData()
        
        Group {
            LiveOverviewScreen(store: store)
                .previewDisplayName("Light Mode")
            LiveOverviewScreen(store: store)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
    
    static func populateStoreWithSampleData() -> LiveDataStore {
        let store = LiveDataStore()
        let topicParser = TopicParser()
        let messages = [
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/Power", payload: ["value": -1250.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Pv/Power", payload: ["value": 1500.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnOutput/L1/Power", payload: ["value": 851.0]),
            (topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: ["value": 300.0]),
            (topic: "N/c0ffee000001/system/0/Dc/Battery/TimeToGo", payload: ["value": 45230.0]),
            (topic: "N/c0ffee000001/battery/279/ProductName", payload: ["value": "SmartShunt 500A"]),
            (topic: "N/c0ffee000001/battery/279/Soc", payload: ["value": 78.5]),
            (topic: "N/c0ffee000001/solarcharger/278/ProductName", payload: ["value": "MPPT 150/70"]),
            (topic: "N/c0ffee000001/solarcharger/278/State", payload: ["value": 5]),
            (topic: "N/c0ffee000001/vebus/276/ProductName", payload: ["value": "MultiPlus-II 48/5000"]),
            (topic: "N/c0ffee000001/vebus/276/State", payload: ["value": 9])
        ]
        
        for messageTuple in messages {
            if let message = topicParser.parseMessage(topic: messageTuple.topic, payload: messageTuple.payload) {
                store.update(with: message)
            }
        }
        
        return store
    }
}
#endif
