import XCTest
@testable import VictronKit

final class ConnectionIntegrationTests: XCTestCase {
    var profileStore: ConnectionProfileStore!
    var secretStore: FakeSecretStore!
    var temporaryDirectory: URL!

    override func setUp() async throws {
        secretStore = FakeSecretStore()

        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
        temporaryDirectory = tempDir.appendingPathComponent("cerbo_integration_test_profiles_\(UUID().uuidString)", isDirectory: true)

        // Create a mock file manager that uses our temporary directory
        let mockFileManager = MockFileManager(baseDirectory: temporaryDirectory)

        profileStore = try ConnectionProfileStore(
            secretStore: secretStore,
            fileManager: mockFileManager,
            profilesDirectory: temporaryDirectory
        )
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: temporaryDirectory)

        // Clear secrets
        secretStore.clear()
    }

    func testCompleteConnectionWorkflow() throws {
        // 1. Create a connection profile
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false,
            username: "testuser"
        )

        // 2. Save the profile with password
        try profileStore.save(profile, password: "testpassword")

        // 3. Load the profile
        let loadedProfile = try profileStore.loadProfile(id: profile.id)
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.name, "Test Cerbo")
        XCTAssertEqual(loadedProfile?.host, "192.168.1.100")
        XCTAssertEqual(loadedProfile?.port, 1883)
        XCTAssertFalse(loadedProfile?.useTLS ?? true)
        XCTAssertEqual(loadedProfile?.username, "testuser")

        // 4. Verify password is stored securely
        let retrievedPassword = try profileStore.password(for: loadedProfile!)
        XCTAssertEqual(retrievedPassword, "testpassword")

        // 5. Load all profiles
        let allProfiles = try profileStore.loadAllProfiles()
        XCTAssertEqual(allProfiles.count, 1)
        XCTAssertEqual(allProfiles[0].id, profile.id)

        // 6. Update the profile
        var updatedProfile = loadedProfile!
        updatedProfile.name = "Updated Cerbo"
        updatedProfile.host = "192.168.1.200"
        updatedProfile.port = 8883
        updatedProfile.useTLS = true

        try profileStore.updateProfile(updatedProfile, password: "newpassword")

        // 7. Verify the update
        let finalProfile = try profileStore.loadProfile(id: profile.id)
        XCTAssertEqual(finalProfile?.name, "Updated Cerbo")
        XCTAssertEqual(finalProfile?.host, "192.168.1.200")
        XCTAssertEqual(finalProfile?.port, 8883)
        XCTAssertTrue(finalProfile?.useTLS ?? false)

        // 8. Verify new password
        let finalPassword = try profileStore.password(for: finalProfile!)
        XCTAssertEqual(finalPassword, "newpassword")

        // 9. Mark as last used
        var usedProfile = finalProfile!
        usedProfile.markAsLastUsed()
        try profileStore.updateProfile(usedProfile, password: nil)

        // 10. Verify most recently used
        let mostRecent = try profileStore.getMostRecentlyUsedProfile()
        XCTAssertNotNil(mostRecent)
        XCTAssertEqual(mostRecent?.id, profile.id)

        // 11. Delete the profile
        try profileStore.deleteProfile(id: profile.id)

        // 12. Verify deletion
        let deletedProfile = try profileStore.loadProfile(id: profile.id)
        XCTAssertNil(deletedProfile)

        let deletedPassword = try profileStore.password(for: profile)
        XCTAssertNil(deletedPassword)
    }

    func testMultipleProfilesManagement() throws {
        // Create multiple profiles
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

        let profile3 = ConnectionProfile(
            name: "Cerbo 3",
            host: "192.168.1.102",
            port: 1883,
            useTLS: false,
            username: "user3"
        )

        // Save all profiles
        try profileStore.save(profile1, password: nil)
        try profileStore.save(profile2, password: "pass2")
        try profileStore.save(profile3, password: "pass3")

        // Load all profiles
        let allProfiles = try profileStore.loadAllProfiles()
        XCTAssertEqual(allProfiles.count, 3)

        // Verify they are sorted by name
        XCTAssertEqual(allProfiles[0].name, "Cerbo 1")
        XCTAssertEqual(allProfiles[1].name, "Cerbo 2")
        XCTAssertEqual(allProfiles[2].name, "Cerbo 3")

        // Mark profile2 as last used
        var profile2Updated = profile2
        profile2Updated.markAsLastUsed()
        try profileStore.updateProfile(profile2Updated, password: nil)

        // Verify profile2 is now most recent
        let mostRecent = try profileStore.getMostRecentlyUsedProfile()
        XCTAssertEqual(mostRecent?.id, profile2.id)

        // Delete profile2
        try profileStore.deleteProfile(id: profile2.id)

        // Verify only 2 profiles remain
        let remainingProfiles = try profileStore.loadAllProfiles()
        XCTAssertEqual(remainingProfiles.count, 2)
        XCTAssertFalse(remainingProfiles.contains { $0.id == profile2.id })

        // Delete all remaining profiles
        try profileStore.deleteAllProfiles()

        // Verify all profiles are gone
        let finalProfiles = try profileStore.loadAllProfiles()
        XCTAssertTrue(finalProfiles.isEmpty)
    }

    func testProfileWithPortalId() throws {
        // Create a profile
        let profile = ConnectionProfile(
            name: "Test Cerbo",
            host: "192.168.1.100",
            port: 1883,
            useTLS: false
        )

        // Save the profile
        try profileStore.save(profile, password: nil)

        // Simulate portal ID detection and update
        var profileWithPortalId = try profileStore.loadProfile(id: profile.id)!
        profileWithPortalId.updatePortalId("c0ffee000001")
        try profileStore.updateProfile(profileWithPortalId, password: nil)

        // Load and verify portal ID
        let loadedProfile = try profileStore.loadProfile(id: profile.id)
        XCTAssertEqual(loadedProfile?.portalId, "c0ffee000001")

        // Verify portal ID is preserved through updates
        var updatedProfile = loadedProfile!
        updatedProfile.name = "Updated Cerbo"
        try profileStore.updateProfile(updatedProfile, password: nil)

        let finalProfile = try profileStore.loadProfile(id: profile.id)
        XCTAssertEqual(finalProfile?.portalId, "c0ffee000001")
        XCTAssertEqual(finalProfile?.name, "Updated Cerbo")
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
