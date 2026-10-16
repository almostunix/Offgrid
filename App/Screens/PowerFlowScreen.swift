//
// PowerFlowScreen.swift
//
// Animated power-flow diagram showing energy flow between solar, battery, inverter, and loads.
//

import SwiftUI
import VictronKit

/// Power flow screen showing animated energy flow between components
public struct PowerFlowScreen: View {
    /// The live data store providing real-time data
    @ObservedObject public var store: LiveDataStore
    
    // Initialize with data store
    public init(store: LiveDataStore) {
        self.store = store
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: OffgridTheme.tileGap) {
                // Power Flow Diagram
                PowerFlowDiagramView(store: store)
                    .padding()
                    .background(OffgridTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OffgridTheme.tileRadius))
                    .padding(.horizontal)
                
                // Power Values Summary
                PowerValuesSummaryView(store: store)
                    .padding()
                    .background(OffgridTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OffgridTheme.tileRadius))
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .scrollContentBackground(.hidden)
        .background(OffgridTheme.background)
        .navigationTitle("Power Flow")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Power flow diagram showing animated energy flow
private struct PowerFlowDiagramView: View {
    @ObservedObject var store: LiveDataStore
    
    var dcToInverter: Double {
        PowerFlowModel.dcToInverter(from: store.system)
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Solar panel at the top
            SolarComponentView(power: store.system.pvPower)
            
            // All solar power goes into the DC side (the battery row stands for it)
            if let pv = store.system.pvPower, pv > 1.0 {
                FlowIndicatorView(from: .solar, to: .battery, watts: pv)
            }

            // Battery in the middle (its own charge/discharge power is shown on it)
            BatteryComponentView(power: store.system.batteryPower)

            // Net DC power between the DC side and the inverter: down = inverting, up = charging from AC
            if dcToInverter > 1.0 {
                FlowIndicatorView(from: .battery, to: .inverter, watts: dcToInverter)
            } else if dcToInverter < -1.0 {
                FlowIndicatorView(from: .inverter, to: .battery, watts: -dcToInverter)
            }

            // Inverter at the bottom
            InverterComponentView(
                acInputPower: store.system.acInputPower,
                acOutputPower: store.system.acConsumptionOnOutput
            )
            
            // AC Loads label
            ACLoadsLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Solar panel component
private struct SolarComponentView: View {
    let power: Double?
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundStyle(OffgridTheme.solar)
            
            Text("Solar")
                .font(.headline)
                .foregroundColor(OffgridTheme.textPrimary)
            
            if let power = power {
                Text(PowerFormatter.formatPower(power))
                    .font(.subheadline)
                    .foregroundStyle(power > 0 ? OffgridTheme.solar : OffgridTheme.textSecondary)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(OffgridTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Solar panel")
        .accessibilityValue(power.map { "Producing \(PowerFormatter.formatPower($0))" } ?? "No data")
    }
}

/// Battery component
private struct BatteryComponentView: View {
    let power: Double?
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "battery.100")
                .font(.system(size: 48))
                .foregroundStyle(OffgridTheme.battery)
            
            Text("Battery")
                .font(.headline)
                .foregroundColor(OffgridTheme.textPrimary)
            
            if let power = power {
                Text(PowerFormatter.formatPower(power))
                    .font(.subheadline)
                    .foregroundStyle(power > 0 ? OffgridTheme.battery : OffgridTheme.warning)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(OffgridTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery")
        .accessibilityValue(power.map { 
            $0 > 0 ? "Charging at \(PowerFormatter.formatPower($0))" : "Discharging at \(PowerFormatter.formatPower(abs($0)))" 
        } ?? "No data")
    }
}

/// Inverter component
private struct InverterComponentView: View {
    let acInputPower: Double?
    let acOutputPower: Double?
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "poweroutlet.type.f")
                .font(.system(size: 48))
                .foregroundStyle(OffgridTheme.grid)
            
            Text("Inverter")
                .font(.headline)
                .foregroundColor(OffgridTheme.textPrimary)
            
            if let outputPower = acOutputPower {
                Text(PowerFormatter.formatPower(outputPower))
                    .font(.subheadline)
                    .foregroundStyle(outputPower > 0 ? OffgridTheme.grid : OffgridTheme.textSecondary)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(OffgridTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Inverter")
        .accessibilityValue(
            acOutputPower.map { "Output: \(PowerFormatter.formatPower($0))" } ?? "No data"
        )
    }
}

/// Flow indicator showing animated power flow
private struct FlowIndicatorView: View {
    let from: PowerNode
    let to: PowerNode
    let watts: Double

    /// Layout order top to bottom; an arrow points down when power flows to a node lower on screen.
    private static func rank(_ node: PowerNode) -> Int {
        switch node { case .solar: return 0; case .battery: return 1; case .inverter: return 2; case .loads: return 3 }
    }
    private var pointsDown: Bool { Self.rank(from) < Self.rank(to) }
    private var flowPower: Double { watts }
    private var flowColor: Color {
        switch from {
        case .solar: return OffgridTheme.solar
        case .battery: return OffgridTheme.battery
        case .inverter: return OffgridTheme.grid
        case .loads: return OffgridTheme.textPrimary
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Arrow indicating flow direction
            Image(systemName: pointsDown ? "arrow.down" : "arrow.up")
                .font(.title2)
                .foregroundStyle(flowColor)
            
            // Flow power label
            if flowPower > 0 {
                Text(PowerFormatter.formatPower(flowPower))
                    .font(.caption)
                    .foregroundStyle(flowColor)
            }
            
            // Animated flow line
            Rectangle()
                .fill(flowColor.opacity(0.3))
                .frame(width: 2, height: 40)
                .overlay {
                    Rectangle()
                        .fill(flowColor)
                        .frame(width: 2, height: 20)
                        .offset(y: pointsDown ? 20 : -20)
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: flowPower)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Power flow")
        .accessibilityValue("Flowing \(PowerFormatter.formatPower(flowPower)) \(pointsDown ? "downward" : "upward")")
    }
}

/// AC Loads label
private struct ACLoadsLabel: View {
    var body: some View {
        Text("AC Loads")
            .font(.headline)
            .foregroundStyle(OffgridTheme.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("AC Loads")
    }
}

/// Power values summary showing detailed numbers
private struct PowerValuesSummaryView: View {
    @ObservedObject var store: LiveDataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Power Values")
                .font(.headline)
                .foregroundColor(OffgridTheme.textPrimary)
            
            // Solar Input ("–" when the Cerbo hasn't sent it)
            let pvPowerText = MetricFormat.watts(store.system.pvPower)
            MetricRow(icon: "sun.max", label: "Solar Input", value: pvPowerText.value, unit: pvPowerText.unit)

            // Battery Power ("–" when the Cerbo hasn't sent it)
            let batteryPowerText = MetricFormat.watts(store.system.batteryPower)
            MetricRow(icon: "battery.100", label: "Battery Power", value: batteryPowerText.value, unit: batteryPowerText.unit)

            // AC Input ("–" when the Cerbo hasn't sent it)
            let acInputPowerText = MetricFormat.watts(store.system.acInputPower)
            MetricRow(icon: "poweroutlet.type.f", label: "AC Input", value: acInputPowerText.value, unit: acInputPowerText.unit)

            // AC Output ("–" when the Cerbo hasn't sent it)
            let acConsumptionOnOutputText = MetricFormat.watts(store.system.acConsumptionOnOutput)
            MetricRow(icon: "house", label: "AC Output", value: acConsumptionOnOutputText.value, unit: acConsumptionOnOutputText.unit)

            // Total AC Consumption ("–" when the Cerbo hasn't sent it)
            let acConsumptionTotalText = MetricFormat.watts(store.system.acConsumptionTotal)
            MetricRow(icon: "bolt", label: "Total AC Consumption", value: acConsumptionTotalText.value, unit: acConsumptionTotalText.unit)
        }
    }
}



// Preview for Xcode
#if DEBUG
struct PowerFlowScreen_Previews: PreviewProvider {
    static var previews: some View {
        let store = populateStoreWithSampleData()
        
        Group {
            PowerFlowScreen(store: store)
                .previewDisplayName("Light Mode")
            PowerFlowScreen(store: store)
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
