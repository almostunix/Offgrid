import XCTest
@testable import VictronKit

/// The expected strings are the spec (docs/STYLE.md: "1,250 W", ">= 10,000 W as kW", missing = "–").
final class MetricFormatTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testWatts() {
        XCTAssertTrue(MetricFormat.watts(nil) == ("–", ""))
        XCTAssertTrue(MetricFormat.watts(.nan) == ("–", ""))
        XCTAssertTrue(MetricFormat.watts(1250, locale: us) == ("1,250", "W"))
        XCTAssertTrue(MetricFormat.watts(66.56, locale: us) == ("67", "W"))
        XCTAssertTrue(MetricFormat.watts(9999.4, locale: us) == ("9,999", "W"))
        XCTAssertTrue(MetricFormat.watts(10000, locale: us) == ("10.0", "kW"))
        XCTAssertTrue(MetricFormat.watts(12345.678, locale: us) == ("12.3", "kW"))
        XCTAssertTrue(MetricFormat.watts(-400, locale: us) == ("-400", "W"), "the sign is kept")
        XCTAssertTrue(MetricFormat.watts(-12345.678, locale: us) == ("-12.3", "kW"))
    }

    func testPercent() {
        XCTAssertTrue(MetricFormat.percent(nil) == ("–", ""))
        XCTAssertTrue(MetricFormat.percent(78.5, locale: us) == ("79", "%"), "half rounds up, not to even")
        XCTAssertTrue(MetricFormat.percent(50.5, locale: us) == ("51", "%"))
        XCTAssertTrue(MetricFormat.percent(100, locale: us) == ("100", "%"))
    }

    func testKWh() {
        XCTAssertTrue(MetricFormat.kWh(nil) == ("–", ""))
        XCTAssertTrue(MetricFormat.kWh(2.5, locale: us) == ("2.5", "kWh"))
        XCTAssertTrue(MetricFormat.kWh(10.999, locale: us) == ("11.0", "kWh"))
        XCTAssertTrue(MetricFormat.kWh(1234.56, locale: us) == ("1,234.6", "kWh"))
    }

    func testGroupingFollowsTheLocale() {
        XCTAssertEqual(MetricFormat.watts(1250, locale: Locale(identifier: "de_DE")).value, "1.250")
    }
}
