//
// LiveDataStore.swift
//
// Stores parsed MQTT topics and provides typed device models.
//

import Foundation
import Combine

/// Represents the system overview data
public struct SystemModel: Equatable {
    public let serial: String?
    public let batterySoc: Double?
    public let batteryPower: Double?
    public let pvPower: Double?
    public let acConsumptionOnOutput: Double?
    public let acConsumptionOnInput: Double?
    public let timeToGo: Double?
    
    /// Total AC consumption (sum of output and input)
    public var acConsumptionTotal: Double? {
        if let output = acConsumptionOnOutput, let input = acConsumptionOnInput {
            return output + input
        } else if let output = acConsumptionOnOutput {
            return output
        } else if let input = acConsumptionOnInput {
            return input
        }
        return nil
    }
    
    public init(serial: String? = nil, batterySoc: Double? = nil, batteryPower: Double? = nil, 
                pvPower: Double? = nil, acConsumptionOnOutput: Double? = nil, 
                acConsumptionOnInput: Double? = nil, timeToGo: Double? = nil) {
        self.serial = serial
        self.batterySoc = batterySoc
        self.batteryPower = batteryPower
        self.pvPower = pvPower
        self.acConsumptionOnOutput = acConsumptionOnOutput
        self.acConsumptionOnInput = acConsumptionOnInput
        self.timeToGo = timeToGo
    }
}

/// Represents battery monitor data
public struct BatteryModel: Equatable {
    public let productName: String?
    public let voltage: Double?
    public let current: Double?
    public let power: Double?
    public let soc: Double?
    public let timeToGo: Double?
    public let consumedAmphours: Double?
    
    public init(productName: String? = nil, voltage: Double? = nil, current: Double? = nil, 
                power: Double? = nil, soc: Double? = nil, timeToGo: Double? = nil, 
                consumedAmphours: Double? = nil) {
        self.productName = productName
        self.voltage = voltage
        self.current = current
        self.power = power
        self.soc = soc
        self.timeToGo = timeToGo
        self.consumedAmphours = consumedAmphours
    }
}

/// Represents solar charger data
public struct SolarChargerModel: Equatable {
    public let productName: String?
    public let pvVoltage: Double?
    public let yieldPower: Double?
    public let dcVoltage: Double?
    public let dcCurrent: Double?
    public let state: Int?
    
    public init(productName: String? = nil, pvVoltage: Double? = nil, yieldPower: Double? = nil, 
                dcVoltage: Double? = nil, dcCurrent: Double? = nil, state: Int? = nil) {
        self.productName = productName
        self.pvVoltage = pvVoltage
        self.yieldPower = yieldPower
        self.dcVoltage = dcVoltage
        self.dcCurrent = dcCurrent
        self.state = state
    }
}

/// Represents VE.Bus inverter/charger data
public struct InverterModel: Equatable {
    public let productName: String?
    public let acInputPower: Double?
    public let acOutputPower: Double?
    public let mode: Int?
    public let state: Int?
    
    public init(productName: String? = nil, acInputPower: Double? = nil, acOutputPower: Double? = nil, 
                mode: Int? = nil, state: Int? = nil) {
        self.productName = productName
        self.acInputPower = acInputPower
        self.acOutputPower = acOutputPower
        self.mode = mode
        self.state = state
    }
}

/// Represents a received MQTT topic with its raw value and timestamp
public struct ReceivedTopic: Identifiable, Equatable {
    /// Unique identifier
    public let id: String
    
    /// The full MQTT topic
    public let topic: String
    
    /// The raw payload value as string
    public let rawValue: String
    
    /// The timestamp when the topic was last updated
    public let timestamp: Date
    
    /// Initialize a new ReceivedTopic
    public init(topic: String, rawValue: String, timestamp: Date) {
        self.id = topic
        self.topic = topic
        self.rawValue = rawValue
        self.timestamp = timestamp
    }
}

/// Stores parsed MQTT messages and provides typed device models
public final class LiveDataStore: ObservableObject {
    /// The alarm store for managing Victron alarms
    public let alarmStore = AlarmStore()
    
    /// Maximum number of distinct topics to keep in memory
    public static let maxTopics = 5000
    
