//
// DeviceListModel.swift
//
// Device list model for building device rows from LiveDataStore
//

import Foundation

/// Device type enum for the device list
public enum DeviceType: String, CaseIterable {
    case battery
    case solarCharger
    case inverter
    
    /// Human-readable name
    public var displayName: String {
        switch self {
        case .battery: return "Battery"
        case .solarCharger: return "Solar Charger"
        case .inverter: return "Inverter/Charger"
        }
    }
}

/// Represents a device in the list
public struct DeviceRow: Identifiable, Equatable, Hashable {
    public let id: String
    public let type: DeviceType
    public let productName: String?
    public let status: String
    public let power: Double?
    public let soc: Double?
    
    public init(id: String, type: DeviceType, productName: String?, status: String, power: Double? = nil, soc: Double? = nil) {
        self.id = id
        self.type = type
        self.productName = productName
        self.status = status
        self.power = power
        self.soc = soc
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
    }
}

/// Device list model for building device rows from LiveDataStore
public enum DeviceListModel {
    /// Get device by ID
    public static func row(id: String, from store: LiveDataStore) -> DeviceRow? {
        return rows(from: store).first { $0.id == id }
    }
    
    /// Get all devices as a flat list
    public static func rows(from store: LiveDataStore) -> [DeviceRow] {
        var devices: [DeviceRow] = []
        
        // Add batteries
        for (id, battery) in store.batteries {
            let status = batteryStatus(for: battery)
            let soc = battery.soc
            let power = battery.power
            
            devices.append(DeviceRow(
                id: id,
                type: .battery,
                productName: battery.productName,
                status: status,
                power: power,
                soc: soc
            ))
        }
        
        // Add solar chargers
        for (id, solarCharger) in store.solarChargers {
            let status = solarChargerStatus(for: solarCharger)
            let power = solarCharger.yieldPower
            
            devices.append(DeviceRow(
                id: id,
                type: .solarCharger,
                productName: solarCharger.productName,
                status: status,
                power: power
            ))
        }
        
        // Add inverters
        for (id, inverter) in store.inverters {
            let status = inverterStatus(for: inverter)
            let power = inverter.acOutputPower
            
            devices.append(DeviceRow(
                id: id,
                type: .inverter,
                productName: inverter.productName,
                status: status,
                power: power
            ))
        }
        
        return devices
    }
    
    /// Get battery status text
    private static func batteryStatus(for battery: BatteryModel) -> String {
        guard let soc = battery.soc else { return "Unknown" }
        
        if soc >= 80 {
            return "Good"
        } else if soc >= 50 {
            return "Fair"
        } else if soc >= 20 {
            return "Low"
        } else {
            return "Critical"
        }
    }
    
    /// Get solar charger status text
    private static func solarChargerStatus(for solarCharger: SolarChargerModel) -> String {
        guard let state = solarCharger.state else { return "Unknown" }
        
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
    
    /// Get inverter status text
    private static func inverterStatus(for inverter: InverterModel) -> String {
        guard let state = inverter.state else { return "Unknown" }
        
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
