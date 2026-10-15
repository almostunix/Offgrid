//
// PowerFlowModel.swift
//
// Models power flow between system components
//

import Foundation

/// Represents power flow nodes in the system
public enum PowerNode: String, Equatable {
    case solar
    case battery
    case inverter
    case loads
}

/// Represents a power flow between two nodes
public struct PowerFlow: Equatable {
    /// The source node of the flow
    public let from: PowerNode
    
    /// The destination node of the flow
    public let to: PowerNode
    
    /// The power in watts flowing from source to destination
    public let watts: Double
    
    /// Initialize a new power flow
    public init(from: PowerNode, to: PowerNode, watts: Double) {
        self.from = `from`
        self.to = to
        self.watts = watts
    }
}

/// Power flow calculation model
public enum PowerFlowModel {
    /// Calculate all power flows in the system
    public static func flows(from system: SystemModel) -> [PowerFlow] {
        var flows: [PowerFlow] = []
        
        // Solar to battery flow
        if let pvPower = system.pvPower, pvPower > 1.0 {
            flows.append(PowerFlow(from: .solar, to: .battery, watts: pvPower))
        }
        
        // Battery flow (charging or discharging)
        if let batteryPower = system.batteryPower, abs(batteryPower) > 1.0 {
            if batteryPower > 0 {
                // Battery is charging: flow from inverter to battery
                flows.append(PowerFlow(from: .inverter, to: .battery, watts: batteryPower))
            } else {
                // Battery is discharging: flow from battery to inverter
                flows.append(PowerFlow(from: .battery, to: .inverter, watts: abs(batteryPower)))
            }
        }
        
        // Inverter to loads flow
        if let acConsumption = system.acConsumptionTotal, acConsumption > 1.0 {
            flows.append(PowerFlow(from: .inverter, to: .loads, watts: acConsumption))
        }
        
        return flows
    }
}