    /// Number of topics that have been dropped due to exceeding maxTopics
    public private(set) var droppedTopicCount = 0
    
    /// The detected portal ID
    public private(set) var portalId: String? {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// System overview model
    public private(set) var system: SystemModel = SystemModel() {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// Battery models by device ID
    public private(set) var batteries: [String: BatteryModel] = [:] {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// Solar charger models by device ID
    public private(set) var solarChargers: [String: SolarChargerModel] = [:] {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// Inverter models by device ID
    public private(set) var inverters: [String: InverterModel] = [:] {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// All received topics with their raw values and timestamps
    public private(set) var receivedTopics: [ReceivedTopic] = [] {
        didSet {
            objectWillChange.send()
        }
    }
    
    /// Publisher for changes
    public let objectWillChange = PassthroughSubject<Void, Never>()
    
    /// Private index for fast topic lookup
    private var topicIndex: [String: Int] = [:]
    
    /// Initialize a new LiveDataStore
    public init() {
        self.portalId = nil
    }

    /// Reset the store, clearing all data and preparing for a new connection
    public func reset() {
        portalId = nil
        system = SystemModel()
        batteries.removeAll()
        solarChargers.removeAll()
        inverters.removeAll()
        receivedTopics.removeAll()
        topicIndex.removeAll()
        droppedTopicCount = 0
        alarmStore.reset()
    }
    
    /// Handle an MQTT message with topic and payload
    /// - Parameters:
    ///   - topic: The MQTT topic
    ///   - payload: The MQTT payload (empty Data means device disappeared)
    public func handle(topic: String, payload: Data) {
        // Empty payload means device disappeared - remove it
        if payload.isEmpty {
            let topicParser = TopicParser()
            guard let parsedTopic = topicParser.parseTopic(topic) else {
                return
            }
            
            // Check portal ID filter if already set
            if let currentPortalId = portalId, currentPortalId != parsedTopic.portalId {
                return
            }
            alarmStore.handle(topic: topic, payload: payload)   // our installation only; clears that device's alarms

            // Only remove devices, not system
            if parsedTopic.service == "battery" {
                batteries.removeValue(forKey: parsedTopic.instance)
            } else if parsedTopic.service == "solarcharger" {
                solarChargers.removeValue(forKey: parsedTopic.instance)
            } else if parsedTopic.service == "vebus" {
                inverters.removeValue(forKey: parsedTopic.instance)
            }
            return
        }
        
        // Parse the JSON payload
        do {
            let json = try JSONSerialization.jsonObject(with: payload, options: [])
            guard let jsonDict = json as? [String: Any] else {
                return
            }
            
            // Check portal ID filter if already set
            let topicParser = TopicParser()
            guard let parsedTopic = topicParser.parseTopic(topic) else {
                return
            }
            
            if let currentPortalId = portalId, currentPortalId != parsedTopic.portalId {
                return
            }
            alarmStore.handle(topic: topic, payload: payload)   // our installation only

            // Parse the message and update
            guard let message = topicParser.parseMessage(topic: topic, payload: jsonDict) else {
                return
            }
            
            update(with: message)
        } catch {
            // Malformed JSON is ignored
            return
        }
    }
    
    /// Track a received topic with its raw value
    /// - Parameters:
    ///   - topic: The MQTT topic
    ///   - payload: The raw payload dictionary
    private func trackReceivedTopic(topic: String, payload: [String: Any]) {
        // Convert payload to string representation
        let rawValue: String
        if let value = payload["value"] {
            if let numberValue = value as? NSNumber {
                // Handle numbers without .0 for integers
                if numberValue.isEqual(to: numberValue.intValue as NSNumber) {
                    rawValue = "\(numberValue.intValue)"
                } else {
                    rawValue = "\(numberValue)"
                }
            } else {
                rawValue = "\(value)"
            }
        } else {
            rawValue = "{}"
        }
        
        let receivedTopic = ReceivedTopic(topic: topic, rawValue: rawValue, timestamp: Date())
        
        // Update or add the topic with bounds checking
        if let index = topicIndex[topic] {
            // Topic exists - update it
            receivedTopics[index] = receivedTopic
        } else {
            // Topic doesn't exist - add it if we haven't reached the limit
            if receivedTopics.count >= Self.maxTopics {
                // Drop this topic and increment counter
                droppedTopicCount += 1
                return
            }
            
            // Add new topic
            receivedTopics.append(receivedTopic)
            topicIndex[topic] = receivedTopics.count - 1
        }
    }
    
    /// Update the store with a parsed message
    /// - Parameter message: The parsed MQTT message
    public func update(with message: ParsedMessage) {
        // Track the received topic
        trackReceivedTopic(topic: "N/\(message.topic.portalId)/\(message.topic.service)/\(message.topic.instance)/\(message.topic.path.joined(separator: "/"))", 
                          payload: message.rawPayload)
        
        // Update portal ID if not already set
        if portalId == nil {
            portalId = message.topic.portalId
        }
        
        // Route message to appropriate service handler
        switch message.topic.service {
        case "system":
            updateSystem(with: message)
        case "battery":
            updateBattery(with: message)
        case "solarcharger":
            updateSolarCharger(with: message)
        case "vebus":
            updateInverter(with: message)
        default:
            // Ignore unknown services
            break
        }
    }
    
    /// Update system model with a message
    private func updateSystem(with message: ParsedMessage) {
        let instance = message.topic.instance
        let path = message.topic.path
        
        // System messages should have instance "0"
        guard instance == "0" else { return }
        
        if path.count == 1 && path[0] == "Serial" {
            if case .string(let value) = message.value {
                system = SystemModel(serial: value, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            } else if case .null = message.value {
                system = SystemModel(serial: nil, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "Battery", "Soc"] {
            if case .number(let value) = message.value {
                system = SystemModel(serial: system.serial, batterySoc: value, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            } else if case .null = message.value {
                system = SystemModel(serial: system.serial, batterySoc: nil, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "Battery", "Power"] {
            if case .number(let value) = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: value, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            } else if case .null = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: nil, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "Pv", "Power"] {
            if case .number(let value) = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: value, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            } else if case .null = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: nil, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            }
        } else if path.count == 4 && path[0...3] == ["Ac", "ConsumptionOnOutput", "L1", "Power"] {
            if case .number(let value) = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: value, acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            } else if case .null = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: nil, acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: system.timeToGo)
            }
        } else if path.count == 4 && path[0...3] == ["Ac", "ConsumptionOnInput", "L1", "Power"] {
            if case .number(let value) = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: value, timeToGo: system.timeToGo)
            } else if case .null = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: nil, timeToGo: system.timeToGo)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "Battery", "TimeToGo"] {
            if case .number(let value) = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: value)
            } else if case .null = message.value {
                system = SystemModel(serial: system.serial, batterySoc: system.batterySoc, 
                                    batteryPower: system.batteryPower, pvPower: system.pvPower, 
                                    acConsumptionOnOutput: system.acConsumptionOnOutput, 
                                    acConsumptionOnInput: system.acConsumptionOnInput, 
                                    timeToGo: nil)
            }
        }
    }
    
