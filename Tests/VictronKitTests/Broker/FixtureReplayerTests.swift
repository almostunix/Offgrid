import XCTest
@testable import VictronKit

final class FixtureReplayerTests: XCTestCase {

    func testParseKeepaliveOptionsEmptyPayload() {
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: "")
        XCTAssertFalse(suppress)
        XCTAssertNil(echo)
    }

    func testParseKeepaliveOptionsSuppressRepublish() {
        let payload = "{\"keepalive-options\":[\"suppress-republish\"]}"
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        XCTAssertTrue(suppress)
        XCTAssertNil(echo)
    }

    func testParseKeepaliveOptionsEchoId() {
        let payload = "{\"keepalive-options\":[{\"full-publish-completed-echo\":\"test-id\"}]}"
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        XCTAssertFalse(suppress)
        XCTAssertEqual(echo, "test-id")
    }

    func testParseKeepaliveOptionsBothOptions() {
        let payload = "{\"keepalive-options\":[\"suppress-republish\",{\"full-publish-completed-echo\":\"test-id\"}]}"
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        XCTAssertTrue(suppress)
        XCTAssertEqual(echo, "test-id")
    }

    func testParseKeepaliveOptionsInvalidJson() {
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: "invalid json")
        XCTAssertFalse(suppress)
        XCTAssertNil(echo)
    }

    func testParseKeepaliveOptionsMissingOptions() {
        let payload = "{\"other-field\":\"value\"}"
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        XCTAssertFalse(suppress)
        XCTAssertNil(echo)
    }

    func testParseKeepaliveOptionsWrongOptionsType() {
        let payload = "{\"keepalive-options\":\"string-not-array\"}"
        let (suppress, echo) = FixtureReplayer.parseKeepaliveOptions(payload: payload)
        XCTAssertFalse(suppress)
        XCTAssertNil(echo)
    }
}