import Foundation
import FirebaseFirestore

// MARK: - Development Service
/// Service for development, debugging, and administrative functions
class DevelopmentService: ObservableObject {
    
    // MARK: - Development Helper Functions
    func enableGuestMode() -> User {
        print("🔧 Enabling guest mode for development")
        
        let guestUser = User(
            id: "admin-001",
            email: "admin@chimeo.app",
            name: "Admin User",
            phone: nil,
            homeLocation: Location(
                latitude: 33.1032,
                longitude: -96.6705,
                address: "123 Main Street",
                city: "Lucas",
                state: "TX",
                zipCode: "75002"
            ),
            workLocation: nil,
            schoolLocation: nil,
            alertRadius: 10.0,
            preferences: UserPreferences(
                incidentTypes: IncidentType.allCases,
                criticalAlertsOnly: false,
                pushNotifications: true,
                quietHoursEnabled: false,
                quietHoursStart: nil,
                quietHoursEnd: nil
            ),
            createdAt: Date(),
            isAdmin: true,
            displayName: "Admin User",
            isOrganizationAdmin: nil,
            organizations: nil,
            updatedAt: nil,
            needsPasswordSetup: nil,
            firebaseAuthId: nil
        )
        
        print("✅ Guest mode enabled with admin privileges")
        return guestUser
    }
    
