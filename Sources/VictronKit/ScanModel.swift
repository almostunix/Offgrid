//
// ScanModel.swift
//
// Model for scanning and filtering discovered devices
//

import Foundation

public enum ScanModel {
    /// Filters found devices to remove those that are already saved
    /// - Parameters:
    ///   - found: Array of discovered devices
    ///   - saved: Array of saved connection profiles
    /// - Returns: Filtered array of discovered devices
    public static func foundRows(found: [DiscoveredDevice], saved: [ConnectionProfile]) -> [DiscoveredDevice] {
        return found.filter { device in
            // Filter out devices whose portalId or host matches a saved profile
            !saved.contains { profile in
                if let portalId = device.portalId {
                    return portalId == profile.portalId || device.host == profile.host
                }
                return device.host == profile.host
            }
        }
    }

    /// Determines if a discovered device can be connected to
    /// - Parameter device: The discovered device
    /// - Returns: True if the device can be connected to
    public static func canConnect(_ device: DiscoveredDevice) -> Bool {
        // Can only connect if MQTT is on
        return device.mqttOnLan != .off
    }

    /// Creates a connection profile from a discovered device
    /// - Parameters:
    ///   - device: The discovered device
    ///   - useTLS: Whether to use TLS
    /// - Returns: A connection profile
    public static func profile(for device: DiscoveredDevice, useTLS: Bool) -> ConnectionProfile {
        let port = useTLS ? 8883 : 1883
        var profile = ConnectionProfile(
            name: device.name,
            host: device.host,
            port: port,
            useTLS: useTLS,
            username: nil,
            pinnedCertificateSHA256: nil
        )
        profile.portalId = device.portalId
        return profile
    }
}
