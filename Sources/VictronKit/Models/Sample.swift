//
// Sample.swift
//
// Represents a single data sample for charting.
//

import Foundation
import DequeModule

/// A timestamped sample value for charting
public struct Sample: Equatable {
    /// The timestamp when the sample was taken
    public let timestamp: Date
    
    /// The numeric value of the sample
    public let value: Double
    
    /// Initialize a new sample
    /// - Parameters:
    ///   - timestamp: The timestamp
    ///   - value: The numeric value
    public init(timestamp: Date, value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

/// Represents a rolling window of samples
public struct RollingWindow: Equatable {
    /// The samples in the window
    public let samples: [Sample]
    
    /// The minimum value in the window
    public var min: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.min(by: { $0.value < $1.value })?.value
    }
    
    /// The maximum value in the window
    public var max: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.max(by: { $0.value < $1.value })?.value
    }
    
    /// The average value in the window
    public var avg: Double? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0.0) { $0 + $1.value }
        return sum / Double(samples.count)
    }
    
    /// Initialize a new rolling window
    /// - Parameter samples: The samples in the window
    public init(samples: [Sample]) {
        self.samples = samples
    }
}

/// Manages rolling buffers for live chart data
public final class RollingBuffer {
    /// Time interval for a 5-minute window (300 seconds)
    private static let fiveMinuteInterval: TimeInterval = 300.0
    
    /// Time interval for a 1-hour window (3600 seconds)
    private static let oneHourInterval: TimeInterval = 3600.0
    
    /// The 5-minute rolling buffer
    private var fiveMinuteBuffer: Deque<Sample>
    
    /// The 1-hour rolling buffer
    private var oneHourBuffer: Deque<Sample>
    
    /// Initialize a new rolling buffer
    public init() {
        self.fiveMinuteBuffer = Deque<Sample>()
        self.oneHourBuffer = Deque<Sample>()
    }
    
    /// Add a new sample to both buffers
    /// - Parameter sample: The sample to add
    public func addSample(_ sample: Sample) {
        // Add to 5-minute buffer
        fiveMinuteBuffer.append(sample)
        
        // Add to 1-hour buffer
        oneHourBuffer.append(sample)
    }
    
    /// Get the 5-minute rolling window
    /// - Returns: The 5-minute rolling window
    public func getFiveMinuteWindow() -> RollingWindow {
        let currentTime = Date()
        trimFiveMinuteBuffer(with: currentTime)
        let samples = Array(fiveMinuteBuffer)
        return RollingWindow(samples: samples)
    }
    
    /// Get the 1-hour rolling window
    /// - Returns: The 1-hour rolling window
    public func getOneHourWindow() -> RollingWindow {
        let currentTime = Date()
        trimOneHourBuffer(with: currentTime)
        let samples = Array(oneHourBuffer)
        return RollingWindow(samples: samples)
    }
    
    /// Get the 5-minute rolling window with a specific current time (for testing)
    /// - Parameter currentTime: The current time to use for trimming
    /// - Returns: The 5-minute rolling window
    internal func getFiveMinuteWindow(at currentTime: Date) -> RollingWindow {
        trimFiveMinuteBuffer(with: currentTime)
        let samples = Array(fiveMinuteBuffer)
        return RollingWindow(samples: samples)
    }
    
    /// Get the 1-hour rolling window with a specific current time (for testing)
    /// - Parameter currentTime: The current time to use for trimming
    /// - Returns: The 1-hour rolling window
    internal func getOneHourWindow(at currentTime: Date) -> RollingWindow {
        trimOneHourBuffer(with: currentTime)
        let samples = Array(oneHourBuffer)
        return RollingWindow(samples: samples)
    }

    /// Clear all samples from both buffers
    public func clear() {
        fiveMinuteBuffer.removeAll()
        oneHourBuffer.removeAll()
    }
    
    /// Trim old samples from 5-minute buffer based on the current timestamp
    /// - Parameter currentTimestamp: The current timestamp
    private func trimFiveMinuteBuffer(with currentTimestamp: Date) {
        while !fiveMinuteBuffer.isEmpty {
            let oldestSample = fiveMinuteBuffer.first!
            let age = currentTimestamp.timeIntervalSince(oldestSample.timestamp)
            if age > Self.fiveMinuteInterval {
                fiveMinuteBuffer.removeFirst()
            } else {
                break
            }
        }
    }
    
    /// Trim old samples from 1-hour buffer based on the current timestamp
    /// - Parameter currentTimestamp: The current timestamp
    private func trimOneHourBuffer(with currentTimestamp: Date) {
        while !oneHourBuffer.isEmpty {
            let oldestSample = oneHourBuffer.first!
            let age = currentTimestamp.timeIntervalSince(oldestSample.timestamp)
            if age > Self.oneHourInterval {
                oneHourBuffer.removeFirst()
            } else {
                break
            }
        }
    }
}