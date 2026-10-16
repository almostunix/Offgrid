//
// SubnetSweep.swift
//
// Helper for generating host addresses to probe during SSDP sweep.
//

import Foundation

public struct IPv4Interface: Equatable {
    public let address: UInt32  // host byte order
    public let netmask: UInt32  // host byte order

    public init(address: UInt32, netmask: UInt32) {
        self.address = address
        self.netmask = netmask
    }
}

public struct SubnetSweep {
    /// Generate host addresses to probe for a given interface.
    /// Returns addresses in dotted-decimal form, excluding network address, broadcast address, and the interface's own address.
    /// Limits to /24 even for larger subnets (e.g., /16 Wi-Fi).
    public static func hosts(for iface: IPv4Interface) -> [String] {
        let mask = max(iface.netmask, 0xFFFFFF00)  // Cap at /24
        let network = iface.address & mask
        let broadcast = network | (~mask & 0xFFFFFFFF)
        let firstHost = network + 1
        let lastHost = broadcast - 1
        
        guard firstHost <= lastHost else { return [] }
        
        var addresses: [String] = []
        for ip in firstHost...lastHost {
            // Skip the interface's own address
            if ip == iface.address { continue }
            
            let address = String(format: "%d.%d.%d.%d",
                                (ip >> 24) & 0xFF,
                                (ip >> 16) & 0xFF,
                                (ip >> 8) & 0xFF,
                                ip & 0xFF)
            addresses.append(address)
        }
        
        return addresses
    }

    /// Get the Wi-Fi interface (en0) information.
    /// Returns nil if no suitable interface is found.
    public static func wifiInterface() -> IPv4Interface? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return nil }
        defer { freeifaddrs(interfaces) }
        
        var ptr = interfaces
        while ptr != nil {
            let iface = ptr!.pointee
            ptr = ptr?.pointee.ifa_next
            
            // Look for en0 (Wi-Fi interface) with AF_INET
            if String(cString: iface.ifa_name) != "en0" || iface.ifa_addr?.pointee.sa_family != sa_family_t(AF_INET) { continue }
            
            // Check if interface is up and not loopback
            let flags = Int32(iface.ifa_flags)
            if (flags & (IFF_UP | IFF_RUNNING)) == 0 || (flags & IFF_LOOPBACK) != 0 { continue }
            
            // Extract address and netmask
            let addr = iface.ifa_addr!.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }.sin_addr.s_addr
            let mask = iface.ifa_netmask!.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }.sin_addr.s_addr
            
            // Convert from network byte order to host byte order
            let address = UInt32(bigEndian: addr)
            let netmask = UInt32(bigEndian: mask)
            
            return IPv4Interface(address: address, netmask: netmask)
        }
        
        return nil
    }
}