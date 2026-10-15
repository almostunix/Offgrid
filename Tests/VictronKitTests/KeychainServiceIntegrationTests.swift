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
    
    /// The stored item's attributes, read back from the Keychain.
    private func attributes(for key: String) throws -> [String: Any] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testServiceName,
            kSecAttrAccount as String: key,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &item), errSecSuccess)
        return try XCTUnwrap(item as? [String: Any])
    }

    // The macOS test run uses the file-based keychain, which doesn't store kSecAttrAccessible (the
    // data-protection keychain needs a signed app's entitlement). iOS always uses the data-protection
    // keychain, so check the attributes every add and update sends, then that items still round-trip.
    func testEveryItemIsThisDeviceOnly() {
        let attrs = KeychainService.protectionAttributes
        XCTAssertEqual(attrs[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertEqual(attrs[kSecAttrSynchronizable as String] as? Bool, false)
    }

    func testUpdateKeepsTheSecretReadable() throws {
        try keychainService.set("test_secret", for: "test_key_update")
        try keychainService.update("updated_secret", for: "test_key_update")
        XCTAssertEqual(try keychainService.get("test_key_update"), "updated_secret")
    }
}
