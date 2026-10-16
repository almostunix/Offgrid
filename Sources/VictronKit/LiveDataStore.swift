//
// LiveDataStore.swift
//
// Stores parsed MQTT topics and provides typed device models.
//

import Foundation
import Combine

/// Represents the system overview data
public struct SystemModel: Equatable {
    public internal(set) var serial: String?
    public internal(set) var batterySoc: Double?
    public internal(set) var batteryPower: Double?
    public internal(set) var pvPower: Double?
    /// Loads on the inverter's AC output (sum of L1-L3).
    public internal(set) var acConsumptionOnOutput: Double?
    /// Loads on the AC input side (sum of L1-L3). Not the input power itself: that is acGridPower / acGensetPower.
    public internal(set) var acConsumptionOnInput: Double?
    /// Power from the grid, system Ac/Grid/Lx/Power summed (dbus-systemcalc-py; negative = feeding in).
    public internal(set) var acGridPower: Double?
    /// Power from a generator, system Ac/Genset/Lx/Power summed (dbus-systemcalc-py).
    public internal(set) var acGensetPower: Double?
    public internal(set) var timeToGo: Double?

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

    /// Power coming in on the AC input: grid + generator (nil when neither is known).
    public var acInputPower: Double? {
        switch (acGridPower, acGensetPower) {
        case (nil, nil): return nil
        case let (grid, genset): return (grid ?? 0) + (genset ?? 0)
        }
    }

    public init(serial: String? = nil, batterySoc: Double? = nil, batteryPower: Double? = nil,
                pvPower: Double? = nil, acConsumptionOnOutput: Double? = nil,
                acConsumptionOnInput: Double? = nil, timeToGo: Double? = nil,
                acGridPower: Double? = nil, acGensetPower: Double? = nil) {
        self.serial = serial
        self.batterySoc = batterySoc
        self.batteryPower = batteryPower
        self.pvPower = pvPower
        self.acConsumptionOnOutput = acConsumptionOnOutput
        self.acConsumptionOnInput = acConsumptionOnInput
        self.acGridPower = acGridPower
        self.acGensetPower = acGensetPower
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
    public internal(set) var productName: String?
    /// AC input power (sum of Ac/ActiveIn/L1-L3/P)
    public internal(set) var acInputPower: Double?
    /// AC output power (sum of Ac/Out/L1-L3/P)
    public internal(set) var acOutputPower: Double?
    public internal(set) var mode: Int?
    public internal(set) var state: Int?
    
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
    
    /// Per-phase AC values, keyed by "<service>/<instance>/<group>/<phase>", so the totals sum L1-L3.
    private var phaseValues: [String: Double] = [:]

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
        phaseValues.removeAll()
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
        // System messages should have instance "0"
        guard message.topic.instance == "0" else { return }
        let path = message.topic.path
        var model = system
        switch path.joined(separator: "/") {
        case "Serial":
            if case .string(let value) = message.value { model.serial = value }
            else if case .null = message.value { model.serial = nil }
        case "Dc/Battery/Soc": model.batterySoc = Self.number(message.value, else: model.batterySoc)
        case "Dc/Battery/Power": model.batteryPower = Self.number(message.value, else: model.batteryPower)
        case "Dc/Pv/Power": model.pvPower = Self.number(message.value, else: model.pvPower)
        case "Dc/Battery/TimeToGo": model.timeToGo = Self.number(message.value, else: model.timeToGo)
        default:
            // Ac/<group>/L1|L2|L3/Power (dbus-systemcalc-py)
            guard path.count == 4, path[0] == "Ac", path[3] == "Power",
                  let total = phaseSum(message, key: "system/0/" + path[1], phase: path[2]) else { return }
            switch path[1] {
            case "ConsumptionOnOutput": model.acConsumptionOnOutput = total
            case "ConsumptionOnInput": model.acConsumptionOnInput = total
            case "Grid": model.acGridPower = total
            case "Genset": model.acGensetPower = total
            default: return
            }
        }
        if model != system { system = model }
    }

    /// A number keeps the value, null clears it, anything else leaves `current`.
    private static func number(_ value: PayloadValue, else current: Double?) -> Double? {
        switch value {
        case .number(let v): return v
        case .null: return nil
        default: return current
        }
    }

    /// An Int field from a number: nil for null, `current` for values that aren't a whole number in range.
    private static func integer(_ value: PayloadValue, else current: Int?) -> Int? {
        switch value {
        case .number(let v): return v.isFinite ? (Int(exactly: v.rounded()) ?? current) : current
        case .null: return nil
        default: return current
        }
    }

    /// Records one phase (L1-L3) of a group and returns the group's sum (nil when no phase has a value).
    /// Returns .none (ignore the message) for an unknown phase or a non-number, non-null value.
    private func phaseSum(_ message: ParsedMessage, key: String, phase: String) -> Double?? {
        guard ["L1", "L2", "L3"].contains(phase) else { return nil }
        switch message.value {
        case .number(let v): phaseValues[key + "/" + phase] = v
        case .null: phaseValues[key + "/" + phase] = nil
        default: return nil
        }
        let values = ["L1", "L2", "L3"].compactMap { phaseValues[key + "/" + $0] }
        return .some(values.isEmpty ? nil : values.reduce(0, +))
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
                let state = Int(exactly: value.rounded()) ?? nil
                solarCharger = SolarChargerModel(productName: solarCharger.productName, 
                                               pvVoltage: solarCharger.pvVoltage, 
                                               yieldPower: solarCharger.yieldPower, 
                                               dcVoltage: solarCharger.dcVoltage, 
                                               dcCurrent: solarCharger.dcCurrent, 
                                               state: state)
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
        var inverter = inverters[instance] ?? InverterModel()
        switch path.joined(separator: "/") {
        case "ProductName":
            if case .string(let value) = message.value { inverter.productName = value }
            else if case .null = message.value { inverter.productName = nil }
        case "Mode": inverter.mode = Self.integer(message.value, else: inverter.mode)
        case "State": inverter.state = Self.integer(message.value, else: inverter.state)
        default:
            // Ac/ActiveIn|Out/L1|L2|L3/P
            guard path.count == 4, path[0] == "Ac", path[3] == "P", ["ActiveIn", "Out"].contains(path[1]),
                  let total = phaseSum(message, key: "vebus/" + instance + "/" + path[1], phase: path[2]) else { return }
            if path[1] == "ActiveIn" { inverter.acInputPower = total } else { inverter.acOutputPower = total }
        }
        inverters[instance] = inverter
    }
}
