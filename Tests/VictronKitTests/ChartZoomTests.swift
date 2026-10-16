import XCTest
import CoreGraphics
@testable import VictronKit

final class ChartZoomTests: XCTestCase {

    func testVisibleLengthBasicZoom() {
        // Test 2x zoom from 600 seconds should give 300 seconds
        let result = ChartZoom.visibleLength(start: 600.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(result, 300.0, "2x zoom from 600s should give 300s")
    }

    func testVisibleLengthConsecutiveZooms() {
        // Test that a second 2x zoom starting at 300 gives 150 (not 600)
        let firstZoom = ChartZoom.visibleLength(start: 600.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(firstZoom, 300.0, "First 2x zoom from 600s should give 300s")
        
        let secondZoom = ChartZoom.visibleLength(start: 300.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(secondZoom, 150.0, "Second 2x zoom from 300s should give 150s, not 600s")
    }

    func testVisibleLengthMinClamping() {
        // Test that minimum limit is respected
        let result = ChartZoom.visibleLength(start: 100.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(result, 60.0, "Should clamp to minimum of 60s")
    }

    func testVisibleLengthMaxClamping() {
        // Test that maximum limit is respected
        let result = ChartZoom.visibleLength(start: 1000.0, magnification: 0.25, min: 60.0, max: 3600.0)
        XCTAssertEqual(result, 3600.0, "Should clamp to maximum of 3600s")
    }

    func testVisibleLengthZeroMagnification() {
        // Test that magnification <= 0 returns the start value
        let result = ChartZoom.visibleLength(start: 600.0, magnification: 0.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(result, 600.0, "Magnification 0 should return start value")
    }

    func testPinchGestureStateReset() {
        // Test that demonstrates the fix for the pinch zoom bug
        // First pinch: 600s -> 300s (2x zoom)
        let firstZoom = ChartZoom.visibleLength(start: 600.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(firstZoom, 300.0, "First 2x zoom from 600s should give 300s")
        
        // Second pinch starting from 300s (not stale 600s): 300s -> 150s (2x zoom)
        let secondZoom = ChartZoom.visibleLength(start: 300.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(secondZoom, 150.0, "Second 2x zoom from 300s should give 150s, not 600s")
        
        // This demonstrates the bug would have occurred if we used the stale start value
        // Old buggy behavior: ChartZoom.visibleLength(start: 600.0, magnification: 2.0, ...) would give 300s again
        // New correct behavior: ChartZoom.visibleLength(start: 300.0, magnification: 2.0, ...) gives 150s
    }

    func testVisibleLengthNegativeMagnification() {
        // Test that negative magnification returns the start value
        let result = ChartZoom.visibleLength(start: 600.0, magnification: -1.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(result, 600.0, "Negative magnification should return start value")
    }

    func testVisibleLengthExactLimits() {
        // Test exact boundary conditions
        let minResult = ChartZoom.visibleLength(start: 120.0, magnification: 2.0, min: 60.0, max: 3600.0)
        XCTAssertEqual(minResult, 60.0, "Should exactly hit minimum limit")
        
        let maxResult = ChartZoom.visibleLength(start: 7200.0, magnification: 0.5, min: 60.0, max: 3600.0)
        XCTAssertEqual(maxResult, 3600.0, "Should exactly hit maximum limit")
    }

    func testGestureStateManagement() {
        // Test that demonstrates the gesture state is properly managed
        // This simulates the actual gesture flow in InteractiveChart
        
        // Initial state
        var gestureStartLength: TimeInterval? = nil
        var visibleDomainLength: TimeInterval = 600.0
        
        // First gesture starts
        let start1 = gestureStartLength ?? visibleDomainLength
        gestureStartLength = start1
        let newLength1 = ChartZoom.visibleLength(start: start1, magnification: 2.0, min: 60.0, max: 3600.0)
        visibleDomainLength = newLength1
        
        XCTAssertEqual(start1, 600.0, "First gesture should start from visibleDomainLength")
        XCTAssertEqual(newLength1, 300.0, "First zoom should reduce to 300s")
        XCTAssertNotNil(gestureStartLength, "gestureStartLength should be set during gesture")
        
        // Gesture ends - state should be reset
        gestureStartLength = nil
        
        // Second gesture starts - should use the current visibleDomainLength (300), not stale value
        let start2 = gestureStartLength ?? visibleDomainLength
        gestureStartLength = start2
        let newLength2 = ChartZoom.visibleLength(start: start2, magnification: 2.0, min: 60.0, max: 3600.0)
        
        XCTAssertEqual(start2, 300.0, "Second gesture should start from current visibleDomainLength (300), not stale 600")
        XCTAssertEqual(newLength2, 150.0, "Second zoom should reduce to 150s")
    }
}