    /// Update battery model with a message
    private func updateBattery(with message: ParsedMessage) {
        let instance = message.topic.instance
        let path = message.topic.path
        
        // Get or create battery model for this instance
        var battery = batteries[instance] ?? BatteryModel()
        
        if path.count == 1 && path[0] == "ProductName" {
            if case .string(let value) = message.value {
                battery = BatteryModel(productName: value, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            } else if case .null = message.value {
                battery = BatteryModel(productName: nil, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "0", "Voltage"] {
            if case .number(let value) = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: value, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            } else if case .null = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: nil, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "0", "Current"] {
            if case .number(let value) = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: value, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            } else if case .null = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: nil, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "0", "Power"] {
            if case .number(let value) = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: value, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            } else if case .null = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: nil, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            }
        } else if path.count == 1 && path[0] == "Soc" {
            if case .number(let value) = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: value, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            } else if case .null = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: nil, timeToGo: battery.timeToGo, 
                                      consumedAmphours: battery.consumedAmphours)
            }
        } else if path.count == 1 && path[0] == "TimeToGo" {
            if case .number(let value) = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: value, 
                                      consumedAmphours: battery.consumedAmphours)
            } else if case .null = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: nil, 
                                      consumedAmphours: battery.consumedAmphours)
            }
        } else if path.count == 1 && path[0] == "ConsumedAmphours" {
            if case .number(let value) = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: value)
            } else if case .null = message.value {
                battery = BatteryModel(productName: battery.productName, voltage: battery.voltage, 
                                      current: battery.current, power: battery.power, 
                                      soc: battery.soc, timeToGo: battery.timeToGo, 
                                      consumedAmphours: nil)
            }
        }
        
        // Update the batteries dictionary
        batteries[instance] = battery
    }
    
    /// Update solar charger model with a message
    private func updateSolarCharger(with message: ParsedMessage) {
        let instance = message.topic.instance
        let path = message.topic.path
        
        // Get or create solar charger model for this instance
        var solarCharger = solarChargers[instance] ?? SolarChargerModel()
        
        if path.count == 1 && path[0] == "ProductName" {
            if case .string(let value) = message.value {
                solarCharger = SolarChargerModel(productName: value, pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            } else if case .null = message.value {
                solarCharger = SolarChargerModel(productName: nil, pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            }
        } else if path.count == 2 && path[0...1] == ["Pv", "V"] {
            if case .number(let value) = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: value, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            } else if case .null = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: nil, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            }
        } else if path.count == 2 && path[0...1] == ["Yield", "Power"] {
            if case .number(let value) = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: value, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            } else if case .null = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: nil, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "0", "Voltage"] {
            if case .number(let value) = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: value, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            } else if case .null = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: nil, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: solarCharger.state)
            }
        } else if path.count == 3 && path[0...2] == ["Dc", "0", "Current"] {
            if case .number(let value) = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: value, 
                                               state: solarCharger.state)
            } else if case .null = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: nil, 
                                               state: solarCharger.state)
            }
        } else if path.count == 1 && path[0] == "State" {
            if case .number(let value) = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: Int(value))
            } else if case .null = message.value {
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: nil)
            }
        }
        
        // Update the solar chargers dictionary
        solarChargers[instance] = solarCharger
    }
    
    /// Update inverter model with a message
    private func updateInverter(with message: ParsedMessage) {
        let instance = message.topic.instance
        let path = message.topic.path
        
        // Get or create inverter model for this instance
        var inverter = inverters[instance] ?? InverterModel()
        
        if path.count == 1 && path[0] == "ProductName" {
            if case .string(let value) = message.value {
                inverter = InverterModel(productName: value, acInputPower: inverter.acInputPower, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: inverter.mode, state: inverter.state)
            } else if case .null = message.value {
                inverter = InverterModel(productName: nil, acInputPower: inverter.acInputPower, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: inverter.mode, state: inverter.state)
            }
        } else if path.count == 4 && path[0...3] == ["Ac", "ActiveIn", "L1", "P"] {
            if case .number(let value) = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: value, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: inverter.mode, state: inverter.state)
            } else if case .null = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: nil, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: inverter.mode, state: inverter.state)
            }
        } else if path.count == 4 && path[0...3] == ["Ac", "Out", "L1", "P"] {
            if case .number(let value) = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: inverter.acInputPower, 
                                       acOutputPower: value, 
                                       mode: inverter.mode, state: inverter.state)
            } else if case .null = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: inverter.acInputPower, 
                                       acOutputPower: nil, 
                                       mode: inverter.mode, state: inverter.state)
            }
        } else if path.count == 1 && path[0] == "Mode" {
            if case .number(let value) = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: inverter.acInputPower, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: Int(value), state: inverter.state)
            } else if case .null = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: inverter.acInputPower, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: nil, state: inverter.state)
            }
        } else if path.count == 1 && path[0] == "State" {
            if case .number(let value) = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: inverter.acInputPower, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: inverter.mode, state: Int(value))
            } else if case .null = message.value {
                inverter = InverterModel(productName: inverter.productName, 
                                       acInputPower: inverter.acInputPower, 
                                       acOutputPower: inverter.acOutputPower, 
                                       mode: inverter.mode, state: nil)
            }
        }
        
        // Update the inverters dictionary
        inverters[instance] = inverter
    }
}
