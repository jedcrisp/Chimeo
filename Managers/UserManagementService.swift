import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Management Service
class UserManagementService: ObservableObject {
    
    // MARK: - User Document Management
    func ensureUserDocumentExists(for user: User) async throws {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.id)
        
        // Check if user document already exists
        let userDoc = try await userRef.getDocument()
        if userDoc.exists {
            print("✅ User document already exists in Firestore")
            // Update FCM token if we have one
            if let fcmToken = UserDefaults.standard.string(forKey: "fcm_token"), !fcmToken.isEmpty {
                try await userRef.updateData([
                    "fcmToken": fcmToken,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                print("✅ Updated FCM token for existing user")
            }
            return
        }
        
        // Get FCM token from UserDefaults if available
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        
        // Create user document in Firestore
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email ?? "",
            "name": user.name ?? "",
            "searchableName": user.name?.lowercased().replacingOccurrences(of: " ", with: "") ?? "",
            "customDisplayName": user.displayName,
            "phone": user.phone ?? "",
            "alertRadius": user.alertRadius,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isAdmin": user.isAdmin,
            "isOrganizationAdmin": user.isOrganizationAdmin ?? false,
            "fcmToken": fcmToken, // Add FCM token for push notifications
            "alertsEnabled": true, // Enable alerts by default
            "uid": user.id // Add Firebase Auth UID for compatibility
        ]
        
        try await userRef.setData(userData)
        print("✅ User document created in Firestore with FCM token: \(fcmToken.isEmpty ? "none" : "present")")
    }
    
