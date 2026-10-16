
//
// ConnectionUI.swift
//
// Utility functions for connection UI state management
//

import Foundation

public enum ConnectionUI {
    /// Determines whether to show the live view based on connection state and whether a connection has been established
    /// 
    /// - Parameters:
    ///   - state: The current connection state
    ///   - hasConnected: Whether a connection has been established at least once
    /// - Returns: True if the live view should be shown
    public static func showsLiveView(state: ConnectionState, hasConnected: Bool) -> Bool {
        switch state {
        case .connected:
            return true
        case .reconnecting:
            return hasConnected
        case .idle, .connecting, .failed:
            return false
        }
    }
}