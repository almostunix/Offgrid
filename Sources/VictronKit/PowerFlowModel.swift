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
        // DC side (Victron sign: battery power > 0 = charging). Solar charges the battery first and the rest goes to
        // the inverter; charging beyond what solar gives comes from the inverter (AC charging); a discharging battery
        // feeds the inverter. Flows under 1 W are not drawn.
        let pv = max(system.pvPower ?? 0, 0)
        let battery = system.batteryPower ?? 0
        let solarToBattery = min(pv, max(battery, 0))
        var flows: [PowerFlow] = []
        func add(_ from: PowerNode, _ to: PowerNode, _ watts: Double) {
            if watts > 1.0 { flows.append(PowerFlow(from: from, to: to, watts: watts)) }
        }
        add(.solar, .battery, solarToBattery)
        add(.solar, .inverter, pv - solarToBattery)
        add(.inverter, .battery, max(battery, 0) - solarToBattery)
        add(.battery, .inverter, max(-battery, 0))
        add(.inverter, .loads, system.acConsumptionTotal ?? 0)
        return flows
    }

    /// Net DC power into the inverter (pv - battery): > 0 inverting, < 0 charging from AC.
    public static func dcToInverter(from system: SystemModel) -> Double {
        max(system.pvPower ?? 0, 0) - (system.batteryPower ?? 0)
    }
}
