//
// DemoPlayer.swift
//
// Plays back recordings into the data store for demo mode (no network).
//

import Foundation

/// Represents a recording of MQTT messages
public struct Recording {
    /// The portal ID for this recording
    public let portalId: String
    
    /// The messages in this recording
    public let messages: [Message]
    
    /// Initialize from JSON data
    public init?(data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let jsonDict = json as? [String: Any],
                  let portalId = jsonDict["portalId"] as? String,
                  let messagesArray = jsonDict["messages"] as? [[String: Any]] else {
                return nil
            }
            
            var messages: [Message] = []
            for messageDict in messagesArray {
                let messageData = try JSONSerialization.data(withJSONObject: messageDict)
                if let message = Message(data: messageData) {
                    messages.append(message)
                }
            }
            
            self.portalId = portalId
            self.messages = messages
        } catch {
            return nil
        }
    }
    
    /// Represents a single MQTT message in a recording
    public struct Message {
        /// The MQTT topic
        public let topic: String
        
        /// The payload (JSON dictionary with "value" key)
        public let payload: [String: Any]
        
        /// Initialize from JSON data
        public init?(data: Data) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                guard let jsonDict = json as? [String: Any],
                      let topic = jsonDict["topic"] as? String,
                      let payload = jsonDict["payload"] as? [String: Any] else {
                    return nil
                }
                self.topic = topic
                self.payload = payload
            } catch {
                return nil
            }
        }
    }
}

/// Errors that can occur when using DemoPlayer
public enum DemoPlayerError: Error {
    case invalidRecordingData
}

/// Plays back recordings into the data store for demo mode
public final class DemoPlayer {
    /// The live data store to update
    private let store: LiveDataStore
    
    /// The optional history store to update
    private let historyStore: HistoryStore?
    
    /// The interval between updates in seconds
    private let interval: TimeInterval
    
    /// The queue to run updates on
    private let queue: DispatchQueue
    
    /// Whether the player is currently playing
    public private(set) var isPlaying: Bool = false
    
    /// The timer for periodic updates
    private var timer: DispatchSourceTimer?
    
    /// The recordings to play back
    private var recordings: [Recording] = []
    
    /// The original values for numeric fields that need variation
    private var originalValues: [String: Double] = [:]
    
    /// The tick count for deterministic variation
    private var tickCount: Int = 0
    
    /// Initialize a new DemoPlayer
    /// - Parameters:
    ///   - store: The live data store to update
    ///   - historyStore: Optional history store to update
    ///   - interval: The interval between updates in seconds (default: 2)
    ///   - queue: The queue to run updates on (default: .main)
    public init(store: LiveDataStore, historyStore: HistoryStore? = nil, interval: TimeInterval = 2, queue: DispatchQueue = .main) {
        self.store = store
        self.historyStore = historyStore
        self.interval = interval
        self.queue = queue
    }
    
    /// Load recordings from data
    /// - Parameter recordings: Array of Data containing JSON recordings
    /// - Throws: If any recording fails to decode
    public func load(_ recordings: [Data]) throws {
        var loadedRecordings: [Recording] = []
        
        for data in recordings {
            guard let recording = Recording(data: data) else {
                throw DemoPlayerError.invalidRecordingData
            }
            loadedRecordings.append(recording)
        }
        
        self.recordings = loadedRecordings
        
        // Clear any stored original values when loading new recordings
        originalValues.removeAll()
        tickCount = 0
    }
    
    /// Start playback
    /// Performs a full publish of all messages, then starts periodic updates
    public func start() {
        guard !isPlaying else { return }
        
        isPlaying = true
        
        // Perform full publish of all messages
        feedAllMessages()
        
        // Start timer for periodic updates
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.updateWithVariation()
        }
        timer.resume()
        
