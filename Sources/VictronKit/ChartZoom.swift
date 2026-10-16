import CoreGraphics
import Foundation

/// Utilities for calculating visible chart lengths during zoom gestures
public enum ChartZoom {
    /// Calculates the new visible length for a chart during a zoom gesture
    /// 
    /// - Parameters:
    ///   - start: The current visible length before zoom
    ///   - magnification: The magnification factor from the gesture (must be > 0)
    ///   - min: The minimum allowed visible length
    ///   - max: The maximum allowed visible length
    /// 
    /// - Returns: The new visible length, clamped between min and max
    public static func visibleLength(start: TimeInterval, magnification: CGFloat, min: TimeInterval, max: TimeInterval) -> TimeInterval {
        guard magnification > 0 else {
            return start
        }
        return Swift.max(min, Swift.min(max, start / Double(magnification)))
    }
}