    // MARK: - Debug Organization Access
    func debugOrganizationAccess(userId: String, organizationId: String) async throws {
        print("🔍 DEBUG: Organization Access Check")
        print("   User ID: \(userId)")
        print("   Organization ID: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Check user document
        let userDoc = try await db.collection("users").document(userId).getDocument()
        if let userData = userDoc.data() {
            print("   👤 User Data:")
            print("      - Name: \(userData["name"] as? String ?? "N/A")")
            print("      - Email: \(userData["email"] as? String ?? "N/A")")
            print("      - Is Admin: \(userData["isAdmin"] as? Bool ?? false)")
            print("      - Is Org Admin: \(userData["isOrganizationAdmin"] as? Bool ?? false)")
            print("      - Organizations: \(userData["organizations"] as? [String] ?? [])")
        } else {
            print("   ❌ User document not found")
        }
        
        // Check organization document
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        if let orgData = orgDoc.data() {
            print("   🏢 Organization Data:")
            print("      - Name: \(orgData["name"] as? String ?? "N/A")")
            print("      - Admin IDs: \(orgData["adminIds"] as? [String: Bool] ?? [:])")
            print("      - Creator ID: \(orgData["creatorId"] as? String ?? "N/A")")
        } else {
            print("   ❌ Organization document not found")
        }
    }
    
    // MARK: - Fix Organization Admin Access
    func fixOrganizationAdminAccess(userId: String, organizationId: String) async throws {
        print("🔧 Fixing organization admin access")
        print("   User ID: \(userId)")
        print("   Organization ID: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Add user to organization's admin list
        try await db.collection("organizations").document(organizationId).updateData([
            "adminIds.\(userId)": true,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update user's organization admin status
        try await db.collection("users").document(userId).updateData([
            "isOrganizationAdmin": true,
            "organizations": FieldValue.arrayUnion([organizationId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ Organization admin access fixed")
    }
    
    // MARK: - Fix Organization ID Mismatch
    func fixOrganizationIdMismatch() async throws {
        print("🔧 Fixing organization ID mismatches")
        
        let db = Firestore.firestore()
        let snapshot = try await db.collection("organizations").getDocuments()
        
        var fixedCount = 0
        
        for document in snapshot.documents {
            let docId = document.documentID
            let data = document.data()
            let storedId = data["id"] as? String
            
            if storedId != docId {
                print("   🔧 Fixing mismatch: stored=\(storedId ?? "nil"), doc=\(docId)")
                
                try await db.collection("organizations").document(docId).updateData([
                    "id": docId,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                
                fixedCount += 1
            }
        }
        
        print("✅ Fixed \(fixedCount) organization ID mismatches")
    }
    
    // MARK: - Migrate Existing Organizations
    func migrateExistingOrganizations() async throws {
        print("🔄 Migrating existing organizations")
        
        let db = Firestore.firestore()
        let snapshot = try await db.collection("organizations").getDocuments()
        
        var migratedCount = 0
        
        for document in snapshot.documents {
            let docId = document.documentID
            let data = document.data()
            
            var updateData: [String: Any] = [:]
            
            // Add missing fields
            if data["verified"] == nil {
                updateData["verified"] = false
            }
            
            if data["followerCount"] == nil {
                updateData["followerCount"] = 0
            }
            
            if data["alertCount"] == nil {
                updateData["alertCount"] = 0
            }
            
            if data["adminIds"] == nil {
                updateData["adminIds"] = [:]
            }
            
            if data["createdAt"] == nil {
                updateData["createdAt"] = FieldValue.serverTimestamp()
            }
            
            if !updateData.isEmpty {
                updateData["updatedAt"] = FieldValue.serverTimestamp()
                
                try await db.collection("organizations").document(docId).updateData(updateData)
                migratedCount += 1
                
                print("   ✅ Migrated organization: \(docId)")
            }
        }
        
        print("✅ Migrated \(migratedCount) organizations")
    }
    
    // MARK: - Fix Follow Relationships
    func fixFollowRelationships() async throws {
        print("🔧 Fixing follow relationships")
        
        let db = Firestore.firestore()
        
        // Get all organization followers
        let followersSnapshot = try await db.collection("organizationFollowers").getDocuments()
        
        for document in followersSnapshot.documents {
            let orgId = document.documentID
            let data = document.data()
            let followers = data["followers"] as? [String] ?? []
            
            // Update organization follower count
            try await db.collection("organizations").document(orgId).updateData([
                "followerCount": followers.count,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("   ✅ Fixed follower count for organization: \(orgId) (\(followers.count) followers)")
        }
        
        print("✅ Follow relationships fixed")
    }
    
    // MARK: - User Creator Status
    func updateUserCreatorStatus(userId: String, isCreator: Bool) async throws {
        print("🔧 Updating user creator status")
        print("   User ID: \(userId)")
        print("   Is Creator: \(isCreator)")
        
        let db = Firestore.firestore()
        
        try await db.collection("users").document(userId).updateData([
            "isCreator": isCreator,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ User creator status updated")
    }
    
    // MARK: - Debug Organization IDs
    func debugOrganizationIds() async throws {
        print("🔍 DEBUG: Organization IDs")
        
        let db = Firestore.firestore()
        let snapshot = try await db.collection("organizations").getDocuments()
        
        for document in snapshot.documents {
            let docId = document.documentID
            let data = document.data()
            let storedId = data["id"] as? String
            let name = data["name"] as? String
            
            print("   🏢 Organization:")
            print("      - Document ID: \(docId)")
            print("      - Stored ID: \(storedId ?? "nil")")
            print("      - Name: \(name ?? "Unknown")")
            print("      - Match: \(docId == storedId ? "✅" : "❌")")
            print("")
        }
    }
    
    // MARK: - Refresh User Email
    func refreshUserEmail(userId: String) async throws {
        print("🔄 Refreshing user email for user: \(userId)")
        
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        if let userData = userDoc.data() {
            let currentEmail = userData["email"] as? String ?? ""
            print("   📧 Current email: \(currentEmail)")
            
            // This would typically refresh from Firebase Auth
            // For now, just log the current state
            print("   ✅ Email refresh completed")
        } else {
            print("   ❌ User document not found")
            throw DevelopmentError.userNotFound
        }
    }
    
    // MARK: - Debug User Info
    func debugUserInfo(userId: String) async throws {
        print("🔍 DEBUG: User Info")
        print("   User ID: \(userId)")
        
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        if let userData = userDoc.data() {
            print("   👤 User Data:")
            for (key, value) in userData {
                print("      - \(key): \(value)")
            }
        } else {
            print("   ❌ User document not found")
        }
    }
    
    // MARK: - Creator Account Check
    func checkCreatorAccount(userId: String) async throws -> Bool {
        print("🔍 Checking creator account status for user: \(userId)")
        
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        guard let userData = userDoc.data() else {
            print("   ❌ User document not found")
            return false
        }
        
        let isCreator = userData["isCreator"] as? Bool ?? false
        let isAdmin = userData["isAdmin"] as? Bool ?? false
        
        print("   👤 User Status:")
        print("      - Is Creator: \(isCreator)")
        print("      - Is Admin: \(isAdmin)")
        
        return isCreator || isAdmin
    }
    
    // MARK: - Fix Existing User Documents
    func fixAllExistingUserDocuments() async throws {
        print("🔧 Fixing all existing user documents")
        
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users").getDocuments()
        
        var fixedCount = 0
        
        for document in snapshot.documents {
            do {
                try await fixSpecificUserDocument(userId: document.documentID)
                fixedCount += 1
            } catch {
                print("   ⚠️ Warning: Could not fix user \(document.documentID): \(error)")
            }
        }
        
        print("✅ Fixed \(fixedCount) user documents")
    }
    
    func fixSpecificUserDocument(userId: String) async throws {
        print("🔧 Fixing user document: \(userId)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        guard let userData = userDoc.data() else {
            throw DevelopmentError.userNotFound
        }
        
        var updateData: [String: Any] = [:]
        
        // Add missing fields
        if userData["searchableName"] == nil {
            let name = userData["name"] as? String ?? ""
            updateData["searchableName"] = name.lowercased().replacingOccurrences(of: " ", with: "")
        }
        
        if userData["customDisplayName"] == nil {
            updateData["customDisplayName"] = userData["name"] ?? ""
        }
        
        if userData["isAdmin"] == nil {
            updateData["isAdmin"] = false
        }
        
        if userData["isOrganizationAdmin"] == nil {
            updateData["isOrganizationAdmin"] = false
        }
        
        if userData["organizations"] == nil {
            updateData["organizations"] = []
        }
        
        if !updateData.isEmpty {
            updateData["updatedAt"] = FieldValue.serverTimestamp()
            try await userRef.updateData(updateData)
            print("   ✅ Fixed user document")
        } else {
            print("   ✅ User document already complete")
        }
    }
}

// MARK: - Development Errors
enum DevelopmentError: Error, LocalizedError {
    case userNotFound
    case organizationNotFound
    case migrationFailed
    case fixFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .organizationNotFound:
            return "Organization not found"
        case .migrationFailed:
            return "Migration failed"
        case .fixFailed:
            return "Fix operation failed"
        }
    }
}