        self.timer = timer
    }
    
    /// Stop playback
    /// Stops periodic updates
    public func stop() {
        guard isPlaying else { return }
        
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    /// Feed all messages from recordings through the store
    private func feedAllMessages() {
        for recording in recordings {
            for message in recording.messages {
                // Convert payload to Data
                if let payloadData = try? JSONSerialization.data(withJSONObject: message.payload) {
                    store.handle(topic: message.topic, payload: payloadData)
                    historyStore?.handle(topic: message.topic, payload: payloadData)
                }
            }
        }
        
        // Store original values for numeric fields that will be varied
        storeOriginalValues()
    }
    
    /// Store original values for numeric fields that need variation
    private func storeOriginalValues() {
        // Check battery power values
        for (deviceId, battery) in store.batteries {
            if let power = battery.power {
                originalValues["battery_\(deviceId)_power"] = power
            }
            if let current = battery.current {
                originalValues["battery_\(deviceId)_current"] = current
            }
            if let voltage = battery.voltage {
                originalValues["battery_\(deviceId)_voltage"] = voltage
            }
            if let soc = battery.soc {
                originalValues["battery_\(deviceId)_soc"] = soc
            }
        }
        
        // Check solar charger yield power values
        for (deviceId, charger) in store.solarChargers {
            if let yieldPower = charger.yieldPower {
                originalValues["solarcharger_\(deviceId)_yieldPower"] = yieldPower
            }
            if let pvVoltage = charger.pvVoltage {
                originalValues["solarcharger_\(deviceId)_pvVoltage"] = pvVoltage
            }
            if let dcCurrent = charger.dcCurrent {
                originalValues["solarcharger_\(deviceId)_dcCurrent"] = dcCurrent
            }
        }
        
        // Check inverter power values
        for (deviceId, inverter) in store.inverters {
            if let acInputPower = inverter.acInputPower {
                originalValues["inverter_\(deviceId)_acInputPower"] = acInputPower
            }
            if let acOutputPower = inverter.acOutputPower {
                originalValues["inverter_\(deviceId)_acOutputPower"] = acOutputPower
            }
        }
        
        // Check system values
        if let batteryPower = store.system.batteryPower {
            originalValues["system_batteryPower"] = batteryPower
        }
        if let pvPower = store.system.pvPower {
            originalValues["system_pvPower"] = pvPower
        }
        if let acConsumptionOnOutput = store.system.acConsumptionOnOutput {
            originalValues["system_acConsumptionOnOutput"] = acConsumptionOnOutput
        }
        if let acConsumptionOnInput = store.system.acConsumptionOnInput {
            originalValues["system_acConsumptionOnInput"] = acConsumptionOnInput
        }
    }
    
    /// Update with deterministic variation
    private func updateWithVariation() {
        tickCount += 1
        
        // Apply variation to numeric values
        for (key, originalValue) in originalValues {
            let variation = calculateVariation(for: key)
            let newValue = originalValue * (1.0 + variation)
            
            // Ensure values stay in plausible ranges
            let clampedValue = clampValue(newValue, for: key, original: originalValue)
            
            // Update the store with the new value
            updateValue(key: key, newValue: clampedValue)
        }
    }
    
    /// Calculate deterministic variation using sine wave (±5%)
    private func calculateVariation(for key: String) -> Double {
        // Use a hash of the key to get a deterministic seed
        let seed = key.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 1000 }   // stable across launches (hashValue isn't)
        let phase = Double(seed) / 1000.0
        
        // Sine wave variation with ±5% amplitude
        let sineValue = sin(2 * .pi * (Double(tickCount) * 0.1 + phase))
        return sineValue * 0.05
    }
    
    /// Clamp value to stay in plausible range
    private func clampValue(_ value: Double, for key: String, original: Double) -> Double {
        // Battery SoC must stay within 0...100
        if key.contains("soc") {
            return max(0, min(100, value))
        }
        
        // Power values should stay within ±50% of original (but variation is already ±5%, so this is extra safety)
        let a = original * 0.5, b = original * 1.5   // for negative values (discharging) a > b, so order them
        return max(Swift.min(a, b), Swift.min(Swift.max(a, b), value))
    }
    
    /// Update a specific value in the store
    private func updateValue(key: String, newValue: Double) {
        if key.hasPrefix("battery_") {
            let parts = key.split(separator: "_")
            guard parts.count >= 3 else { return }
            let deviceId = String(parts[1])
            let field = String(parts[2])
            
            var payload: [String: Any] = [:]
            payload["value"] = newValue
            
            let topic: String
            switch field {
            case "power":
                topic = "N/\(store.portalId ?? "test")/battery/\(deviceId)/Dc/0/Power"
            case "current":
                topic = "N/\(store.portalId ?? "test")/battery/\(deviceId)/Dc/0/Current"
            case "voltage":
                topic = "N/\(store.portalId ?? "test")/battery/\(deviceId)/Dc/0/Voltage"
            case "soc":
                topic = "N/\(store.portalId ?? "test")/battery/\(deviceId)/Soc"
            default:
                return
            }
            
            if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
                store.handle(topic: topic, payload: payloadData)
                historyStore?.handle(topic: topic, payload: payloadData)
            }
        }
        else if key.hasPrefix("solarcharger_") {
            let parts = key.split(separator: "_")
            guard parts.count >= 3 else { return }
            let deviceId = String(parts[1])
            let field = String(parts[2])
            
            var payload: [String: Any] = [:]
            payload["value"] = newValue
            
            let topic: String
            switch field {
            case "yieldPower":
                topic = "N/\(store.portalId ?? "test")/solarcharger/\(deviceId)/Yield/Power"
            case "pvVoltage":
                topic = "N/\(store.portalId ?? "test")/solarcharger/\(deviceId)/Pv/V"
            case "dcCurrent":
                topic = "N/\(store.portalId ?? "test")/solarcharger/\(deviceId)/Dc/0/Current"
            default:
                return
            }
            
            if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
                store.handle(topic: topic, payload: payloadData)
                historyStore?.handle(topic: topic, payload: payloadData)
            }
        }
        else if key.hasPrefix("inverter_") {
            let parts = key.split(separator: "_")
            guard parts.count >= 3 else { return }
            let deviceId = String(parts[1])
            let field = String(parts[2])
            
            var payload: [String: Any] = [:]
            payload["value"] = newValue
            
            let topic: String
            switch field {
            case "acInputPower":
                topic = "N/\(store.portalId ?? "test")/vebus/\(deviceId)/Ac/ActiveIn/L1/P"
            case "acOutputPower":
                topic = "N/\(store.portalId ?? "test")/vebus/\(deviceId)/Ac/Out/L1/P"
            default:
                return
            }
            
            if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
                store.handle(topic: topic, payload: payloadData)
                historyStore?.handle(topic: topic, payload: payloadData)
            }
        }
        else if key.hasPrefix("system_") {
            let field = String(key.split(separator: "_")[1])
            
            var payload: [String: Any] = [:]
            payload["value"] = newValue
            
            let topic: String
            switch field {
            case "batteryPower":
                topic = "N/\(store.portalId ?? "test")/system/0/Dc/Battery/Power"
            case "pvPower":
                topic = "N/\(store.portalId ?? "test")/system/0/Dc/Pv/Power"
            case "acConsumptionOnOutput":
                topic = "N/\(store.portalId ?? "test")/system/0/Ac/ConsumptionOnOutput/L1/Power"
            case "acConsumptionOnInput":
                topic = "N/\(store.portalId ?? "test")/system/0/Ac/ConsumptionOnInput/L1/Power"
            default:
                return
            }
            
            if let payloadData = try? JSONSerialization.data(withJSONObject: payload) {
                store.handle(topic: topic, payload: payloadData)
                historyStore?.handle(topic: topic, payload: payloadData)
            }
        }
    }
}
