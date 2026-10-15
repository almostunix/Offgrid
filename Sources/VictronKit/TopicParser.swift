//
// TopicParser.swift
//
// Parses MQTT topics and payloads from Cerbo GX devices.
//

import Foundation

/// Represents a parsed MQTT topic
public struct Topic {
    /// The portal ID (device identifier)
    public let portalId: String
    
    /// The service type (e.g., "system", "battery", "solarcharger", "vebus")
    public let service: String
    
    /// The instance ID (device number)
    public let instance: String
    
    /// The remaining path components
    public let path: [String]
    
    /// The full topic string
    public let fullTopic: String
}

/// Represents a parsed MQTT payload
public enum PayloadValue: Equatable {
    /// A numeric value (Int or Double)
    case number(Double)
    
    /// A string value
    case string(String)
    
    /// A null value
    case null
    
    /// An array of values
    case array([PayloadValue])
    
    /// Initialize from a JSON value
    init?(jsonValue: Any) {
        if let value = jsonValue as? Int {
            self = .number(Double(value))
        } else if let value = jsonValue as? Double {
            self = .number(value)
        } else if let value = jsonValue as? String {
            self = .string(value)
        } else if jsonValue is NSNull {
            self = .null
        } else if let array = jsonValue as? [Any] {
            // For arrays, accept arrays of any supported values (numbers, strings, null, nested arrays)
            let parsedArray = array.compactMap { PayloadValue(jsonValue: $0) }
            if parsedArray.count == array.count {
                self = .array(parsedArray)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

/// Represents a parsed MQTT message
public struct ParsedMessage {
    /// The parsed topic
    public let topic: Topic
    
    /// The parsed payload value
    public let value: PayloadValue
    
    /// The raw payload dictionary (for backward compatibility)
    public let rawPayload: [String: Any]
}

/// Parses MQTT topics and payloads from Cerbo GX devices
public final class TopicParser {
    /// The detected portal ID, if any
    public private(set) var detectedPortalId: String?
    
    /// Initialize a new TopicParser
    public init() {}
    
    /// Parse a topic string and learn the portal ID if not already known
    /// - Parameter topic: The MQTT topic string
    /// - Returns: A parsed Topic, or nil if the topic is invalid
    public func parseTopic(_ topic: String) -> Topic? {
        // Parse the topic
        let parts = topic.split(separator: "/", omittingEmptySubsequences: false)
        
        // Topic must start with N/ and have at least 3 parts (N/portalId/service...)
        guard parts.count >= 3, parts[0] == "N" else {
            return nil
        }
        
        // Portal ID and service must not be empty or contain wildcards
        guard parts[1] != "", parts[2] != "", !parts[1].contains("+"), !parts[1].contains("#"),
              !parts[2].contains("+"), !parts[2].contains("#") else {   // no wildcards in portal or service (found by T-34 fuzzing)
            return nil
        }
        
        let portalId = String(parts[1])
        let service = String(parts[2])
        
        // Handle special topics like full_publish_completed (3 parts total)
        if parts.count == 3 {
            // Learn portal ID from first valid N/portalId/... message
            if detectedPortalId == nil {
                detectedPortalId = portalId
            }
            
            return Topic(
                portalId: portalId,
                service: service,
                instance: "", // No instance for special topics
                path: [],     // No path for special topics
                fullTopic: topic
            )
        }
        
        // Normal topics: N/portalId/service/instance/path...
        // Must have at least 4 parts and instance must not be empty or contain wildcards
        guard parts.count >= 4, parts[3] != "", !parts[3].contains("+"), !parts[3].contains("#") else {
            return nil
        }
        
        let instance = String(parts[3])
        
        // Path parts must not contain empty segments or wildcards
        let pathParts = parts.dropFirst(4)
        if pathParts.contains("") || pathParts.contains(where: { $0.contains("+") || $0.contains("#") }) {
            return nil
        }
        
        let path = pathParts.map { String($0) }
        
        // Learn portal ID from first valid N/portalId/... message
        if detectedPortalId == nil {
            detectedPortalId = portalId
        }
        
        return Topic(
            portalId: portalId,
            service: service,
            instance: instance,
            path: path,
            fullTopic: topic
        )
    }
    
    /// Parse a payload dictionary
    /// - Parameter payload: The payload dictionary
    /// - Returns: A parsed PayloadValue, or nil if the payload is invalid
    public func parsePayload(_ payload: [String: Any]) -> PayloadValue? {
        guard let value = payload["value"] else {
            return nil
        }
        
        return PayloadValue(jsonValue: value)
    }
    
    /// Parse a complete MQTT message
    /// - Parameter topic: The MQTT topic string
    /// - Parameter payload: The payload dictionary
    /// - Returns: A parsed ParsedMessage, or nil if parsing fails
    public func parseMessage(topic: String, payload: [String: Any]) -> ParsedMessage? {
        guard let parsedTopic = parseTopic(topic) else {
            return nil
        }
        
        guard let parsedValue = parsePayload(payload) else {
            return nil
        }
        
        return ParsedMessage(
            topic: parsedTopic,
            value: parsedValue,
            rawPayload: payload
        )
    }
}
