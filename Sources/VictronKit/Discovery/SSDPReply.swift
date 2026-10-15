//
// SSDPReply.swift
//
// Parser for SSDP M-SEARCH replies from Victron GX devices.
//

import Foundation

struct SSDPReply {
    static func parse(_ text: String, from host: String) -> (portalId: String, location: URL)? {
        // Parse SSDP reply headers
        let lines = text.components(separatedBy: .newlines)
        var usn: String?
        var location: URL?

        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let header = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            if header.lowercased() == "usn" {
                usn = value
            } else if header.lowercased() == "location" {
                if let url = URL(string: value) {
                    location = url
                }
            }
        }

        guard let usn = usn, let location = location else { return nil }

        // Validate USN format: uuid:com.victronenergy.ccgx.<PORTAL_ID>
        let prefix = "uuid:com.victronenergy.ccgx."
        guard usn.hasPrefix(prefix) else { return nil }

        let portalIdPart = String(usn.dropFirst(prefix.count))
        // Portal ID is the part before "::" with ":" separators removed, lowercased
        let portalId = portalIdPart.components(separatedBy: "::")[0].replacingOccurrences(of: ":", with: "").lowercased()

        // Validate location URL host matches the resolved IP
        guard let locationHost = location.host(), locationHost == host else { return nil }

        return (portalId, location)
    }
}