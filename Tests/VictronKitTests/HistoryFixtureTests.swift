import XCTest
@testable import VictronKit

final class HistoryFixtureTests: XCTestCase {
    func testSolarchargerHistoryFixture() throws {
        let url = Bundle.module.url(forResource: "solarcharger_history", withExtension: "json", subdirectory: "Fixtures")
        XCTAssertNotNil(url, "Could not find solarcharger_history.json")
        
        guard let url = url else { return }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json, "JSON should be a dictionary")
        
        guard let json = json else { return }
        
        // Verify portal ID
        XCTAssertEqual(json["portalId"] as? String, "c0ffee000001")
        
        // Verify messages array
        guard let messages = json["messages"] as? [[String: Any]] else {
            XCTFail("Messages should be an array of dictionaries")
            return
        }
        
        // Verify each message
        for message in messages {
            // Topic should start with the portal ID
            XCTAssertTrue((message["topic"] as? String)?.hasPrefix("N/c0ffee000001/") ?? false, "Topic should start with N/c0ffee000001/")
            
            // Payload should have a value
            if let payload = message["payload"] as? [String: Any] {
                XCTAssertTrue(payload.keys.contains("value"), "Payload should have a value key")
                
                // Value should be numeric
                if let value = payload["value"] {
                    XCTAssertTrue(value is Int || value is Double, "Value should be numeric")
                }
            }
        }
        
        // Verify we have exactly 30 days of history for each field
        let expectedFields = ["Yield", "MaxPower", "MaxPvVoltage", "TimeInBulk"]
        for field in expectedFields {
            let fieldMessages = messages.filter { 
                (($0["topic"] as? String)?.contains("/History/Daily/") ?? false) && 
                (($0["topic"] as? String)?.contains("/" + field) ?? false)
            }
            XCTAssertEqual(fieldMessages.count, 30, "Should have exactly 30 days of history for field: " + field)
            
            // Verify day numbers 0-29
            let dayNumbers = fieldMessages.compactMap { 
                ($0["topic"] as? String)?.components(separatedBy: "/").filter { $0 == "0" || $0 == "1" || $0 == "2" || $0 == "3" || $0 == "4" || $0 == "5" || $0 == "6" || $0 == "7" || $0 == "8" || $0 == "9" || $0 == "10" || $0 == "11" || $0 == "12" || $0 == "13" || $0 == "14" || $0 == "15" || $0 == "16" || $0 == "17" || $0 == "18" || $0 == "19" || $0 == "20" || $0 == "21" || $0 == "22" || $0 == "23" || $0 == "24" || $0 == "25" || $0 == "26" || $0 == "27" || $0 == "28" || $0 == "29" }
            }
            XCTAssertEqual(Set(dayNumbers).count, 30, "Should have all day numbers 0-29 for field: " + field)
        }
    }
    
    func testBatteryHistoryFixture() throws {
        let url = Bundle.module.url(forResource: "battery_history", withExtension: "json", subdirectory: "Fixtures")
        XCTAssertNotNil(url, "Could not find battery_history.json")
        
        guard let url = url else { return }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json, "JSON should be a dictionary")
        
        guard let json = json else { return }
        
        // Verify portal ID
        XCTAssertEqual(json["portalId"] as? String, "c0ffee000001")
        
        // Verify messages array
        guard let messages = json["messages"] as? [[String: Any]] else {
            XCTFail("Messages should be an array of dictionaries")
            return
        }
        
        // Verify we have exactly 8 history fields
        XCTAssertEqual(messages.count, 8, "Should have exactly 8 battery history fields")
        
        // Verify each message
        for message in messages {
            // Topic should start with the portal ID
            XCTAssertTrue((message["topic"] as? String)?.hasPrefix("N/c0ffee000001/") ?? false, "Topic should start with N/c0ffee000001/")
            
            // Topic should contain History
            XCTAssertTrue((message["topic"] as? String)?.contains("/History/") ?? false, "Topic should contain /History/")
            
            // Payload should have a value
            if let payload = message["payload"] as? [String: Any] {
                XCTAssertTrue(payload.keys.contains("value"), "Payload should have a value key")
                
                // Value should be numeric
                if let value = payload["value"] {
                    XCTAssertTrue(value is Int || value is Double, "Value should be numeric")
                }
            }
        }
        
        // Verify all expected fields are present
        let expectedFields = ["ChargeCycles", "DeepestDischarge", "AverageDischarge", "DischargedEnergy", "ChargedEnergy", "TotalAhDrawn", "MinimumVoltage", "MaximumVoltage"]
        for field in expectedFields {
            let hasField = messages.contains { 
                (($0["topic"] as? String)?.contains("/" + field) ?? false)
            }
            XCTAssertTrue(hasField, "Should have field: " + field)
        }
    }
}
