//
// LocalNetworkStatus.swift
//
// Maps iOS local network access errors to a simple status for discovery.
// iOS triggers the local network prompt when resolving .local names or
// connecting to LAN hosts. Without multicast entitlement, we only resolve
// "venus.local" and connect to its IP, which still needs NSLocalNetworkUsageDescription.
//

import Foundation
import Network

/// Status of iOS local network access for discovery
public enum LocalNetworkStatus {
    case unknown
    case allowed
    case denied
}

/// Maps Network framework errors to LocalNetworkStatus
public enum LocalNetworkErrorMapper {
    /// Maps NWError to LocalNetworkStatus
    /// - Parameter error: The error from NWConnection or NWBrowser
    /// - Returns: LocalNetworkStatus based on the error
    public static func map(_ error: Error) -> LocalNetworkStatus {
        // The Network framework's own errors (what NWConnection and the discovery report)
        if let nwError = error as? NWError {
            switch nwError {
            case .posix(let code) where code == .EHOSTUNREACH || code == .ENETUNREACH:
                return .denied
            case .dns(let code) where code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied):
                return .denied
            default:
                return .unknown
            }
        }

        // DNS policy denied (kDNSServiceErr_PolicyDenied = -65570)
        if let nsError = error as NSError?,
           nsError.domain == "com.apple.network.dns",
           nsError.code == -65570 {
            return .denied
        }
    
        // POSIX errors for host/unreachable network
        if let nsError = error as NSError?,
           nsError.domain == NSPOSIXErrorDomain,
           (nsError.code == Int(EHOSTUNREACH) || nsError.code == Int(ENETUNREACH)) {
            return .denied
        }
    
        // Unknown error - could be temporary or other issue
        return .unknown
    }
}
