//
// DiscoveredDevice.swift
//
// Discovery service models for Victron GX device discovery.
//

import Foundation

public enum MqttOnLan: Int, Equatable {
    case off = 0
    case on = 1
    case tokensOnly = 2
}

public struct DiscoveredDevice: Identifiable, Equatable {
    public let id: String  // portal ID if known, else host
    public let name: String
    public let host: String  // IPv4 address
    public let portalId: String?
    public let mqttOnLan: MqttOnLan?
    public let venusVersion: String?
    public let lastSeen: Date

    public init(id: String, name: String, host: String, portalId: String? = nil, mqttOnLan: MqttOnLan? = nil, venusVersion: String? = nil, lastSeen: Date = Date()) {
        self.id = id
        self.name = name
        self.host = host
        self.portalId = portalId
        self.mqttOnLan = mqttOnLan
        self.venusVersion = venusVersion
        self.lastSeen = lastSeen
    }
}

public protocol DeviceDiscovering: AnyObject {
    func start(onUpdate: @escaping ([DiscoveredDevice]) -> Void)
    func stop()
}