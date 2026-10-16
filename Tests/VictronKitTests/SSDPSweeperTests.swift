//
// SSDPSweeperTests.swift
//
// Tests for SSDP sweeper functionality.
//

import XCTest
@testable import VictronKit

final class SSDPSweeperTests: XCTestCase {

    class FakeTransport: DatagramTransport {
        var onReceive: ((Data, String) -> Void)?
        var sentPackets: [(host: String, port: UInt16)] = []
        var injectedReplies: [(data: Data, host: String)] = []
        var replyIndex = 0
        
        func send(_ data: Data, to host: String, port: UInt16) {
            sentPackets.append((host: host, port: port))
        }
        
        func close() {
            // No-op for testing
        }
        
        func injectReply(_ data: Data, from host: String) {
            injectedReplies.append((data: data, host: host))
        }
        
        func triggerInjectedReplies() {
            guard let onReceive = onReceive else { return }
            for reply in injectedReplies {
                onReceive(reply.data, reply.host)
            }
            injectedReplies.removeAll()
        }
    }

    func testOneRequestPerHostToPort1900() {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.1", "192.168.1.2", "192.168.1.3"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        var capturedResults: [(portalId: String, location: URL, host: String)] = []
        let expectation = self.expectation(description: "Sweep completion")
        sweeper.sweep(hosts: hosts, request: request) { results in
            capturedResults = results
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have sent one request per host
        XCTAssertEqual(transport.sentPackets.count, 3)
        
        // All requests should be to port 1900
        for packet in transport.sentPackets {
            XCTAssertEqual(packet.port, 1900)
        }
        
        // Requests should be to the correct hosts
        XCTAssertEqual(transport.sentPackets[0].host, "192.168.1.1")
        XCTAssertEqual(transport.sentPackets[1].host, "192.168.1.2")
        XCTAssertEqual(transport.sentPackets[2].host, "192.168.1.3")
    }

    func testVictronReplyFromHostIsReturned() throws {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.20"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        // Load a valid Victron SSDP reply for 192.168.1.20
        let fixtureURL = Bundle.module.url(forResource: "victron_ssdp_reply_192_168_1_20", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let replyText = try String(contentsOf: fixtureURL)
        let replyData = replyText.data(using: .utf8)!
        
        var capturedResults: [(portalId: String, location: URL, host: String)] = []
        let expectation = self.expectation(description: "Sweep completion")
        sweeper.sweep(hosts: hosts, request: request) { results in
            capturedResults = results
            expectation.fulfill()
        }
        
        // Inject the reply before the sweep completes
        transport.injectReply(replyData, from: "192.168.1.20")
        transport.triggerInjectedReplies()
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have one result with the portal ID
        XCTAssertEqual(capturedResults.count, 1)
        XCTAssertEqual(capturedResults[0].portalId, "c0ffee000001")
        XCTAssertEqual(capturedResults[0].host, "192.168.1.20")
    }

    func testNonVictronReplyIsIgnored() throws {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.200"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        // Load a non-Victron SSDP reply
        let fixtureURL = Bundle.module.url(forResource: "non_victron_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let replyText = try String(contentsOf: fixtureURL)
        let replyData = replyText.data(using: .utf8)!
        
        var capturedResults: [(portalId: String, location: URL, host: String)] = []
        let expectation = self.expectation(description: "Sweep completion")
        sweeper.sweep(hosts: hosts, request: request) { results in
            capturedResults = results
            expectation.fulfill()
        }
        
        // Inject the reply
        transport.injectReply(replyData, from: "192.168.1.200")
        transport.triggerInjectedReplies()
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have no results (non-Victron reply ignored)
        XCTAssertEqual(capturedResults.count, 0)
    }

    func testVictronReplyWithWrongLocationIsIgnored() throws {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.100"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        // Load a valid Victron SSDP reply but check with wrong host
        let fixtureURL = Bundle.module.url(forResource: "victron_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let replyText = try String(contentsOf: fixtureURL)
        let replyData = replyText.data(using: .utf8)!
        
        var capturedResults: [(portalId: String, location: URL, host: String)] = []
        let expectation = self.expectation(description: "Sweep completion")
        sweeper.sweep(hosts: hosts, request: request) { results in
            capturedResults = results
            expectation.fulfill()
        }
        
        // Inject the reply from a different host than the one we're sweeping
        transport.injectReply(replyData, from: "192.168.1.999")
        transport.triggerInjectedReplies()
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have no results (LOCATION host doesn't match sender)
        XCTAssertEqual(capturedResults.count, 0)
    }

    func testDuplicatePortalIdsGiveOneResult() throws {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.20", "192.168.1.21"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        // Load a valid Victron SSDP reply for 192.168.1.20
        let fixtureURL = Bundle.module.url(forResource: "victron_ssdp_reply_192_168_1_20", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let replyText = try String(contentsOf: fixtureURL)
        let replyData = replyText.data(using: .utf8)!
        
        var capturedResults: [(portalId: String, location: URL, host: String)] = []
        let expectation = self.expectation(description: "Sweep completion")
        sweeper.sweep(hosts: hosts, request: request) { results in
            capturedResults = results
            expectation.fulfill()
        }
        
        // Give the sweep time to start and send requests
        Thread.sleep(forTimeInterval: 0.05)
        
        // Inject the same reply from both hosts (same portal ID)
        transport.injectReply(replyData, from: "192.168.1.20")
        transport.injectReply(replyData, from: "192.168.1.21")
        transport.triggerInjectedReplies()
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have only one result (first reply wins)
        XCTAssertEqual(capturedResults.count, 1, "Expected 1 result, got \(capturedResults.count)")
        XCTAssertEqual(capturedResults[0].portalId, "c0ffee000001")
    }

    func testCompletionFiresOnceAfterListenTimeout() {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.1"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        let expectation = self.expectation(description: "Sweep completion")
        var completionCount = 0
        sweeper.sweep(hosts: hosts, request: request) { results in
            completionCount += 1
            expectation.fulfill()
        }
        
        // Wait for completion to fire
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have fired exactly once
        XCTAssertEqual(completionCount, 1)
    }

    func testReplyInjectedAfterCompletionIsIgnored() throws {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.20"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        // Load a valid Victron SSDP reply
        let fixtureURL = Bundle.module.url(forResource: "victron_ssdp_reply", withExtension: "txt", subdirectory: "Fixtures/discovery")!
        let replyText = try String(contentsOf: fixtureURL)
        let replyData = replyText.data(using: .utf8)!
        
        var capturedResults: [(portalId: String, location: URL, host: String)] = []
        let expectation = self.expectation(description: "Sweep completion")
        sweeper.sweep(hosts: hosts, request: request) { results in
            capturedResults = results
            expectation.fulfill()
        }
        
        // Wait for completion to fire
        Thread.sleep(forTimeInterval: 0.3)
        
        // Inject reply after completion (should be ignored)
        transport.injectReply(replyData, from: "192.168.1.20")
        transport.triggerInjectedReplies()
        
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Should have no results (reply came after completion)
        XCTAssertEqual(capturedResults.count, 0)
    }

    func testTransportIsClosedAfterCompletion() {
        let transport = FakeTransport()
        let sweeper = SSDPSweeper(transport: transport, interval: 0, listen: 0.2)
        
        let hosts = ["192.168.1.1"]
        let request = { (ip: String) -> String in return "M-SEARCH * HTTP/1.1\r\nHOST: \(ip):1900\r\nST: test\r\n\r\n" }
        
        var completionCalled = false
        sweeper.sweep(hosts: hosts, request: request) { results in
            completionCalled = true
        }
        
        // Wait for completion
        while !completionCalled {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Transport should be closed (onReceive should be nil)
        XCTAssertNil(transport.onReceive)
    }
}