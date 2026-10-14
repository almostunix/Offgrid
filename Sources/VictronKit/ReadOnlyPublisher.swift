//
// VictronKit
//
// Read-only MQTT publisher that enforces R/<portalId>/... topic constraint
//

import Foundation

/// Read-only MQTT publisher that enforces topic constraints
public struct ReadOnlyPublisher {
    /// Errors that can occur during publishing
    public enum Error: Swift.Error {
        /// The portal ID is invalid (empty or contains forbidden characters)
        case invalidPortalId(portalId: String)
        /// The topic is not allowed (must be R/<portalId>/...)
        case notAllowed(topic: String)
    }
    
    /// The portal ID for this publisher
    private let portalId: String
    
    /// The underlying send function that will publish to MQTT
    private let send: (String, String) -> Void
    
    /// Initializes a read-only publisher
    /// - Parameters:
    ///   - portalId: The portal ID to use for topic validation
    ///   - send: The function that will be called to publish messages (only for valid R/<portalId>/... topics)
    /// - Throws: `Error.invalidPortalId` if the portal ID is empty or contains forbidden characters
    public init(portalId: String, send: @escaping (String, String) -> Void) throws {
        // Validate portal ID
        guard !portalId.isEmpty else {
            throw Error.invalidPortalId(portalId: portalId)
        }
        
        // Check for forbidden characters: /, +, #, whitespace, NUL
        let forbiddenChars: [Character] = ["/", "+", "#", " ", "\t", "\n", "\r", "\0"]
        for char in forbiddenChars {
            if portalId.contains(char) {
                throw Error.invalidPortalId(portalId: portalId)
            }
        }
        
        self.portalId = portalId
        self.send = send
    }
    
    /// Publishes a message only if the topic is R/<portalId>/...
    /// - Parameters:
    ///   - topic: The topic to publish to
    ///   - payload: The message payload
    /// - Throws: `Error.notAllowed` if the topic is not valid
    public func publish(topic: String, payload: String) throws {
        // Check for empty topic
        guard !topic.isEmpty else {
            throw Error.notAllowed(topic: topic)
        }
        
        // Check for whitespace-only topic
        guard !topic.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Error.notAllowed(topic: topic)
        }
        
        // Check for MQTT wildcard characters (+, #) and NUL
        let forbiddenChars: [Character] = ["+", "#", "\0"]
        for char in forbiddenChars {
            if topic.contains(char) {
                throw Error.notAllowed(topic: topic)
            }
        }
        
        // Required prefix
        let requiredPrefix = "R/" + portalId + "/"
        
        // Check if topic starts with the required prefix
        guard topic.hasPrefix(requiredPrefix) else {
            throw Error.notAllowed(topic: topic)
        }
        
        // Check that there's at least one more path part after R/<portalId>/
        let remainingPath = String(topic.dropFirst(requiredPrefix.count))
        guard !remainingPath.isEmpty else {
            throw Error.notAllowed(topic: topic)
        }
        
        // Topic is valid, send it
        send(topic, payload)
    }
    
    /// Publishes a keepalive message
    /// - Throws: `Error.notAllowed` if the keepalive topic is not valid (shouldn't happen with valid portalId)
    public func keepalive() throws {
        try publish(topic: "R/" + portalId + "/keepalive", payload: "")
    }
}
