import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import UIKit

// MARK: - Notification Names
extension Notification.Name {
    static let userProfileSaved = Notification.Name("userProfileSaved")
}

// MARK: - Authentication Errors
enum AuthError: Error, LocalizedError {
    case clientIDNotFound
    case noRootViewController
    case noIDToken
    case signInFailed
    
    var errorDescription: String? {
        switch self {
        case .clientIDNotFound:
            return "Firebase configuration not found"
        case .noRootViewController:
            return "Unable to present sign-in flow"
        case .noIDToken:
            return "Google authentication failed"
        case .signInFailed:
            return "Sign-in process failed"
        }
    }
}

// MARK: - Authentication Service
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let userService: UserManagementService
    
    init(userService: UserManagementService) {
        self.userService = userService
        
        // Check for stored auth token
        if UserDefaults.standard.string(forKey: "authToken") != nil {
            print("📱 Found saved auth token, restoring session...")
            self.isAuthenticated = true
            loadCurrentUserFromDefaults()
        }
    }
    
    // MARK: - User Profile Management
    func saveUserProfileToDefaults(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        }
    }
    
    func loadCurrentUserFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
        }
    }
    
    // MARK: - Authentication Methods
    func signInWithGoogle() async throws -> User {
        print("🚀 APIService.signInWithGoogle() called")
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ ERROR: No client ID found")
            throw AuthError.clientIDNotFound
        }
        
        print("✅ Client ID found: \(clientID)")
        
        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ Google Sign In configured")
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingViewController = windowScene.windows.first?.rootViewController else {
            print("❌ ERROR: No root view controller found")
            throw AuthError.noRootViewController
        }
        
        print("✅ Root view controller found, starting Google Sign In...")
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        print("✅ Google Sign In completed, getting credentials...")
        
        guard let idToken = result.user.idToken?.tokenString else {
            print("❌ ERROR: No ID token from Google")
            throw AuthError.noIDToken
        }
        
        print("✅ ID token received from Google")
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                     accessToken: result.user.accessToken.tokenString)
        print("✅ Firebase credential created")
        
        let authResult = try await Auth.auth().signIn(with: credential)
        print("✅ Firebase Auth sign in successful: \(authResult.user.uid)")
        print("📧 User email: \(authResult.user.email ?? "none")")
        print("👤 User display name: \(authResult.user.displayName ?? "none")")
        
        // Create user profile
        print("🔧 Creating user profile...")
        let newUser = User(
            id: authResult.user.uid,
            email: authResult.user.email,
            name: authResult.user.displayName ?? "Google User",
            phone: authResult.user.phoneNumber,
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
                incidentTypes: [.weather, .road, .other],
                criticalAlertsOnly: false,
                pushNotifications: true,
                quietHoursEnabled: false,
                quietHoursStart: nil,
                quietHoursEnd: nil
            ),
            createdAt: Date(),
            isAdmin: false,
            displayName: authResult.user.displayName ?? "Google User"
        )
        
        print("✅ User profile created in memory")
        print("🆔 User ID: \(newUser.id)")
        print("📧 User email: \(newUser.email ?? "none")")
        print("👤 User name: \(newUser.name ?? "none")")
        
        // Update the service state
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
            print("✅ Service state updated")
        }
        
        // Save user profile
        print("💾 Saving user profile to defaults...")
        saveUserProfileToDefaults(newUser)
        print("✅ User profile saved to defaults")
        
        // Post notification that user has been saved (for FCM token registration)
        print("📢 Posting userProfileSaved notification...")
        NotificationCenter.default.post(name: .userProfileSaved, object: newUser)
        print("✅ Notification posted")
        
        // BULLETPROOF: Create user document on EVERY authentication
        print("🔥 BULLETPROOF: Creating user document for every authentication...")
        print("🚨 THIS SHOULD ALWAYS RUN WHEN SIGNING IN!")
        print("📱 User ID: \(newUser.id)")
        print("📧 User Email: \(newUser.email ?? "NO EMAIL")")
        print("👤 User Name: \(newUser.name ?? "NO NAME")")
        
        await createUserDocumentForEveryAuth(userId: newUser.id, email: newUser.email ?? "", name: newUser.name ?? "Google User")
        
        print("🎉 SUCCESS: Google Sign In completed with user: \(newUser.name ?? "Unknown")")
        return newUser
    }
    
    // MARK: - Bulletproof User Creation
    private func createUserDocumentForEveryAuth(userId: String, email: String, name: String) async {
        print("🔧 BULLETPROOF: Creating user document for: \(userId)")
        print("🚨 FUNCTION IS RUNNING!")
        print("   Email: \(email)")
        print("   Name: \(name)")
        print("   User ID: \(userId)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        print("📁 Firestore path: users/\(userId)")
        
        // Get FCM token (or empty string if not available)
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        print("   FCM Token available: \(fcmToken.isEmpty ? "NO" : "YES")")
        print("   FCM Token value: \(fcmToken)")
        
        // Create user document with all necessary fields
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "name": name,
            "displayName": name,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isAdmin": false,
            "isOrganizationAdmin": false,
            "fcmToken": fcmToken,
            "alertsEnabled": true,
            "uid": userId,
            "lastSignIn": FieldValue.serverTimestamp(),
            "signInCount": 1
        ]
        
        print("📋 User data to save: \(userData)")
        
        do {
            print("💾 Attempting to save to Firestore...")
            // Use setData with merge: true to update existing or create new
            try await userRef.setData(userData, merge: true)
            print("✅ BULLETPROOF: User document created/updated successfully")
            
            // Verify the document exists
            print("🔍 Verifying document creation...")
            let verifyDoc = try await userRef.getDocument()
            if verifyDoc.exists {
                print("✅ VERIFICATION: User document confirmed to exist")
                let data = verifyDoc.data()
                print("📋 Document fields: \(data?.keys.joined(separator: ", ") ?? "none")")
            } else {
                print("❌ VERIFICATION FAILED: Document still doesn't exist!")
            }
            
        } catch {
            print("❌ BULLETPROOF FAILED: Could not create user document: \(error)")
            print("🚨 This is critical - user will not receive push notifications!")
            print("🔍 Error details: \(error.localizedDescription)")
        }
    }
    
    func signUpWithEmail(email: String, password: String, name: String) async throws -> User {
        print("🔐 Email Sign Up started for: \(email)")

        // First, check if there's already a user document with this email (from org approval)
        let db = Firestore.firestore()
        let usersQuery = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()

        if let existingUserDoc = usersQuery.documents.first {
            // Found existing user document - link it to Firebase Auth
            print("✅ Found existing user document - linking to Firebase Auth...")

            let existingUserId = existingUserDoc.documentID
            let existingUserData = existingUserDoc.data()

            // Create Firebase Auth account
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let firebaseAuthId = authResult.user.uid

            print("✅ Firebase Auth account created: \(firebaseAuthId)")

            // Update the existing user document to link Firebase Auth and mark password as set
            try await db.collection("users")
                .document(existingUserId)
                .updateData([
                    "needsPasswordSetup": false,
                    "firebaseAuthId": firebaseAuthId,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            print("✅ Existing user document linked to Firebase Auth")

            // Create User object from existing Firestore data
            let linkedUser = User(
                id: firebaseAuthId, // Use Firebase Auth ID as the main ID
                email: email,
                name: existingUserData["name"] as? String ?? name,
                phone: existingUserData["phone"] as? String,
                homeLocation: nil, // Will be loaded separately if needed
                workLocation: nil,
                schoolLocation: nil,
                alertRadius: 10.0,
                preferences: UserPreferences(
                    incidentTypes: [.weather, .road, .other],
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: Date(),
                isAdmin: existingUserData["isAdmin"] as? Bool ?? false,
                displayName: existingUserData["customDisplayName"] as? String ?? name,
                isOrganizationAdmin: existingUserData["isOrganizationAdmin"] as? Bool,
                organizations: existingUserData["organizations"] as? [String],
                updatedAt: Date(),
                needsPasswordSetup: false,
                firebaseAuthId: firebaseAuthId
            )

            // Update the service state
            await MainActor.run {
                self.currentUser = linkedUser
                self.isAuthenticated = true
            }

            // Save user profile
            saveUserProfileToDefaults(linkedUser)
            
            // Post notification that user has been saved (for FCM token registration)
            NotificationCenter.default.post(name: .userProfileSaved, object: linkedUser)
            
            // Update FCM token for linked user
            do {
                try await userService.updateUserFCMToken(userId: linkedUser.id)
            } catch {
                print("⚠️ Warning: Could not update FCM token: \(error)")
            }

            print("🎉 Successfully linked existing organization admin account!")
            return linkedUser

        } else {
            // No existing user document - create new regular user
            print("📝 Creating new user account...")

            // Create user account with Firebase Auth
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)

            // Create user profile
            let newUser = User(
                id: authResult.user.uid,
                email: email,
                name: name,
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
                    incidentTypes: [.weather, .road, .other],
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: Date(),
                isAdmin: false,
                displayName: name,
                isOrganizationAdmin: nil,
                organizations: nil,
                updatedAt: nil,
                needsPasswordSetup: nil,
                firebaseAuthId: nil
            )

            // Save user profile
            saveUserProfileToDefaults(newUser)
            
            // Post notification that user has been saved (for FCM token registration)
            NotificationCenter.default.post(name: .userProfileSaved, object: newUser)

            // Ensure user document exists in Firestore
            do {
                try await userService.ensureUserDocumentExists(for: newUser)
                
                // Also update FCM token to ensure it's stored
                try await userService.updateUserFCMToken(userId: newUser.id)
            } catch {
                print("⚠️ Warning: Could not create Firestore user document: \(error)")
            }

            // Update the service state
            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
            }

            print("✅ Successfully created new account: \(newUser.name ?? "Unknown")")
            return newUser
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws -> User {
        print("🔐 Email Sign In started for: \(email)")
        
        // Sign in with Firebase Auth
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        let firebaseAuthId = authResult.user.uid
        
        print("✅ Firebase Auth sign in successful: \(firebaseAuthId)")
        
        // Try to load existing user data from Firestore
        let db = Firestore.firestore()
        let usersQuery = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments()
        
        if let existingUserDoc = usersQuery.documents.first {
            // Found existing user document - load it
            print("✅ Found existing user document - loading user data...")
            
            let userData = existingUserDoc.data()
            let userId = existingUserDoc.documentID
            
            // Create User object from existing Firestore data
            let existingUser = User(
                id: userId, // Use Firestore document ID as the main ID (this is what adminIds contains)
                email: email,
                name: userData["name"] as? String ?? authResult.user.displayName ?? "Email User",
                phone: userData["phone"] as? String,
                homeLocation: nil, // Will be loaded separately if needed
                workLocation: nil,
                schoolLocation: nil,
                alertRadius: userData["alertRadius"] as? Double ?? 10.0,
                preferences: UserPreferences(
                    incidentTypes: [.weather, .road, .other],
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: (userData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                isAdmin: userData["isAdmin"] as? Bool ?? false,
                displayName: userData["customDisplayName"] as? String ?? userData["name"] as? String ?? "Email User",
                isOrganizationAdmin: userData["isOrganizationAdmin"] as? Bool,
                organizations: userData["organizations"] as? [String],
                updatedAt: (userData["updatedAt"] as? Timestamp)?.dateValue(),
                needsPasswordSetup: userData["needsPasswordSetup"] as? Bool,
                needsPasswordChange: userData["needsPasswordChange"] as? Bool,
                firebaseAuthId: firebaseAuthId
            )
            
            // Update the service state
            await MainActor.run {
                self.currentUser = existingUser
                self.isAuthenticated = true
            }
            
            // Save user profile
            saveUserProfileToDefaults(existingUser)
            
            // Post notification that user has been saved (for FCM token registration)
            NotificationCenter.default.post(name: .userProfileSaved, object: existingUser)
            
            // Update FCM token for existing user
            do {
                try await userService.updateUserFCMToken(userId: existingUser.id)
            } catch {
                print("⚠️ Warning: Could not update FCM token: \(error)")
            }
            
            print("🎉 Successfully signed in existing user: \(existingUser.name ?? "Unknown")")
            return existingUser
            
        } else {
            // No existing user document - create new regular user
            print("📝 No existing user document found - creating new user...")
            
            let newUser = User(
                id: firebaseAuthId,
                email: email,
                name: authResult.user.displayName ?? "Email User",
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
                    incidentTypes: [.weather, .road, .other],
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: Date(),
                isAdmin: false,
                displayName: authResult.user.displayName ?? "Email User",
                isOrganizationAdmin: nil,
                organizations: nil,
                updatedAt: nil,
                needsPasswordSetup: nil,
                needsPasswordChange: nil,
                firebaseAuthId: firebaseAuthId
            )
            
            // Update the service state
            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
            }
            
            // Save user profile
            saveUserProfileToDefaults(newUser)
            
            // Post notification that user has been saved (for FCM token registration)
            NotificationCenter.default.post(name: .userProfileSaved, object: newUser)
            
            // Ensure user document exists in Firestore
            do {
                try await userService.ensureUserDocumentExists(for: newUser)
                
                // Also update FCM token to ensure it's stored
                try await userService.updateUserFCMToken(userId: newUser.id)
            } catch {
                print("⚠️ Warning: Could not create Firestore user document: \(error)")
            }
            
            print("✅ Successfully created new account: \(newUser.name ?? "Unknown")")
            return newUser
        }
    }
    
    func updatePassword(newPassword: String) async throws {
        print("🔐 Attempting to update password...")
        
        guard let user = Auth.auth().currentUser else {
            print("❌ No current Firebase Auth user found")
            throw AuthError.signInFailed
        }
        
        guard let email = user.email else {
            print("❌ No email found for current user")
            throw AuthError.signInFailed
        }
        
        print("✅ Found Firebase Auth user: \(user.uid)")
        print("   Email: \(email)")
        print("   Is Anonymous: \(user.isAnonymous)")
        
        do {
            // For password changes, we might need to re-authenticate first
            print("🔐 Re-authenticating user with current password...")
            // Note: We can't re-authenticate with a default password here
            // The user should sign in again with their current password
            print("💡 User needs to sign in again for recent authentication")
            throw NSError(domain: "PasswordUpdateError", 
                        code: 401, 
                        userInfo: [NSLocalizedDescriptionKey: "Please sign out and sign in again with your current password, then try changing your password."])
        } catch let authError as NSError {
            print("❌ Failed to update password: \(authError)")
            print("   Error code: \(authError.code)")
            print("   Error details: \(authError.localizedDescription)")
            
            // If re-authentication failed due to wrong password, try without it
            if authError.code == AuthErrorCode.wrongPassword.rawValue {
                print("🔄 Re-authentication failed, trying direct password update...")
                do {
                    try await user.updatePassword(to: newPassword)
                    print("✅ Password updated successfully (without re-auth)")
                } catch {
                    print("❌ Direct password update also failed: \(error)")
                    throw error
                }
            } else {
                throw authError
            }
        }
    }
    
    func signOut() {
        self.isAuthenticated = false
        self.currentUser = nil
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
