//
// LiveSeriesRecorder.swift
//
// Records live values into rolling buffers for charting
//

import Foundation
import Combine

/// The series types that can be recorded
public enum LiveSeries: String, CaseIterable {
    case batteryPower
    case batterySoc
    case pvPower
    case acConsumption
}

/// Records live values into rolling buffers
public final class LiveSeriesRecorder: ObservableObject {
    /// The data store to read values from
    private let store: LiveDataStore
    
    /// Function to get current date/time
    private let now: () -> Date
    
    /// Rolling buffers for each series
    private var buffers: [LiveSeries: RollingBuffer]
    
    /// Combine subscription for store changes
    private var cancellable: AnyCancellable?
    
    /// Initialize a new LiveSeriesRecorder
    /// - Parameters:
    ///   - store: The LiveDataStore to read values from
    ///   - now: Function to get current date/time (for testing)
    public init(store: LiveDataStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        self.buffers = [:]
        
        // Initialize buffers for all series
        for series in LiveSeries.allCases {
            buffers[series] = RollingBuffer()
        }
        
        // Subscribe to store changes with throttling
        cancellable = store.objectWillChange
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.record()
            }
    }
    
    /// Get the rolling buffer for a specific series
    /// - Parameter series: The series to get buffer for
    /// - Returns: The rolling buffer
    public func buffer(for series: LiveSeries) -> RollingBuffer {
        return buffers[series] ?? RollingBuffer()
    }

    /// Reset all recording buffers, clearing recorded data
    public func reset() {
        for series in LiveSeries.allCases {
            buffers[series]?.clear()
        }
    }
    
    /// Record current values from the store
    public func record() {
        let currentTime = now()
        
        // Record battery power
        if let value = store.system.batteryPower {
            buffers[.batteryPower]?.addSample(Sample(timestamp: currentTime, value: value))
        }
        
        // Record battery SoC
        if let value = store.system.batterySoc {
            buffers[.batterySoc]?.addSample(Sample(timestamp: currentTime, value: value))
        }
        
        // Record PV power
        if let value = store.system.pvPower {
            buffers[.pvPower]?.addSample(Sample(timestamp: currentTime, value: value))
        }
        
        // Record AC consumption
        if let value = store.system.acConsumptionTotal {
            buffers[.acConsumption]?.addSample(Sample(timestamp: currentTime, value: value))
        }
        
        // Notify observers
        objectWillChange.send()
    }
}
