//
// ConnectionProfileStoreTests.swift
//
// Tests for connection profile storage.
//

import XCTest
@testable import VictronKit

final class ConnectionProfileStoreTests: XCTestCase {
    var profileStore: ConnectionProfileStore!
    var secretStore: FakeSecretStore!
    var temporaryDirectory: URL!
    var testDate: Date!
    
    override func setUp() async throws {
        secretStore = FakeSecretStore()
        testDate = Date()
        
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
        temporaryDirectory = tempDir.appendingPathComponent("cerbo_test_profiles_\(UUID().uuidString)", isDirectory: true)
        
        // Create a mock file manager that uses our temporary directory
        let mockFileManager = MockFileManager(baseDirectory: temporaryDirectory)
        
        // Create a controlled date provider
        let nowProvider: () -> Date = { self.testDate }
        
        profileStore = try ConnectionProfileStore(
            secretStore: secretStore,
            fileManager: mockFileManager,
            profilesDirectory: temporaryDirectory,
            now: nowProvider
        )
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: temporaryDirectory)
        
        // Clear secrets
        secretStore.clear()
    }
    
    func testCreateProfile() throws {
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "testuser"
        )
        
        XCTAssertNotNil(profile.id)
        XCTAssertEqual(profile.name, "Test Cerbo")
        XCTAssertEqual(profile.host, "192.168.1.100")
        XCTAssertEqual(profile.port, 1883)
        XCTAssertFalse(profile.useTLS)
        XCTAssertEqual(profile.username, "testuser")
        XCTAssertNil(profile.passwordKeychainReference)
        XCTAssertNotNil(profile.createdAt)
        XCTAssertNotNil(profile.updatedAt)
    }
    
    func testSaveAndLoadProfileWithPassword() throws {
        // Create a profile
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "testuser"
        )
        
        // Save with password
        try profileStore.save(profile, password: "testpass")
        
        // Load the profile
        let loadedProfile = try profileStore.loadProfile(id: profile.id)
        
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.id, profile.id)
        XCTAssertEqual(loadedProfile?.name, "Test Cerbo")
        XCTAssertEqual(loadedProfile?.host, "192.168.1.100")
        XCTAssertEqual(loadedProfile?.port, 1883)
        XCTAssertFalse(loadedProfile?.useTLS ?? true)
        XCTAssertEqual(loadedProfile?.username, "testuser")
        XCTAssertEqual(loadedProfile?.passwordKeychainReference, profile.id.uuidString)
        
        // Verify password can be retrieved
        let retrievedPassword = try profileStore.password(for: loadedProfile!)
        XCTAssertEqual(retrievedPassword, "testpass")
    }
    
    func testSaveAndLoadProfileWithoutPassword() throws {
        // Create a profile
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false
        )
        
        // Save without password
        try profileStore.save(profile, password: nil)
        
        // Load the profile
        let loadedProfile = try profileStore.loadProfile(id: profile.id)
        
        XCTAssertNotNil(loadedProfile)
        XCTAssertNil(loadedProfile?.passwordKeychainReference)
        
        // Verify no password can be retrieved
        let retrievedPassword = try profileStore.password(for: loadedProfile!)
        XCTAssertNil(retrievedPassword)
    }
    
    func testPasswordNotInJSON() throws {
        // Create a profile
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "testuser"
        )
        
        // Save with password
        try profileStore.save(profile, password: "testpass")
        
        // Read the JSON file
        let url = temporaryDirectory.appendingPathComponent("profile_\(profile.id.uuidString).json")
        let data = try Data(contentsOf: url)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Verify password is not in the JSON
        XCTAssertFalse(jsonString.contains("testpass"))
        
        // Verify password reference is in the JSON
        XCTAssertTrue(jsonString.contains("passwordKeychainReference"))
    }
    
    func testLoadAllProfiles() throws {
        // Create and save multiple profiles
        let profile1 = ConnectionProfile(
            name: "Cerbo 1",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false
        )
        
        let profile2 = ConnectionProfile(
            name: "Cerbo 2",
            host: "192.168.1.101",
            port: 8883,
            useTLS: true,
            username: "user2"
        )
        
        try profileStore.save(profile1, password: nil)
        try profileStore.save(profile2, password: "pass2")
        
        // Load all profiles
        let allProfiles = try profileStore.loadAllProfiles()
        
        XCTAssertEqual(allProfiles.count, 2)
        
        // Verify profiles are sorted by name (since neither has been used)
        XCTAssertEqual(allProfiles[0].name, "Cerbo 1")
        XCTAssertEqual(allProfiles[1].name, "Cerbo 2")
    }
    
    func testUpdateProfileWithNewPassword() throws {
        // Create and save a profile
        let profile = ConnectionProfile(
            name: "Original Name",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "user"
        )
        
        try profileStore.save(profile, password: "oldpass")
        
        // Advance time
        testDate = testDate.addingTimeInterval(1)
        
        // Update the profile with new password
        var updatedProfile = profile
        updatedProfile.name = "Updated Name"
        updatedProfile.host = "192.168.1.200"
        
        try profileStore.updateProfile(updatedProfile, password: "newpass")
        
        // Load and verify the updated profile
        let loadedProfile = try profileStore.loadProfile(id: profile.id)
        
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.name, "Updated Name")
        XCTAssertEqual(loadedProfile?.host, "192.168.1.200")
        
        // Verify new password can be retrieved
        let retrievedPassword = try profileStore.password(for: loadedProfile!)
        XCTAssertEqual(retrievedPassword, "newpass")
        
        // Verify old password is gone
        let oldPassword = try secretStore.get(profile.id.uuidString)
        XCTAssertEqual(oldPassword, "newpass") // Should be updated, not replaced
    }
    
    func testUpdateProfileWithoutPasswordKeepsOldPassword() throws {
        // Create and save a profile with password
        let profile = ConnectionProfile(
            name: "Original Name",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "user"
        )
        
        try profileStore.save(profile, password: "originalpass")
        
        // Advance time
        testDate = testDate.addingTimeInterval(1)
        
        // Update the profile without providing a new password
        var updatedProfile = profile
        updatedProfile.name = "Updated Name"
        
        try profileStore.updateProfile(updatedProfile, password: nil)
        
        // Load and verify the updated profile
        let loadedProfile = try profileStore.loadProfile(id: profile.id)
        
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.name, "Updated Name")
        
        // Verify old password is still retrievable
        let retrievedPassword = try profileStore.password(for: loadedProfile!)
        XCTAssertEqual(retrievedPassword, "originalpass")
    }
    
    func testDeleteProfile() throws {
        // Create and save a profile
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "user"
        )
        
        try profileStore.save(profile, password: "testpass")
        
        // Verify profile exists
        let loadedBefore = try profileStore.loadProfile(id: profile.id)
        XCTAssertNotNil(loadedBefore)
        
        // Verify password exists
        let passwordBefore = try profileStore.password(for: loadedBefore!)
        XCTAssertEqual(passwordBefore, "testpass")
        
        // Delete the profile
        try profileStore.deleteProfile(id: profile.id)
        
        // Verify profile is deleted
        let loadedAfter = try profileStore.loadProfile(id: profile.id)
        XCTAssertNil(loadedAfter)
        
        // Verify password is deleted
        let passwordAfter = try profileStore.password(for: profile)
        XCTAssertNil(passwordAfter)
    }
    
    func testDeleteAllProfiles() throws {
        // Create and save multiple profiles
        let profile1 = ConnectionProfile(
            name: "Cerbo 1",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false
        )
        
        let profile2 = ConnectionProfile(
            name: "Cerbo 2",
            host: "192.168.1.101",
            port: 8883,
            useTLS: true,
            username: "user2"
        )
        
        try profileStore.save(profile1, password: nil)
        try profileStore.save(profile2, password: "pass2")
        
        // Verify profiles exist
        let allProfilesBefore = try profileStore.loadAllProfiles()
        XCTAssertEqual(allProfilesBefore.count, 2)
        
        // Delete all profiles
        try profileStore.deleteAllProfiles()
        
        // Verify all profiles are deleted
        let allProfilesAfter = try profileStore.loadAllProfiles()
        XCTAssertEqual(allProfilesAfter.count, 0)
        
        // Verify passwords are deleted
        let password1 = try profileStore.password(for: profile1)
        let password2 = try profileStore.password(for: profile2)
        XCTAssertNil(password1)
        XCTAssertNil(password2)
    }
    
    func testGetMostRecentlyUsedProfile() throws {
        // Create and save multiple profiles
        let profile1 = ConnectionProfile(
            name: "Cerbo 1",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false
        )
        
        let profile2 = ConnectionProfile(
            name: "Cerbo 2",
            host: "192.168.1.101",
            port: 8883,
            useTLS: true
        )
        
        try profileStore.save(profile1, password: nil)
        try profileStore.save(profile2, password: nil)
        
        // Mark profile2 as last used
        var profile2Updated = profile2
        profile2Updated.markAsLastUsed(now: { self.testDate })
        try profileStore.updateProfile(profile2Updated, password: nil)
        
        // Get most recently used profile
        let mostRecent = try profileStore.getMostRecentlyUsedProfile()
        
        XCTAssertNotNil(mostRecent)
        XCTAssertEqual(mostRecent?.id, profile2.id)
        XCTAssertEqual(mostRecent?.name, "Cerbo 2")
    }
    
    func testDuplicateProfileName() throws {
        // Create and save a profile
        let profile1 = ConnectionProfile(
            name: "Duplicate Name",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false
        )
        
        try profileStore.save(profile1, password: nil)
        
        // Try to save another profile with the same name
        let profile2 = ConnectionProfile(
            name: "Duplicate Name",
            host: "192.168.1.101",
            port: 8883,
            useTLS: true
        )
        
        XCTAssertThrowsError(try profileStore.save(profile2, password: nil)) { error in
            let profileError = error as? ProfileError
            switch profileError {
            case .duplicateName:
                // Error is as expected
                break
            default:
                XCTFail("Expected ProfileError.duplicateName, got \(String(describing: profileError))")
            }
        }
    }
    
    func testProfileEquality() {
        let date = Date()
        
        let profile1 = ConnectionProfile(
            id: UUID(),
            name: "Test",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "user",
            passwordKeychainReference: "ref",
            portalId: "portal1",
            lastUsed: date,
            createdAt: date,
            updatedAt: date
        )
        
        let profile2 = ConnectionProfile(
            id: profile1.id,
            name: profile1.name,
            host: profile1.host,
            port: profile1.port,
            useTLS: profile1.useTLS,
            username: profile1.username,
            passwordKeychainReference: profile1.passwordKeychainReference,
            portalId: profile1.portalId,
            lastUsed: profile1.lastUsed,
            createdAt: profile1.createdAt,
            updatedAt: profile1.updatedAt
        )
        
        XCTAssertEqual(profile1, profile2)
        
        // Test inequality
        var profile3 = profile1
        profile3.name = "Different"
        XCTAssertNotEqual(profile1, profile3)
    }
}

/// Mock FileManager for testing
private class MockFileManager: FileManager {
    private let baseDirectory: URL
    
    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
        super.init()
        
        // Create the base directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: baseDirectory.path) {
            try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        if directory == .documentDirectory && domainMask == .userDomainMask {
            return [baseDirectory]
        }
        return super.urls(for: directory, in: domainMask)
    }
}
