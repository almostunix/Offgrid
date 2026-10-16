import XCTest
@testable import VictronKit

/// Tests for TileOrder functionality
final class TileOrderTests: XCTestCase {
    
    func testMoveItemToTargetPosition() {
        let items = ["A", "B", "C"]
        let result = TileOrder.move(items, moving: "C", onto: "B")
        XCTAssertEqual(result, ["A", "C", "B"])
    }
    
    func testMoveItemToEnd() {
        let items = ["A", "B", "C"]
        let result = TileOrder.move(items, moving: "A", onto: "C")
        XCTAssertEqual(result, ["B", "C", "A"])
    }
    
    func testMoveItemToBeginning() {
        let items = ["A", "B", "C"]
        let result = TileOrder.move(items, moving: "C", onto: "A")
        XCTAssertEqual(result, ["C", "A", "B"])
    }
    
    func testMoveOntoItselfReturnsUnchanged() {
        let items = ["A", "B", "C"]
        let result = TileOrder.move(items, moving: "B", onto: "B")
        XCTAssertEqual(result, items)
    }
    
    func testMoveUnknownItemReturnsUnchanged() {
        let items = ["A", "B", "C"]
        let result = TileOrder.move(items, moving: "D", onto: "B")
        XCTAssertEqual(result, items)
    }
    
    func testMoveToUnknownTargetReturnsUnchanged() {
        let items = ["A", "B", "C"]
        let result = TileOrder.move(items, moving: "B", onto: "D")
        XCTAssertEqual(result, items)
    }
}
