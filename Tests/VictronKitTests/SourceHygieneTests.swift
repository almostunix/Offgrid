import XCTest

/// T-60: an escaped interpolation ("\\(" in source, i.e. backslash backslash paren) renders as literal text on screen.
final class SourceHygieneTests: XCTestCase {
    func testNoEscapedBackslashInterpolationInApp() throws {
        // Tests/VictronKitTests/<this file> -> the package root
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let app = root.appendingPathComponent("App")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
        let escaped = "\\\\("   // the three characters  \  \  (
        var scanned = 0
        var failures: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            scanned += 1
            for (index, line) in try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines).enumerated()
            where line.contains(escaped) {
                failures.append(url.lastPathComponent + ":" + String(index + 1) + ": " + line.trimmingCharacters(in: .whitespaces))
            }
        }
        XCTAssertGreaterThan(scanned, 10, "the scan found too few App files")
        XCTAssertEqual(failures, [], "escaped interpolation renders as text:\n" + failures.joined(separator: "\n"))
    }
}
