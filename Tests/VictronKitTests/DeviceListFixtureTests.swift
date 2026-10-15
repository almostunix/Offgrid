import XCTest
@testable import VictronKit

/// T-22: the device list built from the real fixture full publish (not hand-made messages).
final class DeviceListFixtureTests: XCTestCase {
    func testRowsFromFullPublishFixtures() throws {
        let store = LiveDataStore()
        for name in ["system", "battery", "solarcharger", "vebus"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            for message in try XCTUnwrap(json["messages"] as? [[String: Any]]) {
                let topic = try XCTUnwrap(message["topic"] as? String)
                let payload = try JSONSerialization.data(withJSONObject: try XCTUnwrap(message["payload"]))
                store.handle(topic: topic, payload: payload)
            }
        }
        let rows = DeviceListModel.rows(from: store)
        XCTAssertEqual(Set(rows.map { "\($0.type)-\($0.id)" }), ["battery-279", "solarCharger-278", "inverter-276"])
        XCTAssertEqual(rows.first { $0.type == .battery }?.productName, "Victron SmartShunt 500A")
    }
}
