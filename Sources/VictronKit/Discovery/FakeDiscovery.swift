//
// FakeDiscovery.swift
//
// Fake discovery service for testing and previews.
//

import Foundation

public class FakeDiscovery: DeviceDiscovering {
    private var onUpdate: ([DiscoveredDevice]) -> Void = { _ in }
    private var devices: [DiscoveredDevice] = []
    private var isRunning = false

    public init(devices: [DiscoveredDevice] = []) {
        self.devices = devices
    }

    public func start(onUpdate: @escaping ([DiscoveredDevice]) -> Void) {
        self.onUpdate = onUpdate
        self.isRunning = true
        onUpdate(devices)
    }

    public func stop() {
        isRunning = false
    }

    public func setDevices(_ devices: [DiscoveredDevice]) {
        self.devices = devices
        if isRunning {
            onUpdate(devices)
        }
    }
}