    func createOrGetUserAccount(email: String, name: String, organizationId: String) async throws -> User {
        print("🔄 Creating or finding user account for: \(email)")
        print("   Name: \(name)")
        print("   Organization ID: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // First, try to find existing user by email
        let usersQuery = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        if let existingUserDoc = usersQuery.documents.first {
            // User exists - update their org admin status and organization reference
            print("   ✅ User already exists - updating admin status")
            let existingUserData = existingUserDoc.data()
            let userId = existingUserDoc.documentID
            
            // Update user to be organization admin and add organization reference
            try await db.collection("users").document(userId).updateData([
                "isAdmin": true,
                "isOrganizationAdmin": true,
                "organizations": FieldValue.arrayUnion([organizationId]),
                "updatedAt": FieldValue.serverTimestamp(),
                "fcmToken": UserDefaults.standard.string(forKey: "fcm_token") ?? "", // Add FCM token
                "alertsEnabled": true // Enable alerts
            ])
            
            print("   ✅ Updated existing user admin status")
            
            return User(
                id: userId,
                email: email,
                name: existingUserData["name"] as? String ?? name,
                phone: existingUserData["phone"] as? String,
                homeLocation: nil, // Will be populated later if needed
                workLocation: nil, // Will be populated later if needed
                schoolLocation: nil, // Will be populated later if needed
                alertRadius: existingUserData["alertRadius"] as? Double ?? 5.0,
                preferences: UserPreferences(
                    incidentTypes: [],
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: (existingUserData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                isAdmin: true,
                displayName: existingUserData["customDisplayName"] as? String ?? name,
                isOrganizationAdmin: true,
                organizations: existingUserData["organizations"] as? [String] ?? [organizationId],
                updatedAt: Date(),
                needsPasswordSetup: existingUserData["needsPasswordSetup"] as? Bool ?? false,
                firebaseAuthId: existingUserData["firebaseAuthId"] as? String
            )
        }
        
        // User doesn't exist - create new account
        print("   ➕ Creating new user account")
        let userRef = db.collection("users").document()
        let userId = userRef.documentID
        
        // Get FCM token from UserDefaults if available
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "name": name,
            "searchableName": name.lowercased().replacingOccurrences(of: " ", with: ""),
            "customDisplayName": name,
            "isAdmin": true, // Set to true since they're managing an organization
            "isOrganizationAdmin": true,
            "organizations": [organizationId],
            "needsPasswordSetup": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "fcmToken": fcmToken, // Add FCM token for push notifications
            "alertsEnabled": true, // Enable alerts by default
            "uid": userId // Add Firebase Auth UID for compatibility
        ]
        
        try await userRef.setData(userData)
        print("   ✅ New user account created: \(userId) with FCM token: \(fcmToken.isEmpty ? "none" : "present")")
        
        return User(
            id: userId,
            email: email,
            name: name,
            phone: nil,
            homeLocation: nil,
            workLocation: nil,
            schoolLocation: nil,
            alertRadius: 5.0,
            preferences: UserPreferences(
                incidentTypes: [],
                criticalAlertsOnly: false,
                pushNotifications: true,
                quietHoursEnabled: false,
                quietHoursStart: nil,
                quietHoursEnd: nil
            ),
            createdAt: Date(),
            isAdmin: true, // Set to true since they're managing an organization
            displayName: name,
            isOrganizationAdmin: true,
            organizations: [organizationId],
            updatedAt: Date(),
            needsPasswordSetup: true,
            firebaseAuthId: nil
        )
    }
    
    func fixUserDocumentForOrganizationAdmin(userId: String, email: String, name: String) async throws {
        print("🔧 Fixing user document for organization admin: \(userId)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // Check if user document exists
        let userDoc = try await userRef.getDocument()
        
        if userDoc.exists {
            var updateData: [String: Any] = [:]
            let currentData = userDoc.data() ?? [:]
            
            // Add missing fields
            if currentData["searchableName"] == nil {
                updateData["searchableName"] = name.lowercased().replacingOccurrences(of: " ", with: "")
            }
            
            if currentData["customDisplayName"] == nil {
                updateData["customDisplayName"] = name
            }
            
            if currentData["isAdmin"] == nil {
                updateData["isAdmin"] = true
            }
            
            if currentData["isOrganizationAdmin"] == nil {
                updateData["isOrganizationAdmin"] = true
            }
            
            if currentData["organizations"] == nil {
                updateData["organizations"] = []
            }
            
            updateData["updatedAt"] = FieldValue.serverTimestamp()
            
            if !updateData.isEmpty {
                try await userRef.updateData(updateData)
                print("   ✅ Updated user document with missing fields")
            } else {
                print("   ✅ User document already has all required fields")
            }
        } else {
            // Create new user document
            let userData: [String: Any] = [
                "id": userId,
                "email": email,
                "name": name,
                "searchableName": name.lowercased().replacingOccurrences(of: " ", with: ""),
                "customDisplayName": name,
                "isAdmin": true,
                "isOrganizationAdmin": true,
                "organizations": [],
                "needsPasswordSetup": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await userRef.setData(userData)
            print("   ✅ Created new user document")
        }
    }
    
    func updateUserOrganizationReference(userId: String, oldOrgId: String, newOrgId: String) async throws {
        print("🔄 Updating user organization reference: \(userId)")
        print("   From: \(oldOrgId)")
        print("   To: \(newOrgId)")
        
        let db = Firestore.firestore()
        
        // Remove old organization reference
        try await db.collection("users").document(userId).updateData([
            "organizations": FieldValue.arrayRemove([oldOrgId])
        ])
        
        // Add new organization reference
        try await db.collection("users").document(userId).updateData([
            "organizations": FieldValue.arrayUnion([newOrgId])
        ])
        
        print("   ✅ User organization reference updated")
    }
    
    // MARK: - FCM Token Management
    func updateUserFCMToken(userId: String) async throws {
        print("🔥 Updating FCM token for user: \(userId)")
        
        guard let fcmToken = UserDefaults.standard.string(forKey: "fcm_token"), !fcmToken.isEmpty else {
            print("⚠️ No FCM token available to update")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "fcmToken": fcmToken,
            "alertsEnabled": true,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ FCM token updated successfully for user: \(userId)")
    }
    
    func getUserFCMToken(userId: String) async -> String? {
        print("🔍 Getting FCM token for user: \(userId)")
        
        do {
            let db = Firestore.firestore()
            let doc = try await db.collection("users").document(userId).getDocument()
            
            if let data = doc.data(), let token = data["fcmToken"] as? String {
                print("✅ FCM token found for user: \(userId)")
                return token
            } else {
                print("⚠️ No FCM token found for user: \(userId)")
                return nil
            }
        } catch {
            print("❌ Error getting FCM token: \(error)")
            return nil
        }
    }
    
    // MARK: - Debug Functions
    func createMissingUserDocument(userId: String, email: String, name: String) async throws {
        print("🔧 DEBUG: Creating missing user document for: \(userId)")
        print("   Email: \(email)")
        print("   Name: \(name)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // Check if user already exists
        let existingDoc = try await userRef.getDocument()
        if existingDoc.exists {
            print("⚠️ User document already exists, updating instead...")
            try await userRef.updateData([
                "email": email,
                "name": name,
                "updatedAt": FieldValue.serverTimestamp(),
                "fcmToken": UserDefaults.standard.string(forKey: "fcm_token") ?? "",
                "alertsEnabled": true
            ])
            print("✅ User document updated successfully")
            return
        }
        
        // Create new user document
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "name": name,
            "displayName": name,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isAdmin": false,
            "isOrganizationAdmin": false,
            "fcmToken": UserDefaults.standard.string(forKey: "fcm_token") ?? "",
            "alertsEnabled": true,
            "uid": userId
        ]
        
        try await userRef.setData(userData)
        print("✅ Missing user document created successfully")
        
        // Verify creation
        let verifyDoc = try await userRef.getDocument()
        if verifyDoc.exists {
            print("✅ VERIFICATION: User document confirmed to exist")
        } else {
            print("❌ VERIFICATION FAILED: User document still doesn't exist!")
        }
    }
    
    // MARK: - User Profile Updates
    
    // MARK: - User Role Checks
    func isAdminOfOrganization(_ organizationId: String, currentUser: User?) async -> Bool {
        guard let currentUser = currentUser else { 
            print("❌ No current user for admin check")
            return false 
        }
        
        print("🔍 Checking if user \(currentUser.id) is admin of organization \(organizationId)")
        print("   🔄 Always fetching fresh data from Firestore...")
        print("   👤 Current user details:")
        print("      - ID: \(currentUser.id)")
        print("      - Email: \(currentUser.email ?? "nil")")
        print("      - Firebase Auth ID: \(currentUser.firebaseAuthId ?? "nil")")
        print("      - Is Admin: \(currentUser.isAdmin)")
        print("      - Is Org Admin: \(currentUser.isOrganizationAdmin ?? false)")
        print("      - Organizations: \(currentUser.organizations ?? [])")
        
        let db = Firestore.firestore()
        
        do {
            // First, find the user's Firestore document ID by email
            print("   🔍 Finding user's Firestore document ID...")
            let usersQuery = try await db.collection("users")
                .whereField("email", isEqualTo: currentUser.email ?? "")
                .getDocuments()
            
            guard let userDoc = usersQuery.documents.first else {
                print("   ❌ User document not found in Firestore")
                return false
            }
            
            let firestoreUserId = userDoc.documentID
            print("   ✅ Found user's Firestore document ID: \(firestoreUserId)")
            
            // Try different possible document IDs for the organization (case-insensitive)
            let possibleDocIds = [
                organizationId, // Original ID as provided
                organizationId.lowercased(), // Lowercase version
                organizationId.uppercased(), // Uppercase version
                organizationId.capitalized, // Capitalized version
                // Handle mixed case with underscores (like "Velocity_Physical_Therapy_North_Denton")
                organizationId.replacingOccurrences(of: "_", with: " ").lowercased().replacingOccurrences(of: " ", with: "_"), // Convert to lowercase with underscores
                organizationId.replacingOccurrences(of: "_", with: " ").capitalized.replacingOccurrences(of: " ", with: "_"), // Convert to title case with underscores
                // Original space replacement logic
                organizationId.replacingOccurrences(of: " ", with: "_"), // Replace spaces with underscores
                organizationId.replacingOccurrences(of: " ", with: "_").lowercased(), // Lowercase with underscores
                organizationId.replacingOccurrences(of: " ", with: "_").uppercased(), // Uppercase with underscores
                organizationId.replacingOccurrences(of: " ", with: "_").capitalized // Capitalized with underscores
            ]
            
            // Remove duplicates and empty strings
            let uniqueDocIds = Array(Set(possibleDocIds)).filter { !$0.isEmpty }
            
            print("   🔍 Searching for organization with case-insensitive IDs: \(uniqueDocIds)")
            
            for docId in uniqueDocIds {
                print("   🔍 Checking Firestore document ID: \(docId)")
                
                let orgDoc = try await db.collection("organizations").document(docId).getDocument()
                
                if orgDoc.exists, let orgData = orgDoc.data() {
                    let orgName = orgData["name"] as? String ?? "Unknown"
                    let adminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
                    
                    print("   ✅ Found organization in Firestore: \(orgName)")
                    print("   🔑 Organization admin IDs: \(adminIds)")
                    print("   🔍 Looking for Firestore user ID: \(firestoreUserId)")
                    print("   🔍 Looking for Firebase Auth ID: \(currentUser.firebaseAuthId ?? "nil")")
                    
                    // Check if user is admin using Firestore document ID (this is what adminIds contains)
                    let isAdminByFirestoreId = adminIds[firestoreUserId] == true
                    let isAdminByFirebaseId = currentUser.firebaseAuthId != nil ? adminIds[currentUser.firebaseAuthId!] == true : false
                    
                    print("   ✅ Admin check by Firestore user ID (\(firestoreUserId)): \(isAdminByFirestoreId)")
                    print("   ✅ Admin check by Firebase Auth ID (\(currentUser.firebaseAuthId ?? "nil")): \(isAdminByFirebaseId)")
                    
                    let isAdmin = isAdminByFirestoreId || isAdminByFirebaseId
                    
                    if isAdmin {
                        print("   🎉 User \(firestoreUserId) is confirmed admin of organization \(docId)")
                    } else {
                        print("   ⚠️ User \(firestoreUserId) is NOT admin of organization \(docId)")
                        print("   🔍 Available admin IDs: \(Array(adminIds.keys))")
                        print("   💡 Tip: Check if Firestore user ID or Firebase Auth ID matches any admin ID")
                    }
                    
                    return isAdmin
                } else {
                    print("   ❌ Organization document '\(docId)' not found or has no data")
                }
            }
            
            print("   ❌ Organization not found with any possible document ID")
            print("   🔍 Tried document IDs: \(uniqueDocIds)")
            print("   💡 Tip: Check if organization exists in Firestore with exact document ID")
            
            // Fallback: Try to find organization by name (case-insensitive)
            print("   🔍 Fallback: Searching for organization by name...")
            let orgNameQuery = try await db.collection("organizations")
                .whereField("name", isEqualTo: organizationId.replacingOccurrences(of: "_", with: " "))
                .getDocuments()
            
            if let orgDoc = orgNameQuery.documents.first {
                let orgData = orgDoc.data()
                let orgName = orgData["name"] as? String ?? "Unknown"
                let adminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
                let actualDocId = orgDoc.documentID
                
                print("   ✅ Found organization by name: \(orgName) (Document ID: \(actualDocId))")
                print("   🔑 Organization admin IDs: \(adminIds)")
                print("   🔍 Looking for Firestore user ID: \(firestoreUserId)")
                
                // Check if user is admin
                let isAdminByFirestoreId = adminIds[firestoreUserId] == true
                let isAdminByFirebaseId = currentUser.firebaseAuthId != nil ? adminIds[currentUser.firebaseAuthId!] == true : false
                
                let isAdmin = isAdminByFirestoreId || isAdminByFirebaseId
                
                if isAdmin {
                    print("   🎉 User \(firestoreUserId) is confirmed admin of organization \(actualDocId)")
                } else {
                    print("   ⚠️ User \(firestoreUserId) is NOT admin of organization \(actualDocId)")
                    print("   🔍 Available admin IDs: \(Array(adminIds.keys))")
                }
                
                return isAdmin
            }
            
            print("   ❌ Organization not found by name either")
            
        } catch {
            print("❌ Failed to check organization in Firestore: \(error)")
        }
        
        print("   ❌ User is NOT admin of organization \(organizationId)")
        return false
    }
    
    func canManageOrganization(_ organizationId: String, currentUser: User?) async -> Bool {
        return await isAdminOfOrganization(organizationId, currentUser: currentUser)
    }
    
    func hasOrganizationAdminAccess(currentUser: User?, organizations: [Organization]) -> Bool {
        guard let currentUser = currentUser else { 
            return false 
        }
        
        // Check if user is admin of any organization
        let hasAccess = organizations.contains { organization in
            organization.adminIds?[currentUser.id] == true
        }
        
        return hasAccess
    }
}
