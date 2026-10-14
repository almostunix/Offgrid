//
// KeychainServiceIntegrationTests.swift
//
// Integration tests for Keychain service using real Keychain.
//

import XCTest
@testable import VictronKit

final class KeychainServiceIntegrationTests: XCTestCase {
    var keychainService: KeychainService!
    let testServiceName = "com.almostunix.cerbo-app.test"
    
    override func setUp() {
        keychainService = KeychainService(service: testServiceName)
    }
    
    override func tearDown() {
        // Clean up test data
        let testKeys = ["test_key_1", "test_key_2", "test_key_update"]
        for key in testKeys {
            try? keychainService.remove(key)
        }
    }
    
    func testSecretStoreOperations() throws {
        let secret = "my_secure_secret"
        let key = "test_key_1"
        
        // Store secret
        try keychainService.set(secret, for: key)
        
        // Retrieve secret
        let retrievedSecret = try keychainService.get(key)
        XCTAssertEqual(retrievedSecret, secret)
        
        // Update secret
        let newSecret = "updated_secret"
        try keychainService.set(newSecret, for: key)
        
        let updatedSecret = try keychainService.get(key)
        XCTAssertEqual(updatedSecret, newSecret)
        
        // Remove secret
        try keychainService.remove(key)
        
        let removedSecret = try keychainService.get(key)
        XCTAssertNil(removedSecret)
    }
}
