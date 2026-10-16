
//
// ConnectionUITests.swift
//
// Tests for connection UI state management
//

import XCTest
@testable import VictronKit

final class ConnectionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        print("ConnectionUITests setUp called")
    }

    func testShowsLiveViewForConnectedState() {
        print("testShowsLiveViewForConnectedState called")
        let state = ConnectionState.connected
        let hasConnected = true
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertTrue(showsLiveView, "Should show live view for .connected state when hasConnected is true")
    }
    
    func testShowsLiveViewForReconnectingState() {
        let state = ConnectionState.reconnecting
        let hasConnected = true
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertTrue(showsLiveView, "Should show live view for .reconnecting state when hasConnected is true")
    }

    func testShowsLiveViewForIdleStateWithPreviousConnection() {
        let state = ConnectionState.idle
        let hasConnected = true
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertFalse(showsLiveView, "Should not show live view for .idle state even when hasConnected is true")
    }

    func testShowsLiveViewForConnectingState() {
        let state = ConnectionState.connecting
        let hasConnected = true
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertFalse(showsLiveView, "Should not show live view for .connecting state")
    }

    func testShowsLiveViewForFailedState() {
        let state = ConnectionState.failed(.connectionRefused)
        let hasConnected = true
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertFalse(showsLiveView, "Should not show live view for .failed state")
    }

    func testShowsLiveViewForFirstConnection() {
        let state = ConnectionState.connected
        let hasConnected = false
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertTrue(showsLiveView, "Should show live view for .connected state on first connection")
    }

    func testShowsLiveViewForReconnectingWithoutPreviousConnection() {
        let state = ConnectionState.reconnecting
        let hasConnected = false
        
        let showsLiveView = ConnectionUI.showsLiveView(state: state, hasConnected: hasConnected)
        XCTAssertFalse(showsLiveView, "Should not show live view for .reconnecting state without previous connection")
    }
}