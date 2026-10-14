//
// VictronKitTests
//
// Tests for ReadOnlyPublisher
//

import XCTest
@testable import VictronKit

final class ReadOnlyPublisherTests: XCTestCase {
    func testKeepaliveMessage() throws {
        // Test that keepalive messages can be sent
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        try publisher.keepalive()
        
        // Verify the keepalive message was sent
        XCTAssertEqual(sentTopic, "R/c0ffee000001/keepalive")
        XCTAssertEqual(sentPayload, "")
    }
    
    func testValidReadTopic() throws {
        // Test that valid R/<portalId>/... topics are allowed
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "R/c0ffee000001/system/0/Serial"
        let payload = "test"
        
        try publisher.publish(topic: topic, payload: payload)
        
        // Verify the message was sent
        XCTAssertEqual(sentTopic, topic)
        XCTAssertEqual(sentPayload, payload)
    }
    
    func testWriteTopicRejected() throws {
        // Test that W/ topics are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "W/c0ffee000001/some/write"
        let payload = "write"
        
        XCTAssertThrowsError(try publisher.publish(topic: topic, payload: payload)) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, topic)
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testNotificationTopicRejected() throws {
        // Test that N/ topics are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "N/c0ffee000001/some/notification"
        let payload = "notify"
        
        XCTAssertThrowsError(try publisher.publish(topic: topic, payload: payload)) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, topic)
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testEmptyTopicRejected() throws {
        // Test that empty topics are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        XCTAssertThrowsError(try publisher.publish(topic: "", payload: "empty")) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, "")
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testRSlashOnlyRejected() throws {
        // Test that "R/" alone is rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        XCTAssertThrowsError(try publisher.publish(topic: "R/", payload: "test")) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, "R/")
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testAnotherPortalsTopicRejected() throws {
        // Test that R/<other-portal-id>/... topics are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "R/otherportal/keepalive"
        let payload = "test"
        
        XCTAssertThrowsError(try publisher.publish(topic: topic, payload: payload)) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, topic)
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testWhitespaceTopicRejected() throws {
        // Test that whitespace-only topics are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        XCTAssertThrowsError(try publisher.publish(topic: "   ", payload: "test")) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, "   ")
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testWhitespacePrefixTopicRejected() throws {
        // Test that topics with leading whitespace are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        XCTAssertThrowsError(try publisher.publish(topic: " W/c0ffee000001/keepalive", payload: "test")) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, " W/c0ffee000001/keepalive")
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testEmptyPortalIdRejected() throws {
        // Test that empty portal ID is rejected
        let send = { (topic: String, payload: String) in
        }
        
        XCTAssertThrowsError(try ReadOnlyPublisher(portalId: "", send: send)) { error in
            guard case ReadOnlyPublisher.Error.invalidPortalId(let invalidId) = error else {
                XCTFail("Expected invalidPortalId error")
                return
            }
            XCTAssertEqual(invalidId, "")
        }
    }
    
    func testPortalIdWithSlashRejected() throws {
        // Test that portal ID with slash is rejected
        let send = { (topic: String, payload: String) in
        }
        
        XCTAssertThrowsError(try ReadOnlyPublisher(portalId: "c0ffee/000001", send: send)) { error in
            guard case ReadOnlyPublisher.Error.invalidPortalId(let invalidId) = error else {
                XCTFail("Expected invalidPortalId error")
                return
            }
            XCTAssertEqual(invalidId, "c0ffee/000001")
        }
    }
    
    func testPortalIdWithPlusRejected() throws {
        // Test that portal ID with plus is rejected
        let send = { (topic: String, payload: String) in
        }
        
        XCTAssertThrowsError(try ReadOnlyPublisher(portalId: "c0ffee+000001", send: send)) { error in
            guard case ReadOnlyPublisher.Error.invalidPortalId(let invalidId) = error else {
                XCTFail("Expected invalidPortalId error")
                return
            }
            XCTAssertEqual(invalidId, "c0ffee+000001")
        }
    }
    
    func testPortalIdWithHashRejected() throws {
        // Test that portal ID with hash is rejected
        let send = { (topic: String, payload: String) in
        }
        
        XCTAssertThrowsError(try ReadOnlyPublisher(portalId: "c0ffee#000001", send: send)) { error in
            guard case ReadOnlyPublisher.Error.invalidPortalId(let invalidId) = error else {
                XCTFail("Expected invalidPortalId error")
                return
            }
            XCTAssertEqual(invalidId, "c0ffee#000001")
        }
    }
    
    func testPortalIdWithWhitespaceRejected() throws {
        // Test that portal ID with whitespace is rejected
        let send = { (topic: String, payload: String) in
        }
        
        XCTAssertThrowsError(try ReadOnlyPublisher(portalId: "c0ffee 000001", send: send)) { error in
            guard case ReadOnlyPublisher.Error.invalidPortalId(let invalidId) = error else {
                XCTFail("Expected invalidPortalId error")
                return
            }
            XCTAssertEqual(invalidId, "c0ffee 000001")
        }
    }
    
    func testTopicWithPlusRejected() throws {
        // Test that topics with + wildcard are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "R/c0ffee000001/system/+"
        let payload = "test"
        
        XCTAssertThrowsError(try publisher.publish(topic: topic, payload: payload)) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, topic)
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testTopicWithHashRejected() throws {
        // Test that topics with # wildcard are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "R/c0ffee000001/system/#"
        let payload = "test"
        
        XCTAssertThrowsError(try publisher.publish(topic: topic, payload: payload)) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, topic)
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
    
    func testTopicWithNulRejected() throws {
        // Test that topics with NUL character are rejected
        var sentTopic: String?
        var sentPayload: String?
        
        let send = { (topic: String, payload: String) in
            sentTopic = topic
            sentPayload = payload
        }
        
        let publisher = try ReadOnlyPublisher(portalId: "c0ffee000001", send: send)
        
        let topic = "R/c0ffee000001/system\0/Serial"
        let payload = "test"
        
        XCTAssertThrowsError(try publisher.publish(topic: topic, payload: payload)) { error in
            guard case ReadOnlyPublisher.Error.notAllowed(let rejectedTopic) = error else {
                XCTFail("Expected notAllowed error")
                return
            }
            XCTAssertEqual(rejectedTopic, topic)
        }
        
        // Verify nothing was sent
        XCTAssertNil(sentTopic)
        XCTAssertNil(sentPayload)
    }
}
