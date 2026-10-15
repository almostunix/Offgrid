import XCTest
@testable import VictronKit

/// T-62: AC values are summed over L1-L3, and AC input power comes from Ac/Grid and Ac/Genset
/// (not Ac/ConsumptionOnInput, which is loads on the input side).
final class PhaseTotalsTests: XCTestCase {
    private func store(fixture: String) throws -> (LiveDataStore, [String: Double]) {
        let url = try XCTUnwrap(Bundle.module.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let store = LiveDataStore()
        var values: [String: Double] = [:]
        for message in try XCTUnwrap(json["messages"] as? [[String: Any]]) {
            let topic = try XCTUnwrap(message["topic"] as? String)
            let payload = try XCTUnwrap(message["payload"] as? [String: Any])
            store.handle(topic: topic, payload: try JSONSerialization.data(withJSONObject: payload))
            if let v = payload["value"] as? Double { values[topic] = v }
        }
        return (store, values)
    }

    /// Expected value: the fixture's L1 + L2 + L3 for `group`, computed from the fixture itself.
    private func sum(_ values: [String: Double], _ prefix: String, _ suffix: String) -> Double {
        (1...3).compactMap { values[prefix + "L" + String($0) + suffix] }.reduce(0, +)
    }

    func testSystemTotalsSumAllThreePhases() throws {
        let (store, v) = try store(fixture: "three-phase")
        let base = "N/c0ffee000001/system/0/Ac/"
        XCTAssertEqual(store.system.acConsumptionOnOutput, sum(v, base + "ConsumptionOnOutput/", "/Power"))
        XCTAssertEqual(store.system.acConsumptionOnInput, sum(v, base + "ConsumptionOnInput/", "/Power"))
        XCTAssertEqual(store.system.acGridPower, sum(v, base + "Grid/", "/Power"))
        XCTAssertEqual(store.system.acGensetPower, sum(v, base + "Genset/", "/Power"))
        XCTAssertEqual(store.system.acInputPower, sum(v, base + "Grid/", "/Power") + sum(v, base + "Genset/", "/Power"))
    }

    func testInverterTotalsSumAllThreePhases() throws {
        let (store, v) = try store(fixture: "three-phase")
        let base = "N/c0ffee000001/vebus/276/Ac/"
        XCTAssertEqual(store.inverters["276"]?.acInputPower, sum(v, base + "ActiveIn/", "/P"))
        XCTAssertEqual(store.inverters["276"]?.acOutputPower, sum(v, base + "Out/", "/P"))
    }

    func testAPhaseGoingInvalidLeavesTheOthers() throws {
        let (store, v) = try store(fixture: "three-phase")
        let l2 = "N/c0ffee000001/system/0/Ac/Grid/L2/Power"
        store.handle(topic: l2, payload: try JSONSerialization.data(withJSONObject: ["value": NSNull()]))
        XCTAssertEqual(store.system.acGridPower, sum(v, "N/c0ffee000001/system/0/Ac/Grid/", "/Power") - v[l2]!)
    }

    func testGeneratorOnlyIsAcInput() throws {
        let store = LiveDataStore()
        store.handle(topic: "N/c0ffee000001/system/0/Ac/Genset/L1/Power", payload: try JSONSerialization.data(withJSONObject: ["value": 3000]))
        store.handle(topic: "N/c0ffee000001/system/0/Ac/ConsumptionOnInput/L1/Power", payload: try JSONSerialization.data(withJSONObject: ["value": 0]))
        XCTAssertEqual(store.system.acInputPower, 3000, "a 3 kW generator shows as 3 kW AC input, not the 0 W of input-side loads")
        XCTAssertNil(store.system.acGridPower)
    }

    func testHugeModeValueDoesNotTrap() throws {
        let store = LiveDataStore()
        store.handle(topic: "N/c0ffee000001/vebus/276/Mode", payload: try JSONSerialization.data(withJSONObject: ["value": 3]))
        store.handle(topic: "N/c0ffee000001/vebus/276/Mode", payload: try JSONSerialization.data(withJSONObject: ["value": 1e300]))
        XCTAssertEqual(store.inverters["276"]?.mode, 3, "an out-of-range value is ignored")
    }
}
