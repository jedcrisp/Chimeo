import Foundation
import FirebaseFirestore

// MARK: - Organization Following Service
class OrganizationFollowingService: ObservableObject {
    
    // MARK: - Following Management
    func followOrganization(_ organizationId: String, userId: String) async throws {
        print("👥 Following organization: \(organizationId)")
        print("   User: \(userId)")
        
        let db = Firestore.firestore()
        
        // BULLETPROOF: Ensure user document exists with FCM token before following
        print("🔧 BULLETPROOF: Ensuring user document exists with FCM token...")
        await ensureUserDocumentWithFCMToken(userId: userId)
        
        // NEW LOGIC: Only update user's followedOrganizations array
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        guard let userData = userDoc.data() else {
            print("❌ User document not found")
            throw NSError(domain: "OrganizationFollowingService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
        }
        
        var followedOrganizations = userData["followedOrganizations"] as? [String] ?? []
        
        if !followedOrganizations.contains(organizationId) {
            followedOrganizations.append(organizationId)
            
            try await userRef.updateData([
                "followedOrganizations": followedOrganizations,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Added organization \(organizationId) to user's followedOrganizations array")
        } else {
            print("ℹ️ User already follows organization \(organizationId)")
        }
        
        print("✅ Successfully followed organization")
    }
    
    func unfollowOrganization(_ organizationId: String, userId: String) async throws {
        print("👥 Unfollowing organization: \(organizationId)")
        print("   User: \(userId)")
        
        let db = Firestore.firestore()
        
        // NEW LOGIC: Only update user's followedOrganizations array
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        guard let userData = userDoc.data() else {
            print("❌ User document not found")
            throw NSError(domain: "OrganizationFollowingService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
        }
        
        var followedOrganizations = userData["followedOrganizations"] as? [String] ?? []
        
        if let index = followedOrganizations.firstIndex(of: organizationId) {
            followedOrganizations.remove(at: index)
            
            try await userRef.updateData([
                "followedOrganizations": followedOrganizations,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Removed organization \(organizationId) from user's followedOrganizations array")
        } else {
            print("ℹ️ User was not following organization \(organizationId)")
        }
        
        print("✅ Successfully unfollowed organization")
    }
    
    // MARK: - Utility Functions for Fixing Follower Counts
    
    func fixOrganizationFollowerCount(_ organizationId: String) async throws {
        print("🔧 Fixing follower count for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Count actual followers in the subcollection
        let followersSnapshot = try await db.collection("organizations")
            .document(organizationId)
            .collection("followers")
            .getDocuments()
        
        let actualCount = followersSnapshot.documents.count
        print("   📊 Actual followers in subcollection: \(actualCount)")
        
        // Update the organization's follower count
        let orgRef = db.collection("organizations").document(organizationId)
        try await orgRef.updateData([
            "followerCount": actualCount,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ Fixed follower count to \(actualCount)")
    }
    
    func isFollowingOrganization(_ organizationId: String, userId: String) async throws -> Bool {
        print("🔍 Checking if user \(userId) is following organization \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Check the subcollection document for the specific organization
        let userOrgRef = db.collection("users").document(userId)
            .collection("followedOrganizations").document(organizationId)
        
        let doc = try await userOrgRef.getDocument()
        
        if doc.exists, let data = doc.data() {
            let isFollowing = data["isFollowing"] as? Bool ?? false
            print("   ✅ Is following: \(isFollowing)")
            return isFollowing
        } else {
            print("   ❌ Organization following document not found")
            return false
        }
    }
    
    // MARK: - Followed Organizations
    func getFollowedOrganizations(userId: String) async throws -> [Organization] {
        print("📋 Fetching followed organizations for user: \(userId)")
        
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        guard let userData = userDoc.data() else {
            print("   ❌ User document not found")
            return []
        }
        
        let followedOrganizationIds = userData["followedOrganizations"] as? [String] ?? []
        
        if followedOrganizationIds.isEmpty {
            print("   ✅ No followed organizations")
            return []
        }
        
        var organizations: [Organization] = []
        
        // Fetch each organization
        for orgId in followedOrganizationIds {
            do {
                let orgDoc = try await db.collection("organizations").document(orgId).getDocument()
                if let orgData = orgDoc.data() {
                    if let organization = try parseOrganizationFromFirestore(docId: orgDoc.documentID, data: orgData) {
                        organizations.append(organization)
                    }
                }
            } catch {
                print("   ⚠️ Warning: Could not fetch organization \(orgId): \(error)")
            }
        }
        
        print("   ✅ Found \(organizations.count) followed organizations")
        return organizations
    }
    
    func getOrganizationFollowers(_ organizationId: String) async throws -> [String] {
        print("👥 Fetching followers for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Query all users who have this organization in their followedOrganizations array
        let snapshot = try await db.collection("users")
            .whereField("followedOrganizations", arrayContains: organizationId)
            .getDocuments()
        
        let followers = snapshot.documents.map { $0.documentID }
        
        print("   ✅ Found \(followers.count) followers")
        return followers
    }
    
    // MARK: - Group Preferences
    func updateUserGroupPreferences(_ preferences: UserGroupPreferences) async throws {
        print("⚙️ Updating user group preferences")
        print("   User: \(preferences.userId)")
        print("   Organization: \(preferences.organizationId)")
        print("   Group: \(preferences.groupId)")
        print("   Alerts enabled: \(preferences.alertsEnabled)")
        
        let db = Firestore.firestore()
        let preferenceId = "\(preferences.userId)_\(preferences.organizationId)_\(preferences.groupId)"
        
        let preferenceData: [String: Any] = [
            "userId": preferences.userId,
            "organizationId": preferences.organizationId,
            "groupId": preferences.groupId,
            "alertsEnabled": preferences.alertsEnabled,
            "createdAt": preferences.createdAt,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("userGroupPreferences").document(preferenceId).setData(preferenceData)
        
        print("✅ User group preferences updated successfully")
    }
    
    func getUserGroupPreferences(userId: String, organizationId: String) async throws -> [UserGroupPreferences] {
        print("⚙️ Fetching user group preferences")
        print("   User: \(userId)")
        print("   Organization: \(organizationId)")
        
        let db = Firestore.firestore()
        let snapshot = try await db.collection("userGroupPreferences")
            .whereField("userId", isEqualTo: userId)
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        
        var preferences: [UserGroupPreferences] = []
        
        for document in snapshot.documents {
            if let preference = parseUserGroupPreferences(from: document.data()) {
                preferences.append(preference)
            }
        }
        
        print("   ✅ Found \(preferences.count) group preferences")
        return preferences
    }
    
    // MARK: - Following Statistics
    func getFollowingStatistics(userId: String) async throws -> FollowingStatistics {
        print("📊 Fetching following statistics for user: \(userId)")
        
        let followedOrganizations = try await getFollowedOrganizations(userId: userId)
        let organizationCount = followedOrganizations.count
        
        // Calculate total groups
        var totalGroups = 0
        for organization in followedOrganizations {
            totalGroups += organization.groupCount
        }
        
        // Get preferences count
        let db = Firestore.firestore()
        let preferencesSnapshot = try await db.collection("userGroupPreferences")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let preferencesCount = preferencesSnapshot.documents.count
        
        let statistics = FollowingStatistics(
            organizationsFollowing: organizationCount,
            totalGroupsAvailable: totalGroups,
            preferencesSet: preferencesCount,
            lastUpdated: Date()
        )
        
        print("✅ Following statistics compiled successfully")
        print("   📊 Organizations: \(organizationCount)")
        print("   🏢 Groups: \(totalGroups)")
        print("   ⚙️ Preferences: \(preferencesCount)")
        
        return statistics
    }
    
    // MARK: - Helper Methods
    private func parseOrganizationFromFirestore(docId: String, data: [String: Any]) throws -> Organization? {
        let name = data["name"] as? String ?? "Unknown"
        let type = data["type"] as? String ?? "business"
        let description = data["description"] as? String ?? ""
        let website = data["website"] as? String
        let phone = data["phone"] as? String
        let email = data["email"] as? String ?? ""
        let address = data["address"] as? String ?? ""
        let city = data["city"] as? String ?? ""
        let state = data["state"] as? String ?? ""
        let zipCode = data["zipCode"] as? String ?? ""
        let verified = data["verified"] as? Bool ?? false
        let followerCount = data["followerCount"] as? Int ?? 0
        let logoURL = data["logoURL"] as? String
        let adminIds = data["adminIds"] as? [String: Bool] ?? [:]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return Organization(
            id: docId,
            name: name,
            type: type,
            description: description,
            location: Location(
                latitude: 33.1032, // Default coordinates
                longitude: -96.6705,
                address: address,
                city: city,
                state: state,
                zipCode: zipCode
            ),
            verified: verified,
            followerCount: followerCount,
            logoURL: logoURL,
            website: website,
            phone: phone,
            email: email,
            groups: nil,
            adminIds: adminIds,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func parseUserGroupPreferences(from data: [String: Any]) -> UserGroupPreferences? {
        let userId = data["userId"] as? String ?? ""
        let organizationId = data["organizationId"] as? String ?? ""
        let groupId = data["groupId"] as? String ?? ""
        let alertsEnabled = data["alertsEnabled"] as? Bool ?? true
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return UserGroupPreferences(
            userId: userId,
            organizationId: organizationId,
            groupId: groupId,
            alertsEnabled: alertsEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    // MARK: - Bulletproof User Document Creation
    private func ensureUserDocumentWithFCMToken(userId: String) async {
        print("🔧 BULLETPROOF: Ensuring user document exists for: \(userId)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // First, check if user document exists
        let userDoc = try? await userRef.getDocument()
        
        if let userDoc = userDoc, userDoc.exists {
            print("✅ User document already exists")
            
            // Check if it has an FCM token
            let userData = userDoc.data() ?? [:]
            let fcmToken = userData["fcmToken"] as? String ?? ""
            
            if fcmToken.isEmpty {
                print("⚠️ User document exists but missing FCM token, updating...")
                await updateUserWithFCMToken(userId: userId, userRef: userRef)
            } else {
                print("✅ User document has FCM token: \(fcmToken.prefix(10))...")
            }
        } else {
            print("⚠️ User document does not exist, creating with FCM token...")
            await createUserDocumentWithFCMToken(userId: userId, userRef: userRef)
        }
    }
    
    private func updateUserWithFCMToken(userId: String, userRef: DocumentReference) async {
        print("🔧 Updating existing user with FCM token...")
        
        // Get FCM token from UserDefaults
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        print("   FCM Token available: \(fcmToken.isEmpty ? "NO" : "YES")")
        
        if !fcmToken.isEmpty {
            try? await userRef.updateData([
                "fcmToken": fcmToken,
                "alertsEnabled": true,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Updated user document with FCM token")
        } else {
            print("⚠️ No FCM token available to update user document")
        }
    }
    
    private func createUserDocumentWithFCMToken(userId: String, userRef: DocumentReference) async {
        print("🔧 Creating new user document with FCM token...")
        
        // Get FCM token from UserDefaults
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        print("   FCM Token available: \(fcmToken.isEmpty ? "NO" : "YES")")
        
        // Create user document with all necessary fields
        let userData: [String: Any] = [
            "id": userId,
            "fcmToken": fcmToken,
            "alertsEnabled": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "followedOrganizations": []
        ]
        
        do {
            try await userRef.setData(userData)
            print("✅ Created user document with FCM token")
        } catch {
            print("❌ Failed to create user document: \(error)")
        }
    }
    
    // MARK: - Sync Functions
    
    /// Syncs the organization's followers subcollection with the actual follower count
    func syncOrganizationFollowersSubcollection(_ organizationId: String) async throws {
        print("🔄 Syncing followers subcollection for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Get all users who follow this organization
        let followers = try await getOrganizationFollowers(organizationId)
        print("   📊 Found \(followers.count) actual followers")
        
        // Get current followers in the subcollection
        let currentFollowersSnapshot = try await db.collection("organizations")
            .document(organizationId)
            .collection("followers")
            .getDocuments()
        
        let currentFollowerIds = currentFollowersSnapshot.documents.map { $0.documentID }
        print("   📊 Current subcollection has \(currentFollowerIds.count) followers")
        
        // Add missing followers to the subcollection
        var addedCount = 0
        for followerId in followers {
            if !currentFollowerIds.contains(followerId) {
                let followerRef = db.collection("organizations")
                    .document(organizationId)
                    .collection("followers")
                    .document(followerId)
                
                try await followerRef.setData([
                    "userId": followerId,
                    "followedAt": FieldValue.serverTimestamp(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                addedCount += 1
                print("   ➕ Added follower \(followerId) to subcollection")
            }
        }
        
        // Remove followers from subcollection that are no longer following
        var removedCount = 0
        for currentFollowerId in currentFollowerIds {
            if !followers.contains(currentFollowerId) {
                let followerRef = db.collection("organizations")
                    .document(organizationId)
                    .collection("followers")
                    .document(currentFollowerId)
                
                try await followerRef.delete()
                removedCount += 1
                print("   ➖ Removed follower \(currentFollowerId) from subcollection")
            }
        }
        
        // Update the organization's follower count to match the actual count
        let orgRef = db.collection("organizations").document(organizationId)
        try await orgRef.updateData([
            "followerCount": followers.count,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ Sync completed: Added \(addedCount), Removed \(removedCount), Total: \(followers.count)")
    }
}

// MARK: - Following Models
struct FollowingStatistics: Codable {
    let organizationsFollowing: Int
    let totalGroupsAvailable: Int
    let preferencesSet: Int
    let lastUpdated: Date
}

// MARK: - Following Errors
enum FollowingError: Error, LocalizedError {
    case alreadyFollowing
    case notFollowing
    case organizationNotFound
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .alreadyFollowing:
            return "Already following this organization"
        case .notFollowing:
            return "Not currently following this organization"
        case .organizationNotFound:
            return "Organization not found"
        case .userNotFound:
            return "User not found"
        }
    }
}
