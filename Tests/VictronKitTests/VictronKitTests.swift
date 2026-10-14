//
// VictronKitTests
//
// Tests for VictronKit package.
//

import XCTest
@testable import VictronKit

final class VictronKitTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the expected results.
        let victronKit = VictronKit()
        XCTAssertNotNil(victronKit)
    }

    func testFixturesParse() throws {
        // Test that all fixture files can be loaded and parsed
        let fixtureFiles = ["system", "battery", "solarcharger", "vebus", "full_publish_completed"]

        for filename in fixtureFiles {
            let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "Fixtures")
            XCTAssertNotNil(url, "Could not find fixture file: \(filename).json")
            
            guard let url = url else { continue }
            
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            XCTAssertNotNil(json, "JSON should be a dictionary")
            
            guard let json = json else { continue }
            
            // Verify portal ID
            XCTAssertEqual(json["portalId"] as? String, "c0ffee000001")
            
            // Verify messages array
            guard let messages = json["messages"] as? [[String: Any]] else {
                XCTFail("Messages should be an array of dictionaries")
                continue
            }
            
            // Verify each message
            for message in messages {
                // Topic should start with the portal ID
                XCTAssertTrue((message["topic"] as? String)?.hasPrefix("N/c0ffee000001/") ?? false, "Topic should start with N/c0ffee000001/")
                
                // Topic should have at least 3 path parts (e.g., N/c0ffee000001/system/0/Serial)
                if let topic = message["topic"] as? String {
                    let parts = topic.split(separator: "/")
                    XCTAssertGreaterThanOrEqual(parts.count, 3, "Topic should have at least 3 parts")
                }
                
                // Payload should have a value
                if let payload = message["payload"] as? [String: Any] {
                    XCTAssertTrue(payload.keys.contains("value"), "Payload should have a value key")
                }
            }
        }
    }
}
