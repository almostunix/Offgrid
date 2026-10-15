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
            VStack(spacing: 24) {
                // Power Flow Diagram
                PowerFlowDiagramView(store: store)
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                
                // Power Values Summary
                PowerValuesSummaryView(store: store)
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 3)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
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
                FlowIndicatorView(from: .solar, to: .battery, watts: pv, color: .yellow)
            }

            // Battery in the middle (its own charge/discharge power is shown on it)
            BatteryComponentView(power: store.system.batteryPower)

            // Net DC power between the DC side and the inverter: down = inverting, up = charging from AC
            if dcToInverter > 1.0 {
                FlowIndicatorView(from: .battery, to: .inverter, watts: dcToInverter, color: .blue)
            } else if dcToInverter < -1.0 {
                FlowIndicatorView(from: .inverter, to: .battery, watts: -dcToInverter, color: .green)
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
                .foregroundStyle(.yellow)
            
            Text("Solar")
                .font(.headline)
            
            if let power = power {
                Text(PowerFormatter.formatPower(power))
                    .font(.subheadline)
                    .foregroundStyle(power > 0 ? .yellow : .secondary)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.blue)
            
            Text("Battery")
                .font(.headline)
            
            if let power = power {
                Text(PowerFormatter.formatPower(power))
                    .font(.subheadline)
                    .foregroundStyle(power > 0 ? .green : .orange)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.green)
            
            Text("Inverter")
                .font(.headline)
            
            if let outputPower = acOutputPower {
                Text(PowerFormatter.formatPower(outputPower))
                    .font(.subheadline)
                    .foregroundStyle(outputPower > 0 ? .green : .secondary)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
    let color: Color

    /// Layout order top to bottom; an arrow points down when power flows to a node lower on screen.
    private static func rank(_ node: PowerNode) -> Int {
        switch node { case .solar: return 0; case .battery: return 1; case .inverter: return 2; case .loads: return 3 }
    }
    private var pointsDown: Bool { Self.rank(from) < Self.rank(to) }
    private var flowPower: Double { watts }

    var body: some View {
        VStack(spacing: 8) {
            // Arrow indicating flow direction
            Image(systemName: pointsDown ? "arrow.down" : "arrow.up")
                .font(.title2)
                .foregroundStyle(color)
            
            // Flow power label
            if flowPower > 0 {
                Text(PowerFormatter.formatPower(flowPower))
                    .font(.caption)
                    .foregroundStyle(color)
            }
            
            // Animated flow line
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(width: 2, height: 40)
                .overlay {
                    Rectangle()
                        .fill(color)
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
            .foregroundStyle(.secondary)
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
            
            // Solar Input
            PowerValueRow(title: "Solar Input", value: store.system.pvPower, color: .yellow)
            
            // Battery Power
            PowerValueRow(title: "Battery Power", value: store.system.batteryPower, color: .blue)
            
            // AC Input
            PowerValueRow(title: "AC Input", value: store.system.acInputPower, color: .green)
            
            // AC Output
            PowerValueRow(title: "AC Output", value: store.system.acConsumptionOnOutput, color: .cyan)
            
            // Total AC Consumption
            PowerValueRow(title: "Total AC Consumption", value: store.system.acConsumptionTotal, color: .purple)
        }
    }
}

/// Individual power value row
private struct PowerValueRow: View {
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
