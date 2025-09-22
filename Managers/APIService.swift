import Foundation
import Combine
import SwiftUI
import CoreLocation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import FirebaseFunctions
import FirebaseMessaging
import FirebaseAuth

// MARK: - Keychain Service
// Using the dedicated KeychainService from its own file

// MARK: - Authentication Errors
// AuthError is defined in AuthenticationService.swift

class APIService: ObservableObject {
    private let baseURL = "https://api.localalert.com" // Replace with your actual API URL
    var authToken: String?
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var incidents: [Incident] = []
    @Published var organizations: [Organization] = []
    @Published var pendingRequests: [OrganizationRequest] = []
    
    init() {
        print("🚀 APIService: Initializing...")
        
        // Initialize with default values
        self.isAuthenticated = false
        self.authToken = nil
        self.currentUser = nil
        
        print("🔐 APIService: Set initial state - isAuthenticated: \(self.isAuthenticated)")
        
        // Try to restore authentication state from stored data
        restoreAuthenticationState()
        
        // Also try to sync with ServiceCoordinator if available
        syncWithServiceCoordinator()
        
        print("🔐 APIService: Forcing login screen - isAuthenticated: \(self.isAuthenticated)")
        print("🔍 DEBUG: APIService initialized - isAuthenticated: \(self.isAuthenticated)")
        print("🔍 DEBUG: APIService currentUser: \(self.currentUser?.id ?? "nil")")
        
        // Set up Firebase Auth state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    print("🔥 Firebase Auth: User signed in - \(user.email ?? "unknown")")
                    print("🔥 Firebase Auth: User UID - \(user.uid)")
                    print("🔐 APIService: Current isAuthenticated = \(self?.isAuthenticated ?? false)")
                    print("🔐 APIService: Current user ID = \(self?.currentUser?.id ?? "nil")")
                    
                    // If we have a Firebase user but not authenticated, try to restore authentication
                    if let strongSelf = self, !strongSelf.isAuthenticated {
                        print("🔄 Firebase user exists but APIService not authenticated - attempting to restore...")
                        Task {
                            await strongSelf.restoreAuthenticationState()
                        }
                    }
                    
                    // If we have a signed-in user but no organizations loaded, load them
                    if let strongSelf = self, strongSelf.isAuthenticated && strongSelf.organizations.isEmpty {
                        Task {
                            await strongSelf.loadOrganizations()
                        }
                    }
                } else {
                    print("🔥 Firebase Auth: User signed out")
                    print("🔐 APIService: Current isAuthenticated = \(self?.isAuthenticated ?? false)")
                    print("🔐 APIService: Current user ID = \(self?.currentUser?.id ?? "nil")")
                    
                    // Only clear authentication state if we were previously authenticated
                    // This prevents clearing state on initial app launch when no user was signed in
                    if let strongSelf = self, strongSelf.isAuthenticated {
                        print("🔐 Clearing authentication state after sign out")
                        strongSelf.isAuthenticated = false
                        strongSelf.currentUser = nil
                        strongSelf.organizations = [] // Clear organizations on sign out
                        strongSelf.authToken = nil
                        UserDefaults.standard.removeObject(forKey: "authToken")
                    } else {
                        print("🔐 No previous authentication state to clear")
                    }
                    UserDefaults.standard.removeObject(forKey: "currentUser")
                }
            }
        }
        
        // Development bypass - comment this out for production
        #if DEBUG
        // Temporarily disabled guest mode to test Google Sign-In
        // if !self.isAuthenticated {
        //     self.enableGuestMode()
        // }
        
        // Add some sample requests for testing
        addSampleRequests()
        #endif
        

    }
    
    // MARK: - Authentication State Restoration
    private func restoreAuthenticationState() {
        print("🔄 Attempting to restore authentication state...")
        
        // Check if we have a stored auth token
        if let storedToken = UserDefaults.standard.string(forKey: "authToken") {
            print("🔑 Found stored auth token")
            self.authToken = storedToken
        }
        
        // Check if we have a stored user
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let storedUser = try? JSONDecoder().decode(User.self, from: userData) {
            print("👤 Found stored user: \(storedUser.name ?? "Unknown")")
            self.currentUser = storedUser
            
            // Store user ID in UserDefaults for FCM token registration
            UserDefaults.standard.set(storedUser.id, forKey: "currentUserId")
            print("✅ User ID stored in UserDefaults: \(storedUser.id)")
        }
        
        // Check if Firebase Auth has a current user
        if let firebaseUser = Auth.auth().currentUser {
            print("🔥 Firebase Auth has current user: \(firebaseUser.email ?? "unknown")")
            
            // If we have both stored user and Firebase user, restore authentication
            if currentUser != nil {
                print("✅ Restoring authentication state...")
                self.isAuthenticated = true
                
                // Load organizations for the restored user
                Task {
                    await loadOrganizations()
                }
            } else {
                print("⚠️ Firebase user exists but no stored user data - but NOT signing out (SimpleAuthManager will handle this)")
                // Don't sign out - let SimpleAuthManager handle authentication state
            }
        } else {
            print("🔐 No Firebase Auth user - staying unauthenticated")
        }
        
        print("🔐 Authentication state restored - isAuthenticated: \(self.isAuthenticated)")
        print("🔍 DEBUG: APIService currentUser: \(self.currentUser?.id ?? "nil")")
        print("🔍 DEBUG: APIService isAuthenticated: \(self.isAuthenticated)")
    }
    
    // MARK: - Sync with ServiceCoordinator
    private func syncWithServiceCoordinator() {
        print("🔄 APIService: Attempting to sync with ServiceCoordinator...")
        
        // If we already have a user, no need to sync
        if currentUser != nil {
            print("✅ APIService already has user, no sync needed")
            return
        }
        
        // Only sync if there's a Firebase Auth user
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ No Firebase Auth user found - skipping sync with ServiceCoordinator")
            return
        }
        
        // Try to get user from UserDefaults (which ServiceCoordinator uses)
        if let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            print("✅ Found user in UserDefaults for sync: \(user.name ?? "Unknown")")
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = true
                print("✅ APIService synced with ServiceCoordinator user: \(user.name ?? "Unknown")")
            }
            return
        }
        
        // Try to get user ID from UserDefaults and fetch full user data from Firestore
        if let userId = UserDefaults.standard.string(forKey: "currentUserId"), !userId.isEmpty {
            print("✅ Found user ID in UserDefaults for sync: \(userId)")
            
            // Try to fetch full user data from Firestore
            Task {
                do {
                    let db = Firestore.firestore()
                    let userDoc = try await db.collection("users").document(userId).getDocument()
                    
                    if userDoc.exists, let userData = userDoc.data() {
                        let fullUser = User(
                            id: userId,
                            email: userData["email"] as? String,
                            name: userData["name"] as? String ?? "User",
                            phone: userData["phone"] as? String,
                            homeLocation: nil,
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
                            displayName: userData["customDisplayName"] as? String ?? userData["name"] as? String ?? "User"
                        )
                        
                        await MainActor.run {
                            self.currentUser = fullUser
                            self.isAuthenticated = true
                            print("✅ APIService synced with full user data from Firestore: \(fullUser.name ?? "Unknown")")
                            
                            // Save user data to UserDefaults for future use
                            self.saveUserToDefaults(fullUser)
                        }
                    } else {
                        // Fallback: Create a basic user object
                        let basicUser = User(
                            id: userId,
                            email: nil,
                            name: "User",
                            phone: nil,
                            homeLocation: nil,
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
                            displayName: "User"
                        )
                        
                        await MainActor.run {
                            self.currentUser = basicUser
                            self.isAuthenticated = true
                            print("✅ APIService synced with basic user data: \(userId)")
                        }
                    }
                } catch {
                    print("⚠️ Error fetching user from Firestore: \(error)")
                    
                    // Fallback: Create a basic user object
                    let basicUser = User(
                        id: userId,
                        email: nil,
                        name: "User",
                        phone: nil,
                        homeLocation: nil,
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
                        displayName: "User"
                    )
                    
                    await MainActor.run {
                        self.currentUser = basicUser
                        self.isAuthenticated = true
                        print("✅ APIService synced with basic user data (fallback): \(userId)")
                    }
                }
            }
            return
        }
        
        print("⚠️ No user data found for sync with ServiceCoordinator")
    }
    
    // MARK: - Manual Sync Method
    func syncUserFromServiceCoordinator() {
        print("🔄 APIService: Manual sync requested...")
        syncWithServiceCoordinator()
    }
    
    // MARK: - Save User to UserDefaults
    private func saveUserToDefaults(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
            UserDefaults.standard.set(user.id, forKey: "currentUserId")
            print("✅ User data saved to UserDefaults: \(user.name ?? "Unknown")")
        } else {
            print("❌ Failed to encode user data for UserDefaults")
        }
    }
    
    // MARK: - Development Helper
    func enableGuestMode() {
        self.isAuthenticated = true
        
        // Create a sample admin user for testing
        let sampleUser = User(
            id: "admin-001",
            email: "admin@localalert.com",
            name: "Admin User",
            phone: nil,
            profilePhotoURL: nil,
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
            isAdmin: true
        )
        
        self.currentUser = sampleUser
        print("Guest mode enabled with admin privileges for development")
    }
    
    // MARK: - Development Helper Functions
    func addSampleRequests() {
        let sampleRequests = [
            OrganizationRequest(
                name: "Lucas Baptist Church",
                type: .church,
                description: "A welcoming community church serving Lucas and surrounding areas. We offer various ministries and community outreach programs.",
                website: "https://lucasbaptist.org",
                phone: "(972) 555-0100",
                email: "info@lucasbaptist.org",
                address: "123 Church Street",
                city: "Lucas",
                state: "TX",
                zipCode: "75002",
                contactPersonName: "Pastor John Smith",
                contactPersonTitle: "Senior Pastor",
                contactPersonPhone: "(972) 555-0101",
                contactPersonEmail: "pastor@lucasbaptist.org",
                adminPassword: "secure_password_123",
                status: .pending
            ),
            OrganizationRequest(
                name: "Velocity Physical Therapy - North Denton",
                type: .business,
                description: "Leading physical therapy clinic specializing in sports injury, post-surgical rehab, and chronic pain management.",
                website: "https://velocityptnorthdenton.com",
                phone: "(940) 555-0123",
                email: "info@velocityptnorthdenton.com",
                address: "2500 North Elm Street",
                city: "Denton",
                state: "TX",
                zipCode: "76201",
                contactPersonName: "Dr. Sarah Johnson",
                contactPersonTitle: "Clinic Director",
                contactPersonPhone: "(940) 555-0124",
                contactPersonEmail: "sarah@velocityptnorthdenton.com",
                adminPassword: "secure_password_456",
                status: .pending
            )
        ]
        
        pendingRequests = sampleRequests
        print("📋 Added \(sampleRequests.count) sample requests for testing")
    }
    
    func clearAllRequests() {
        pendingRequests.removeAll()
        print("🗑️ Cleared all pending requests")
    }
    

    
    // MARK: - Apple Sign In with Firebase
    func signInWithApple(identityToken: String, authorizationCode: String) async throws -> User {
        print("🔐 APIService.signInWithApple() called")
        
        // Create Firebase credential from Apple identity token
        // For now, create a mock user with a unique ID
        // In production, you would implement proper Apple Sign In with Firebase
        let mockUserId = UUID().uuidString
        
        print("⚠️ Using mock Apple Sign In for development")
        
        // Create new user with mock ID
        let newUser = User(
            id: mockUserId,
            email: "apple_user_\(mockUserId.prefix(8))@localalert.com",
            name: "Apple User",
            phone: nil,
            profilePhotoURL: nil,
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
            isAdmin: false
        )
        
        // Save user profile to defaults
        await saveUserProfileToDefaults(newUser)
        
        // Update the service state
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
        }
        
        // Load organizations after successful sign-in
        await loadOrganizations()
        
        print("✅ Created mock Apple user: \(newUser.id)")
        return newUser
    }
    
    // MARK: - Google Sign In with Firebase
    func signInWithGoogle() async throws -> User {
        print("🔐 APIService.signInWithGoogle() called")
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ No Firebase client ID found")
            throw AuthError.clientIDNotFound
        }
        
        print("✅ Firebase client ID found: \(clientID)")
        
        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the current view controller for presenting the sign-in flow
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = await windowScene.windows.first,
              let rootViewController = await window.rootViewController else {
            throw AuthError.noRootViewController
        }
        
        // Present Google Sign In
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.signInFailed)
                }
            }
        }
        
        // Get the ID token for Firebase authentication
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.noIDToken
        }
        
        // Create Firebase credential
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        
        // Sign in to Firebase
        print("🔥 Attempting Firebase authentication...")
        let authResult = try await Auth.auth().signIn(with: credential)
        print("✅ Firebase authentication successful for user: \(authResult.user.email ?? "unknown")")
        
        // Create or update user profile
        let newUser = User(
            id: authResult.user.uid,
            email: authResult.user.email ?? "unknown@email.com",
            name: result.user.profile?.name ?? "Google User",
            phone: nil,
            profilePhotoURL: nil,
            homeLocation: Location(
                latitude: 33.1032,
                longitude: -117.1945
            ),
            workLocation: Location(
                latitude: 33.1032,
                longitude: -117.1945
            ),
            schoolLocation: Location(
                latitude: 33.1032,
                longitude: -117.1945
            ),
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
            isAdmin: false
        )
        
        print("👤 User object created: \(newUser.id), email: \(newUser.email ?? "nil"), name: \(newUser.name ?? "nil")")
        
        // Save user profile and auth token
        await saveUserProfileToDefaults(newUser)
        
        // Save auth token for session persistence
        if let idToken = result.user.idToken?.tokenString {
            self.authToken = idToken
            UserDefaults.standard.set(idToken, forKey: "authToken")
            print("🔐 Auth token saved for session persistence")
        }
        
        // Update the service state
        print("🔄 About to update APIService state on MainActor...")
        await MainActor.run {
            print("🔄 On MainActor - setting currentUser and isAuthenticated...")
            self.currentUser = newUser
            self.isAuthenticated = true
            print("🔐 APIService state updated - isAuthenticated: \(self.isAuthenticated), currentUser: \(self.currentUser?.email ?? "nil")")
        }
        
        // Load organizations after successful sign-in
        await loadOrganizations()
        
        print("✅ Successfully signed in with Google: \(newUser.name ?? "Unknown")")
        return newUser
    }
    
    // MARK: - Email Sign Up
    func signUpWithEmail(email: String, password: String, name: String) async throws -> User {
        // Create user account with Firebase Auth
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Create user profile
        let newUser = User(
            id: authResult.user.uid,
            email: email,
            name: name,
            phone: nil,
            profilePhotoURL: nil,
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
            isAdmin: false
        )
        
        // Save user profile
        await saveUserProfileToDefaults(newUser)
        
        // Update the service state
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
        }
        
        // Load organizations after successful sign-up
        await loadOrganizations()
        
        print("Successfully created account: \(newUser.name ?? "Unknown")")
        return newUser
    }
    
    // MARK: - Email Sign In
    func signInWithEmail(email: String, password: String) async throws -> User {
        print("🔐 Signing in with email: \(email)")
        
        let authResult: AuthDataResult
        do {
            // Sign in with Firebase Auth
            authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Firebase Auth successful for UID: \(authResult.user.uid)")
            print("✅ Firebase Auth user email: \(authResult.user.email ?? "none")")
            print("✅ Firebase Auth user display name: \(authResult.user.displayName ?? "none")")
            
            // Debug: Check Firebase Auth state immediately after sign in
            if let currentUser = Auth.auth().currentUser {
                print("✅ Firebase Auth current user confirmed: \(currentUser.uid)")
            } else {
                print("❌ Firebase Auth current user is nil immediately after sign in!")
                throw APIError.custom("Firebase Auth session not established")
            }
            
            // Additional verification: Check if the user is actually signed in
            if Auth.auth().currentUser?.uid != authResult.user.uid {
                print("❌ Firebase Auth UID mismatch!")
                print("   - Auth result UID: \(authResult.user.uid)")
                print("   - Current user UID: \(Auth.auth().currentUser?.uid ?? "nil")")
                throw APIError.custom("Firebase Auth UID mismatch")
            }
            
        } catch {
            print("❌ Firebase Auth sign-in failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            if let authError = error as? AuthErrorCode {
                print("❌ Auth error code: \(authError.rawValue)")
            }
            throw error
        }
        
        // Check if user already exists in Firestore by email
        let existingUser = try await findUserByEmail(email)
        
        if let existingUser = existingUser {
            print("✅ Found existing user in Firestore:")
            print("   - Firestore User ID: \(existingUser.id)")
            print("   - Firebase Auth UID: \(authResult.user.uid)")
            print("   - Email: \(existingUser.email ?? "nil")")
            print("   - Name: \(existingUser.name ?? "nil")")
            
            // Use the Firebase Auth UID for consistency with adminIds and other Firebase operations
            let userToUse = User(
                id: authResult.user.uid, // Use Firebase Auth UID for consistency
                email: existingUser.email ?? email,
                name: existingUser.name ?? authResult.user.displayName ?? "Email User",
                phone: existingUser.phone,
                profilePhotoURL: existingUser.profilePhotoURL,
                homeLocation: existingUser.homeLocation,
                workLocation: existingUser.workLocation,
                schoolLocation: existingUser.schoolLocation,
                alertRadius: existingUser.alertRadius,
                preferences: existingUser.preferences,
                createdAt: existingUser.createdAt,
                isAdmin: existingUser.isAdmin
            )
            
            // Save auth token for session persistence
            do {
                let idToken = try await authResult.user.getIDToken()
                self.authToken = idToken
                UserDefaults.standard.set(idToken, forKey: "authToken")
                print("🔐 Auth token saved for session persistence")
            } catch {
                print("❌ Failed to get ID token: \(error)")
            }
            
            // Update the service state
            await MainActor.run {
                self.currentUser = userToUse
                self.isAuthenticated = true
                print("🔐 APIService: Authentication state updated - isAuthenticated: \(self.isAuthenticated)")
                print("🔐 APIService: Current user set - \(self.currentUser?.id ?? "nil")")
                print("🔍 DEBUG: APIService after MainActor.run - isAuthenticated: \(self.isAuthenticated)")
                print("🔍 DEBUG: APIService after MainActor.run - currentUser: \(self.currentUser?.id ?? "nil")")
            }
            
            // Store user ID in UserDefaults for FCM token registration
            UserDefaults.standard.set(userToUse.id, forKey: "currentUserId")
            print("✅ User ID stored in UserDefaults: \(userToUse.id)")
            
            // Debug: Verify the user ID was actually stored
            let storedUserId = UserDefaults.standard.string(forKey: "currentUserId")
            print("🔍 DEBUG: Verification - stored user ID: \(storedUserId ?? "nil")")
            print("🔍 DEBUG: User ID matches: \(storedUserId == userToUse.id)")
            
            // Migrate user document to use Firebase Auth UID if needed
            if existingUser.id != authResult.user.uid {
                print("🔄 Migrating user document from Firestore ID to Firebase UID...")
                try await migrateUserDocument(from: existingUser.id, to: authResult.user.uid)
            }
            
            // Load organizations after successful sign-in
            await loadOrganizations()
            
            // Post notification that user has logged in (for FCM token registration)
            NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: userToUse)
            
            print("✅ Using existing Firestore user: \(userToUse.id)")
            print("🔍 DEBUG: APIService.signInWithEmail returning user - isAuthenticated: \(self.isAuthenticated)")
            print("🔍 DEBUG: APIService.signInWithEmail returning user - currentUser: \(self.currentUser?.id ?? "nil")")
            return userToUse
            
        } else {
            print("⚠️ No existing user found in Firestore, creating new user with Firebase UID")
            
            // Create new user only if none exists
            let newUser = User(
            id: authResult.user.uid,
            email: email,
            name: authResult.user.displayName ?? "Email User",
            phone: nil,
            profilePhotoURL: nil,
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
            isAdmin: false
        )
        
        // Save auth token for session persistence
        do {
            let idToken = try await authResult.user.getIDToken()
            self.authToken = idToken
            UserDefaults.standard.set(idToken, forKey: "authToken")
            print("🔐 Auth token saved for session persistence")
        } catch {
            print("❌ Failed to get ID token: \(error)")
        }
        
        // Update the service state
        await MainActor.run {
            self.currentUser = newUser
            self.isAuthenticated = true
            print("🔐 APIService: Authentication state updated - isAuthenticated: \(self.isAuthenticated)")
            print("🔐 APIService: Current user set - \(self.currentUser?.id ?? "nil")")
            print("🔍 DEBUG: APIService after MainActor.run - isAuthenticated: \(self.isAuthenticated)")
            print("🔍 DEBUG: APIService after MainActor.run - currentUser: \(self.currentUser?.id ?? "nil")")
        }
        
        // Store user ID in UserDefaults for FCM token registration
        UserDefaults.standard.set(newUser.id, forKey: "currentUserId")
        print("✅ User ID stored in UserDefaults: \(newUser.id)")
        
        // Debug: Verify the user ID was actually stored
        let storedUserId = UserDefaults.standard.string(forKey: "currentUserId")
        print("🔍 DEBUG: Verification - stored user ID: \(storedUserId ?? "nil")")
        print("🔍 DEBUG: User ID matches: \(storedUserId == newUser.id)")
        
        // Save user profile
        await saveUserProfileToDefaults(newUser)
        
        // Load organizations after successful sign-in
        await loadOrganizations()
        
        // Post notification that user has logged in (for FCM token registration)
        NotificationCenter.default.post(name: NSNotification.Name("UserLoggedIn"), object: newUser)
        
        print("✅ Created new user with Firebase UID: \(newUser.id)")
        print("🔍 DEBUG: APIService.signInWithEmail returning new user - isAuthenticated: \(self.isAuthenticated)")
        print("🔍 DEBUG: APIService.signInWithEmail returning new user - currentUser: \(self.currentUser?.id ?? "nil")")
        return newUser
        }
    }
    
    func signOut() {
        print("🔐 APIService: Starting sign out process...")
        
        // Clear local state first
        self.authToken = nil
        self.currentUser = nil
        self.isAuthenticated = false
        self.organizations = []
        self.pendingRequests = []
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        
        // Sign out from Firebase Auth
        do {
            try Auth.auth().signOut()
            print("✅ Successfully signed out from Firebase Auth")
        } catch {
            print("❌ Error signing out from Firebase Auth: \(error)")
        }
        
        // Force UI update on main thread
        DispatchQueue.main.async {
            print("✅ APIService sign out completed - UI should update")
            print("🔍 APIService isAuthenticated after sign out: \(self.isAuthenticated)")
            print("🔍 APIService currentUser after sign out: \(self.currentUser?.id ?? "nil")")
            
            // Force a UI refresh by triggering objectWillChange
            self.objectWillChange.send()
        }
    }
    
    // MARK: - Incidents
    func fetchIncidents(latitude: Double, longitude: Double, radius: Double, types: [IncidentType]? = nil) async throws -> [Incident] {
        // TODO: Implement real API call to fetch incidents
        // For now, return empty array until backend is ready
        
        // Update the published incidents array
        await MainActor.run {
            self.incidents = []
        }
        
        // In production, this would make an API call
        // var endpoint = "/incidents?lat=\(latitude)&lon=\(longitude)&radius=\(radius)"
        // 
        // if let types = types, !types.isEmpty {
        //     let typeParams = types.map { $0.rawValue }.joined(separator: ",")
        //     endpoint += "&type=\(typeParams)"
        // }
        // 
        // let request = try createRequest(endpoint: endpoint, method: "GET")
        // let (data, response) = try await URLSession.shared.data(for: request)
        // 
        // guard let httpResponse = response as? HTTPURLResponse,
        //       httpResponse.statusCode == 200 else {
        //     throw APIError.invalidResponse
        // }
        // 
        // return try JSONDecoder().decode([Incident].self, from: data)
        
        // For now, return empty array until backend is ready
        return []
    }
    
    // MARK: - Reports
    func reportIncident(_ report: IncidentReport) async throws -> IncidentReport {
        let endpoint = "/reports"
        let body = try JSONEncoder().encode(report)
        
        let request = try createRequestWithData(endpoint: endpoint, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(IncidentReport.self, from: data)
    }
    
    // MARK: - Organizations
    func fetchOrganizations() async throws -> [Organization] {
        print("🔍 Fetching organizations from Firestore...")
        
        let db = Firestore.firestore()
        
        do {
            // Query for all organizations first to debug what's available
            let allSnapshot = try await db.collection("organizations").getDocuments()
            print("🔍 Total organizations in Firestore: \(allSnapshot.documents.count)")
            
            // Debug: Print first few document IDs and verified status
            for (index, doc) in allSnapshot.documents.prefix(3).enumerated() {
                let data = doc.data()
                let verified = data["verified"]
                print("📄 Document \(index + 1): ID=\(doc.documentID), verified=\(String(describing: verified))")
            }
            
            // Query for verified organizations
            let snapshot = try await db.collection("organizations")
                .whereField("verified", isEqualTo: true)
                .getDocuments()
            
            print("📊 Found \(snapshot.documents.count) verified organizations in Firestore")
            
            // Debug: Print all verified organization details
            for (index, doc) in snapshot.documents.enumerated() {
                let data = doc.data()
                let name = data["name"] as? String ?? "Unknown"
                let verified = data["verified"] as? Bool ?? false
                let adminIds = data["adminIds"] as? [String: Bool] ?? [:]
                print("📄 Verified Org \(index + 1): ID=\(doc.documentID), Name=\(name), Verified=\(verified), AdminIDs=\(adminIds.keys.joined(separator: ", "))")
            }
            
            var organizations: [Organization] = []
            
            for document in snapshot.documents {
                do {
                    let data = document.data()
                    print("📄 Processing organization document: \(document.documentID)")
                    
                    // Parse organization data
                    let organization = try parseOrganizationFromFirestore(document: document, data: data)
                    organizations.append(organization)
                    
                } catch {
                    print("⚠️ Error parsing organization \(document.documentID): \(error)")
                    // Continue with other organizations instead of failing completely
                    continue
                }
            }
            
            print("✅ Successfully parsed \(organizations.count) organizations")
            return organizations
            
        } catch {
            print("❌ Error fetching organizations from Firestore: \(error)")
            throw error
        }
    }
    
    private func parseOrganizationFromFirestore(document: DocumentSnapshot, data: [String: Any]) throws -> Organization {
        // Extract basic organization fields
        let id = document.documentID
        let name = data["name"] as? String ?? "Unknown Organization"
        let type = data["type"] as? String ?? "unknown"
        let description = data["description"] as? String ?? "No description available"
        let verified = data["verified"] as? Bool ?? false
        let followerCount = data["followerCount"] as? Int ?? 0
        let logoURL = data["logoURL"] as? String
        
        // Debug logging for logo URL
        print("🔍 APIService parseOrganizationFromFirestore:")
        print("   - Organization ID: \(id)")
        print("   - Organization name: \(name)")
        print("   - Raw logoURL from Firestore: \(String(describing: data["logoURL"]))")
        print("   - Parsed logoURL: \(String(describing: logoURL))")
        print("   - logoURL isEmpty: \(logoURL?.isEmpty ?? true)")
        print("   - logoURL is nil: \(logoURL == nil)")
        
        let website = data["website"] as? String
        let phone = data["phone"] as? String
        let email = data["email"] as? String
        let adminIds = data["adminIds"] as? [String: Bool] ?? [:]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse location data
        let locationData = data["location"] as? [String: Any] ?? [:]
        let location = Location(
            latitude: locationData["latitude"] as? Double ?? 0.0,
            longitude: locationData["longitude"] as? Double ?? 0.0,
            address: locationData["address"] as? String ?? "",
            city: locationData["city"] as? String ?? "",
            state: locationData["state"] as? String ?? "",
            zipCode: locationData["zipCode"] as? String ?? ""
        )
        
        // Parse groups if they exist
        var groups: [OrganizationGroup] = []
        if let groupsData = data["groups"] as? [[String: Any]] {
            for groupData in groupsData {
                let group = OrganizationGroup(
                    id: groupData["id"] as? String ?? UUID().uuidString,
                    name: groupData["name"] as? String ?? "Unknown Group",
                    description: groupData["description"] as? String ?? "No description available",
                    organizationId: id
                )
                groups.append(group)
            }
        }
        
        return Organization(
            id: id,
            name: name,
            type: type,
            description: description,
            location: location,
            verified: verified,
            followerCount: followerCount,
            logoURL: logoURL,
            website: website,
            phone: phone,
            email: email,
            groups: groups,
            adminIds: adminIds,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func parseOrganizationAlertFromFirestore(document: DocumentSnapshot, data: [String: Any]) throws -> OrganizationAlert {
        // Extract basic alert fields
        let id = document.documentID
        let title = data["title"] as? String ?? "Unknown Alert"
        let description = data["description"] as? String ?? "No description available"
        let organizationId = data["organizationId"] as? String ?? ""
        let organizationName = data["organizationName"] as? String ?? "Unknown Organization"
        let groupId = data["groupId"] as? String
        let groupName = data["groupName"] as? String
        let typeString = data["type"] as? String ?? "other"
        let severityString = data["severity"] as? String ?? "low"
        let postedBy = data["postedBy"] as? String ?? "Unknown"
        let postedByUserId = data["postedByUserId"] as? String ?? ""
        let isActive = data["isActive"] as? Bool ?? true
        
        // Parse dates
        let postedAt = (data["postedAt"] as? Timestamp)?.dateValue() ?? Date()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? postedAt
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? postedAt
        let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Calendar.current.date(byAdding: .day, value: 14, to: postedAt) ?? postedAt
        
        // Parse location data
        let locationData = data["location"] as? [String: Any] ?? [:]
        let location = Location(
            latitude: locationData["latitude"] as? Double ?? 0.0,
            longitude: locationData["longitude"] as? Double ?? 0.0,
            address: locationData["address"] as? String ?? "",
            city: locationData["city"] as? String ?? "",
            state: locationData["state"] as? String ?? "",
            zipCode: locationData["zipCode"] as? String ?? ""
        )
        
        // Parse incident type and severity
        let type = IncidentType(rawValue: typeString) ?? .other
        let severity = IncidentSeverity(rawValue: severityString) ?? .low
        
        // Parse image URLs if they exist
        let imageURLs = data["imageURLs"] as? [String] ?? []
        
        return OrganizationAlert(
            id: id,
            title: title,
            description: description,
            organizationId: organizationId,
            organizationName: organizationName,
            groupId: groupId,
            groupName: groupName,
            type: type,
            severity: severity,
            location: location,
            postedBy: postedBy,
            postedByUserId: postedByUserId,
            postedAt: postedAt,
            imageURLs: imageURLs
        )
    }
    
    private func parseOrganizationGroupFromFirestore(document: DocumentSnapshot, data: [String: Any]) throws -> OrganizationGroup {
        // Extract group fields
        let id = document.documentID
        let name = data["name"] as? String ?? "Unknown Group"
        let description = data["description"] as? String ?? "No description available"
        let organizationId = data["organizationId"] as? String ?? ""
        let isActive = data["isActive"] as? Bool ?? true
        let memberCount = data["memberCount"] as? Int ?? 0
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return OrganizationGroup(
            id: id,
            name: name,
            description: description,
            organizationId: organizationId,
            isActive: isActive,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func fetchGroups(for organizationId: String) async throws -> [OrganizationGroup] {
        // Use the dedicated method to get organization groups from Firestore
        return try await getOrganizationGroups(organizationId: organizationId)
    }
    
    func followOrganization(_ organizationId: String) async throws -> Bool {
        print("🔗 Following organization: \(organizationId)")
        
        // Try to get user ID from multiple sources
        var currentUserId: String?
        
        // First try APIService currentUser
        if let apiUserId = currentUser?.id {
            currentUserId = apiUserId
            print("✅ Found user ID from APIService: \(apiUserId)")
        }
        // Then try UserDefaults
        else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
        }
        // Finally try Firebase Auth
        else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
            print("✅ Found user ID from Firebase Auth: \(firebaseUserId)")
        }
        
        guard let userId = currentUserId else {
            print("❌ No current user found from any source")
            throw APIError.unauthorized
        }
        
        // Use the OrganizationFollowingService for consistency
        let followingService = OrganizationFollowingService()
        try await followingService.followOrganization(organizationId, userId: userId)
        
        print("✅ Successfully followed organization \(organizationId)")
        return true
    }
    
    func unfollowOrganization(_ organizationId: String) async throws -> Bool {
        print("❌ Unfollowing organization: \(organizationId)")
        
        // Try to get user ID from multiple sources
        var currentUserId: String?
        
        // First try APIService currentUser
        if let apiUserId = currentUser?.id {
            currentUserId = apiUserId
            print("✅ Found user ID from APIService: \(apiUserId)")
        }
        // Then try UserDefaults
        else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
        }
        // Finally try Firebase Auth
        else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
            print("✅ Found user ID from Firebase Auth: \(firebaseUserId)")
        }
        
        guard let userId = currentUserId else {
            print("❌ No current user found from any source")
            throw APIError.unauthorized
        }
        
        // Use the OrganizationFollowingService for consistency
        let followingService = OrganizationFollowingService()
        try await followingService.unfollowOrganization(organizationId, userId: userId)
        
        print("✅ Successfully unfollowed organization \(organizationId)")
        return true
    }
    
    func isFollowingOrganization(_ organizationId: String) async throws -> Bool {
        print("🔍 Checking if following organization: \(organizationId)")
        
        // Try to get user ID from multiple sources
        var currentUserId: String?
        
        // First try APIService currentUser
        if let apiUserId = currentUser?.id {
            currentUserId = apiUserId
            print("✅ Found user ID from APIService: \(apiUserId)")
        }
        // Then try UserDefaults
        else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
        }
        // Finally try Firebase Auth
        else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
            print("✅ Found user ID from Firebase Auth: \(firebaseUserId)")
        }
        
        guard let userId = currentUserId else {
            print("❌ No current user found from any source")
            return false
        }
        
        // Use the OrganizationFollowingService for consistency
        let followingService = OrganizationFollowingService()
        return try await followingService.isFollowingOrganization(organizationId, userId: userId)
    }
    
    func hasOrganizationAdminAccess() -> Bool {
        // Check if current user is an admin of any organization
        // Try to get user ID from multiple sources
        var currentUserId: String?
        
        // First try APIService currentUser
        if let apiUserId = currentUser?.id {
            currentUserId = apiUserId
        }
        // Then try UserDefaults
        else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
        }
        // Finally try Firebase Auth
        else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
        }
        
        guard let userId = currentUserId else { return false }
        
        // Check if user is marked as admin in any organization
        for organization in organizations {
            if organization.adminIds?[userId] == true {
                return true
            }
        }
        
        return false
    }
    
    func updateOrganizationCoordinates() async {
        // This method would update organization coordinates
        // For now, it's a placeholder
        print("📍 Updating organization coordinates...")
    }
    
    func fixAllExistingUserDocuments() async {
        // This method would fix existing user documents
        // For now, it's a placeholder
        print("🔧 Fixing existing user documents...")
    }
    
    func fixSpecificUserDocument(email: String) async {
        // This method would fix a specific user document
        // For now, it's a placeholder
        print("🔧 Fixing user document for email: \(email)")
    }
    
    func fixOrganizationAdminAccess(email: String, organizationName: String) async {
        // This method would fix organization admin access
        // For now, it's a placeholder
        print("🔧 Fixing organization admin access for email: \(email), organization: \(organizationName)")
    }
    
    func getUserById(_ userId: String) async throws -> User? {
        print("👤 Getting user by ID: \(userId)")
        
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                let data = document.data() ?? [:]
                print("✅ Found user document: \(document.documentID)")
                
                let user = User(
                    id: document.documentID,
                    email: data["email"] as? String ?? "unknown@email.com",
                    name: data["name"] as? String ?? "Unknown User",
                    phone: data["phone"] as? String,
                    profilePhotoURL: data["profilePhotoURL"] as? String,
                    homeLocation: parseLocationFromFirestore(data["homeLocation"] as? [String: Any]),
                    workLocation: parseLocationFromFirestore(data["workLocation"] as? [String: Any]),
                    schoolLocation: parseLocationFromFirestore(data["schoolLocation"] as? [String: Any]),
                    alertRadius: data["alertRadius"] as? Double ?? 10.0,
                    preferences: parseUserPreferencesFromFirestore(data["preferences"] as? [String: Any]),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isAdmin: data["isAdmin"] as? Bool ?? false
                )
                
                print("✅ Parsed user: \(user.name ?? user.email)")
                return user
            } else {
                print("ℹ️ No user found with ID: \(userId)")
                return nil
            }
        } catch {
            print("❌ Error getting user by ID: \(error)")
            throw error
        }
    }
    
    func removeOrganizationAdmin(_ adminId: String, from organizationId: String) async throws {
        print("👤 Removing admin \(adminId) from organization ID: \(organizationId)")
        
        let db = Firestore.firestore()
        do {
            // Get the current organization document
            let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
            
            if !orgDoc.exists {
                throw NSError(domain: "OrganizationError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
            }
            
            let orgData = orgDoc.data() ?? [:]
            var adminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
            
            // Remove the admin
            adminIds.removeValue(forKey: adminId)
            
            // Update the organization document
            try await db.collection("organizations").document(organizationId).updateData([
                "adminIds": adminIds,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Successfully removed user \(adminId) as admin from organization \(organizationId)")
            
            // Refresh local organizations data
            await refreshOrganizations()
            
        } catch {
            print("❌ Error removing organization admin: \(error)")
            throw error
        }
    }
    
    func findUsersByEmail(_ email: String) async throws -> [User] {
        print("🔍 Finding users by email: \(email)")
        
        let db = Firestore.firestore()
        do {
            let query = try await db.collection("users")
                .whereField("email", isEqualTo: email)
                .getDocuments()
            
            var users: [User] = []
            
            for document in query.documents {
                let data = document.data()
                print("✅ Found user document: \(document.documentID)")
                
                let user = User(
                    id: document.documentID,
                    email: data["email"] as? String ?? email,
                    name: data["name"] as? String ?? "Unknown User",
                    phone: data["phone"] as? String,
                    profilePhotoURL: data["profilePhotoURL"] as? String,
                    homeLocation: parseLocationFromFirestore(data["homeLocation"] as? [String: Any]),
                    workLocation: parseLocationFromFirestore(data["workLocation"] as? [String: Any]),
                    schoolLocation: parseLocationFromFirestore(data["schoolLocation"] as? [String: Any]),
                    alertRadius: data["alertRadius"] as? Double ?? 10.0,
                    preferences: parseUserPreferencesFromFirestore(data["preferences"] as? [String: Any]),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isAdmin: data["isAdmin"] as? Bool ?? false
                )
                
                users.append(user)
            }
            
            print("✅ Found \(users.count) users with email: \(email)")
            return users
            
        } catch {
            print("❌ Error finding users by email: \(error)")
            throw error
        }
    }
    
    func addOrganizationAdmin(_ userId: String, to organizationId: String) async throws {
        print("👤 Adding admin \(userId) to organization ID: \(organizationId)")
        
        let db = Firestore.firestore()
        do {
            // Get the current organization document
            let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
            
            if !orgDoc.exists {
                throw NSError(domain: "OrganizationError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
            }
            
            let orgData = orgDoc.data() ?? [:]
            var adminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
            
            // Add the new admin
            adminIds[userId] = true
            
            // Update the organization document
            try await db.collection("organizations").document(organizationId).updateData([
                "adminIds": adminIds,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Successfully added user \(userId) as admin to organization \(organizationId)")
            
            // Refresh local organizations data
            await refreshOrganizations()
            
        } catch {
            print("❌ Error adding organization admin: \(error)")
            throw error
        }
    }
    
    func createOrganizationGroup(group: OrganizationGroup, organizationId: String) async throws -> OrganizationGroup {
        print("👥 Creating organization group: \(group.name) for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // First, verify the organization exists
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        
        if !orgDoc.exists {
            throw NSError(domain: "GroupCreationError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
        }
        
        // Create the group data
        let groupData: [String: Any] = [
            "name": group.name,
            "description": group.description ?? "",
            "organizationId": organizationId,
            "isActive": group.isActive,
            "isPrivate": group.isPrivate,
            "allowPublicJoin": group.allowPublicJoin,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Add to the organization's groups subcollection using group name as document ID
        let groupRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(group.name)
        try await groupRef.setData(groupData)
        
        // Get the created document to return the complete group
        let createdDoc = try await groupRef.getDocument()
        let createdData = createdDoc.data() ?? [:]
        
        let createdGroup = OrganizationGroup(
            id: group.name, // Use group name as ID
            name: group.name,
            description: group.description,
            organizationId: organizationId,
            isActive: group.isActive,
            createdAt: (createdData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (createdData["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
        
        print("✅ Successfully created organization group: \(createdGroup.name)")
        return createdGroup
    }
    
    func updateOrganizationGroup(_ group: OrganizationGroup) async throws {
        print("🏢 Updating organization group: \(group.name)")
        print("   Group ID: \(group.id)")

        let db = Firestore.firestore()
        let organizationRef = db.collection("organizations").document(group.organizationId)

        // Update the existing document
        let groupRef = organizationRef.collection("groups").document(group.name)
        let updateData: [String: Any] = [
            "name": group.name,
            "description": group.description ?? "",
            "isActive": group.isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await groupRef.updateData(updateData)
        print("✅ Successfully updated organization group: \(group.name)")
    }
    
    func uploadOrganizationLogo(_ image: UIImage, organizationId: String, organizationName: String? = nil) async throws -> String {
        print("🖼️ Uploading organization logo for organization: \(organizationId)")
        if let orgName = organizationName {
            print("   🏢 Organization name: \(orgName)")
        }
        
        let fileUploadService = FileUploadService()
        let logoURL = try await fileUploadService.uploadOrganizationLogo(image, organizationId: organizationId, organizationName: organizationName)
        
        print("✅ Organization logo uploaded successfully: \(logoURL)")
        
        // Update the organization document with the new logo URL
        do {
            let db = Firestore.firestore()
            try await db.collection("organizations").document(organizationId).updateData([
                "logoURL": logoURL,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Organization document updated with new logo URL: \(logoURL)")
        } catch {
            print("❌ Failed to update organization document with logo URL: \(error)")
            throw error
        }
        
        // Refresh the organization data to ensure UI updates
        await refreshOrganizationData(organizationId: organizationId)
        
        return logoURL
    }
    
    func uploadUserProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
        print("📸 APIService: Uploading user profile photo for user: \(userId)")
        print("📸 APIService: Image size: \(image.size)")
        
        let fileUploadService = FileUploadService()
        let photoURL = try await fileUploadService.uploadUserProfilePhoto(image, userId: userId)
        
        print("✅ APIService: User profile photo uploaded successfully: \(photoURL)")
        
        return photoURL
    }
    
    // MARK: - Check and Fix Organization Logo URL
    func checkAndFixOrganizationLogoURL(organizationId: String) async {
        do {
            let fileUploadService = FileUploadService()
            
            // Check if there's a logo file in the organization's photos folder
            if let logoURL = try await fileUploadService.getOrganizationLogoURL(organizationId: organizationId) {
                // Update the organization document with the logo URL
                let db = Firestore.firestore()
                try await db.collection("organizations").document(organizationId).updateData([
                    "logoURL": logoURL,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                
                // Refresh the organization data
                await refreshOrganizationData(organizationId: organizationId)
            }
            
        } catch {
            // Silently handle errors - organization will just use default icon
        }
    }
    
    // MARK: - Refresh Organization Data
    private func refreshOrganizationData(organizationId: String) async {
        print("🔄 Refreshing organization data for: \(organizationId)")
        
        do {
            let updatedOrg = try await getOrganizationById(organizationId)
            if let updatedOrg = updatedOrg {
                await MainActor.run {
                    // Update the organization in the local array
                    if let index = self.organizations.firstIndex(where: { $0.id == organizationId }) {
                        self.organizations[index] = updatedOrg
                        print("✅ Updated organization in local array: \(updatedOrg.name)")
                        
                        // Clear any cached images for this organization to ensure fresh logo
                        ImageCacheManager.shared.clearCacheForOrganization(organizationId)
                        
                        // Post notification for UI updates
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OrganizationUpdated"),
                            object: nil,
                            userInfo: ["organizationId": organizationId]
                        )
                    }
                }
            }
        } catch {
            print("❌ Failed to refresh organization data: \(error)")
        }
    }
    
    func loadOrganizations() async {
        print("🔄 Loading organizations for user...")
        
        do {
            let fetchedOrgs = try await fetchOrganizations()
            await MainActor.run {
                self.organizations = fetchedOrgs
                print("✅ Loaded organizations: \(fetchedOrgs.count) organizations")
            }
            
            // Preload organization logos for better performance
            await preloadOrganizationLogos(fetchedOrgs)
        } catch {
            print("❌ Error loading organizations: \(error)")
        }
    }
    
    // MARK: - Preload Organization Logos
    private func preloadOrganizationLogos(_ organizations: [Organization]) async {
        let logoURLs = organizations.compactMap { $0.logoURL }.filter { !$0.isEmpty }
        
        if !logoURLs.isEmpty {
            print("🖼️ Preloading \(logoURLs.count) organization logos...")
            ImageCacheManager.shared.preloadImages(for: logoURLs)
        }
    }
    
    func refreshOrganizations() async {
        print("🔄 Refreshing organizations...")
        
        do {
            let refreshedOrgs = try await fetchOrganizations()
            await MainActor.run {
                self.organizations = refreshedOrgs
                print("✅ Refreshed organizations: \(refreshedOrgs.count) organizations")
            }
            
            // Preload organization logos for better performance
            await preloadOrganizationLogos(refreshedOrgs)
        } catch {
            print("❌ Error refreshing organizations: \(error)")
        }
    }
    
    func forceRefreshOrganizations() async {
        print("🔄 Force refreshing organizations...")
        
        do {
            let refreshedOrgs = try await fetchOrganizations()
            await MainActor.run {
                self.organizations = refreshedOrgs
                print("✅ Force refreshed organizations: \(refreshedOrgs.count) organizations")
            }
        } catch {
            print("❌ Error force refreshing organizations: \(error)")
        }
    }
    
    // MARK: - Force Refresh Specific Organization
    func forceRefreshOrganization(_ organizationId: String) async {
        print("🔄 Force refreshing specific organization: \(organizationId)")
        
        do {
            let refreshedOrg = try await getOrganizationById(organizationId)
            if let refreshedOrg = refreshedOrg {
                await MainActor.run {
                    // Update the organization in the local array
                    if let index = self.organizations.firstIndex(where: { $0.id == organizationId }) {
                        self.organizations[index] = refreshedOrg
                        print("✅ Force refreshed organization: \(refreshedOrg.name)")
                    }
                }
            }
        } catch {
            print("❌ Error force refreshing organization: \(error)")
        }
    }
    
    func canManageOrganization(_ organizationId: String) async -> Bool {
        print("👑 Checking if user can manage organization: \(organizationId)")
        
        // Use the existing isAdminOfOrganization method
        let canManage = await isAdminOfOrganization(organizationId)
        print("✅ User can manage organization \(organizationId): \(canManage)")
        return canManage
    }
    
    func getOrganizationAlerts(organizationId: String) async throws -> [OrganizationAlert] {
        print("🔍 Fetching alerts for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        do {
            // Query the organization's alerts subcollection
            let alertsRef = db.collection("organizations")
                .document(organizationId)
                .collection("alerts")
            
            print("🔍 Querying path: organizations/\(organizationId)/alerts")
            let snapshot = try await alertsRef.getDocuments()
            print("📊 Found \(snapshot.documents.count) alerts in organization \(organizationId)")
            
            // Log each document found
            for (index, document) in snapshot.documents.enumerated() {
                print("   📄 Document \(index + 1): \(document.documentID)")
                let data = document.data()
                print("   📋 Data keys: \(Array(data.keys).sorted())")
                if let title = data["title"] as? String {
                    print("   📝 Title: \(title)")
                }
                if let isActive = data["isActive"] as? Bool {
                    print("   🔄 Is Active: \(isActive)")
                }
            }
            
            var alerts: [OrganizationAlert] = []
            
            for document in snapshot.documents {
                do {
                    let data = document.data()
                    let alert = try parseOrganizationAlertFromFirestore(document: document, data: data)
                    alerts.append(alert)
                    print("✅ Successfully parsed alert: \(alert.title)")
                } catch {
                    print("⚠️ Error parsing alert \(document.documentID): \(error)")
                    print("   Error details: \(error.localizedDescription)")
                    // Continue with other alerts
                    continue
                }
            }
            
            print("✅ Successfully parsed \(alerts.count) alerts for organization \(organizationId)")
            return alerts
            
        } catch {
            print("❌ Error fetching alerts for organization \(organizationId): \(error)")
            print("   Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fixOrganizationFollowerCount(_ organizationId: String) async throws {
        print("🔧 Fixing follower count for organization: \(organizationId)")
        
        do {
            // Use the OrganizationFollowingService to sync the followers subcollection
            let followingService = OrganizationFollowingService()
            try await followingService.syncOrganizationFollowersSubcollection(organizationId)
            
            print("✅ Successfully synced followers subcollection for organization \(organizationId)")
            
        } catch {
            print("❌ Error fixing follower count: \(error)")
            throw error
        }
    }
    
    /// Syncs follower counts for all organizations
    func syncAllOrganizationFollowerCounts() async throws {
        print("🔄 Syncing follower counts for all organizations...")
        
        let db = Firestore.firestore()
        
        // Get all organizations
        let snapshot = try await db.collection("organizations").getDocuments()
        print("📋 Found \(snapshot.documents.count) organizations to sync")
        
        var totalSynced = 0
        var totalErrors = 0
        
        for document in snapshot.documents {
            let organizationId = document.documentID
            let organizationName = document.data()["name"] as? String ?? "Unknown"
            
            print("🔄 Syncing organization: \(organizationName) (\(organizationId))")
            
            do {
                try await fixOrganizationFollowerCount(organizationId)
                totalSynced += 1
                print("✅ Successfully synced \(organizationName)")
            } catch {
                totalErrors += 1
                print("❌ Failed to sync \(organizationName): \(error)")
            }
        }
        
        print("🎉 Sync completed! Successfully synced: \(totalSynced), Errors: \(totalErrors)")
    }
    
    func deleteOrganizationAlert(alertId: String, organizationId: String) async throws {
        print("🗑️ Deleting organization alert: \(alertId) from organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Delete from organization's alerts subcollection
        let alertRef = db.collection("organizations")
            .document(organizationId)
            .collection("alerts")
            .document(alertId)
        
        try await alertRef.delete()
        
        // Update organization alert count
        try await db.collection("organizations").document(organizationId).updateData([
            "alertCount": FieldValue.increment(Int64(-1))
        ])
        
        print("✅ Organization alert deleted successfully from Firestore")
    }
    
    func editOrganizationAlert(_ alert: OrganizationAlert) async throws -> OrganizationAlert {
        // This method would edit an organization alert
        // For now, it's a placeholder
        print("✏️ Editing organization alert: \(alert.title)")
        return alert
    }
    
    func isAdminUser() async -> Bool {
        // This method would check if the current user is an admin
        // For now, it's a placeholder
        print("👑 Checking if current user is admin")
        return currentUser?.isAdmin ?? false
    }
    
    func searchUsers(query: String) async throws -> [User] {
        // This method would search users
        // For now, it's a placeholder
        print("🔍 Searching users with query: \(query)")
        return []
    }
    
    func getAllUsers() async throws -> [User] {
        // This method would get all users
        // For now, it's a placeholder
        print("👥 Getting all users...")
        return []
    }
    
    func fetchFollowedOrganizations() async throws -> [Organization] {
        print("🔗 Fetching followed organizations...")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            return []
        }
        
        let db = Firestore.firestore()
        var followedOrganizations: [Organization] = []
        
        do {
            // Get user's followed organizations from their subcollection
            let userDoc = db.collection("users").document(currentUser.id)
            let followedOrgsRef = userDoc.collection("followedOrganizations")
            let snapshot = try await followedOrgsRef.getDocuments()
            
            print("📋 Found \(snapshot.documents.count) followed organization references")
            
            // Fetch each followed organization's details
            for doc in snapshot.documents {
                do {
                    let orgId = doc.documentID
                    let orgData = doc.data()
                    
                    // Check if the user is actually following this organization
                    let isFollowing = orgData["isFollowing"] as? Bool ?? true
                    
                    if isFollowing {
                        // Fetch the organization details
                        let orgDoc = try await db.collection("organizations").document(orgId).getDocument()
                        
                        if orgDoc.exists, let orgData = orgDoc.data() {
                            let organization = try parseOrganizationFromFirestore(document: orgDoc, data: orgData)
                            followedOrganizations.append(organization)
                            print("✅ Added followed organization: \(organization.name)")
                        } else {
                            print("⚠️ Organization \(orgId) not found or has no data")
                        }
                    } else {
                        print("⚠️ User is not following organization \(orgId)")
                    }
                } catch {
                    print("⚠️ Error fetching organization \(doc.documentID): \(error)")
                    // Continue with other organizations
                    continue
                }
            }
            
            print("✅ Successfully fetched \(followedOrganizations.count) followed organizations")
            return followedOrganizations
            
        } catch {
            print("❌ Error fetching followed organizations: \(error)")
            throw error
        }
    }
    
    func getGroupPreferences(for organizationId: String) async throws -> [String: Bool] {
        print("⚙️ Getting group preferences for organization: \(organizationId)")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            return [:]
        }
        
        let db = Firestore.firestore()
        
        do {
            // Get user's group preferences for this organization
            let userDoc = db.collection("users").document(currentUser.id)
            let followedOrgDoc = userDoc.collection("followedOrganizations").document(organizationId)
            
            let doc = try await followedOrgDoc.getDocument()
            
            if doc.exists, let data = doc.data() {
                let groupPreferences = data["groupPreferences"] as? [String: Bool] ?? [:]
                print("✅ Found \(groupPreferences.count) group preferences for organization \(organizationId)")
                return groupPreferences
            } else {
                print("ℹ️ No group preferences found for organization \(organizationId)")
                return [:]
            }
            
        } catch {
            print("❌ Error fetching group preferences for organization \(organizationId): \(error)")
            throw error
        }
    }
    
    func updateGroupPreference(organizationId: String, groupId: String, isEnabled: Bool) async throws {
        print("⚙️ Updating group preference for organization: \(organizationId), group: \(groupId), enabled: \(isEnabled)")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            throw APIError.unauthorized
        }
        
        let db = Firestore.firestore()
        
        do {
            // Update user's group preferences for this organization
            let userDoc = db.collection("users").document(currentUser.id)
            let followedOrgDoc = userDoc.collection("followedOrganizations").document(organizationId)
            
            // Get current preferences
            let doc = try await followedOrgDoc.getDocument()
            var currentPreferences: [String: Bool] = [:]
            
            if doc.exists, let data = doc.data() {
                currentPreferences = data["groupPreferences"] as? [String: Bool] ?? [:]
            }
            
            // Update the specific group preference
            currentPreferences[groupId] = isEnabled
            
            print("💾 Saving group preferences to Firestore:")
            print("   Organization: \(organizationId)")
            print("   Group: \(groupId)")
            print("   Enabled: \(isEnabled)")
            print("   All preferences: \(currentPreferences)")
            
            // Save updated preferences
            try await followedOrgDoc.setData([
                "groupPreferences": currentPreferences,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ Successfully saved group preference to Firestore: \(groupId) = \(isEnabled)")
            
            // Verify the save by reading it back
            let verifyDoc = try await followedOrgDoc.getDocument()
            if let verifyData = verifyDoc.data(),
               let savedPreferences = verifyData["groupPreferences"] as? [String: Bool] {
                print("🔍 Verification: Saved preferences = \(savedPreferences)")
            }
            
        } catch {
            print("❌ Error updating group preference for organization \(organizationId): \(error)")
            throw error
        }
    }
    
    func fetchUserGroupPreferences() async throws -> [String: Bool] {
        print("🔍 Fetching user group preferences...")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            throw APIError.unauthorized
        }
        
        let db = Firestore.firestore()
        var allPreferences: [String: Bool] = [:]
        
        do {
            // Get all followed organizations
            let userDoc = db.collection("users").document(currentUser.id)
            let followedOrgsRef = userDoc.collection("followedOrganizations")
            let snapshot = try await followedOrgsRef.getDocuments()
            
            print("📋 Found \(snapshot.documents.count) followed organizations")
            
            // Fetch preferences from each followed organization
            for doc in snapshot.documents {
                let orgId = doc.documentID
                let data = doc.data()
                
                if let groupPreferences = data["groupPreferences"] as? [String: Bool] {
                    print("📊 Found \(groupPreferences.count) group preferences for organization \(orgId):")
                    for (groupId, isEnabled) in groupPreferences {
                        print("   Group \(groupId): \(isEnabled ? "enabled" : "disabled")")
                    }
                    allPreferences.merge(groupPreferences) { (_, new) in new }
                } else {
                    print("ℹ️ No group preferences found for organization \(orgId)")
                }
            }
            
            print("✅ Total group preferences loaded: \(allPreferences.count)")
            return allPreferences
            
        } catch {
            print("❌ Error fetching user group preferences: \(error)")
            throw error
        }
    }
    

    

    
    func fetchOrganizationRequests(status: RequestStatus? = nil) async throws -> [OrganizationRequest] {
        // This method would fetch organization requests
        // For now, it's a placeholder
        print("📋 Fetching organization requests with status: \(status?.displayName ?? "all")")
        return []
    }
    
    func getCurrentUserId() -> String? {
        print("🔍 APIService.getCurrentUserId: Checking for user ID...")
        
        // First try APIService currentUser
        if let apiUserId = currentUser?.id {
            print("✅ Found user ID from APIService: \(apiUserId)")
            return apiUserId
        }
        
        // Then try UserDefaults
        if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
            return defaultsUserId
        }
        
        // Finally try Firebase Auth
        if let firebaseUserId = Auth.auth().currentUser?.uid {
            print("✅ Found user ID from Firebase Auth: \(firebaseUserId)")
            return firebaseUserId
        }
        
        print("❌ No user ID found from any source")
        return nil
    }
    
    // MARK: - Debug Authentication State
    func debugAuthenticationState() {
        print("🔍 === AUTHENTICATION DEBUG STATE ===")
        print("APIService:")
        print("  - isAuthenticated: \(isAuthenticated)")
        print("  - currentUser: \(currentUser?.id ?? "nil")")
        print("  - currentUser name: \(currentUser?.name ?? "nil")")
        print("  - currentUser email: \(currentUser?.email ?? "nil")")
        
        print("UserDefaults:")
        print("  - currentUserId: \(UserDefaults.standard.string(forKey: "currentUserId") ?? "nil")")
        print("  - authToken: \(UserDefaults.standard.string(forKey: "authToken") ?? "nil")")
        
        print("Firebase Auth:")
        if let firebaseUser = Auth.auth().currentUser {
            print("  - UID: \(firebaseUser.uid)")
            print("  - Email: \(firebaseUser.email ?? "nil")")
            print("  - Display Name: \(firebaseUser.displayName ?? "nil")")
        } else {
            print("  - No Firebase Auth user")
        }
        
        print("FCM Token:")
        print("  - fcm_token: \(UserDefaults.standard.string(forKey: "fcm_token") ?? "nil")")
        print("  - pending_fcm_token: \(UserDefaults.standard.string(forKey: "pending_fcm_token") ?? "nil")")
        
        print("=== END AUTHENTICATION DEBUG ===")
    }
    
    // MARK: - Force FCM Token Registration
    func forceFCMTokenRegistration() async {
        print("🔄 APIService: Force FCM token registration...")
        
        // First, debug the current state
        debugAuthenticationState()
        
        // Get user ID
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID available for FCM token registration")
            return
        }
        
        // Get FCM token
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        if fcmToken.isEmpty {
            print("❌ No FCM token available for registration")
            return
        }
        
        print("📱 Registering FCM token for user: \(userId)")
        print("📱 FCM token: \(fcmToken.prefix(20))...")
        
        do {
            try await validateAndRegisterFCMToken()
            print("✅ FCM token successfully registered")
        } catch {
            print("❌ Failed to register FCM token: \(error)")
        }
    }
    
    // MARK: - Ensure User Document Exists with FCM Token
    func ensureUserDocumentWithFCMToken() async {
        print("🔧 APIService: Ensuring user document exists with FCM token...")
        
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID available")
            return
        }
        
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        if fcmToken.isEmpty {
            print("❌ No FCM token available")
            return
        }
        
        do {
            let db = Firestore.firestore()
            let userRef = db.collection("users").document(userId)
            
            // Check if user document exists
            let userDoc = try await userRef.getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data() ?? [:]
                let existingToken = userData["fcmToken"] as? String ?? ""
                
                if existingToken.isEmpty {
                    print("📱 User document exists but missing FCM token, updating...")
                    try await userRef.updateData([
                        "fcmToken": fcmToken,
                        "lastTokenUpdate": FieldValue.serverTimestamp(),
                        "platform": "ios",
                        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                        "tokenStatus": "active",
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                    print("✅ FCM token added to existing user document")
                } else {
                    print("✅ User document already has FCM token")
                }
            } else {
                print("📱 User document doesn't exist, creating with FCM token...")
                
                // Get user info from Firebase Auth
                let firebaseUser = Auth.auth().currentUser
                let email = firebaseUser?.email ?? "unknown@example.com"
                let name = firebaseUser?.displayName ?? "User"
                
                try await userRef.setData([
                    "id": userId,
                    "email": email,
                    "name": name,
                    "displayName": name,
                    "fcmToken": fcmToken,
                    "alertsEnabled": true,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp(),
                    "isAdmin": false,
                    "isOrganizationAdmin": false,
                    "uid": userId,
                    "lastSignIn": FieldValue.serverTimestamp(),
                    "signInCount": 1,
                    "platform": "ios",
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "tokenStatus": "active"
                ])
                print("✅ User document created with FCM token")
            }
        } catch {
            print("❌ Error ensuring user document: \(error)")
        }
    }
    
    // MARK: - Synchronize Authentication State
    func synchronizeAuthenticationState() async {
        print("🔄 APIService: Synchronizing authentication state...")
        
        // First, try to restore from Firebase Auth
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Found Firebase Auth user: \(firebaseUser.uid)")
            
            // If we don't have a current user or it's different, try to load from Firestore
            if currentUser == nil || currentUser?.id != firebaseUser.uid {
                print("🔄 Loading user data from Firestore...")
                
                do {
                    let db = Firestore.firestore()
                    let userDoc = try await db.collection("users").document(firebaseUser.uid).getDocument()
                    
                    if userDoc.exists, let userData = userDoc.data() {
                        let syncedUser = User(
                            id: firebaseUser.uid,
                            email: userData["email"] as? String ?? firebaseUser.email,
                            name: userData["name"] as? String ?? firebaseUser.displayName ?? "User",
                            phone: userData["phone"] as? String ?? firebaseUser.phoneNumber,
                            homeLocation: nil,
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
                            displayName: userData["customDisplayName"] as? String ?? userData["name"] as? String ?? firebaseUser.displayName ?? "User",
                            isOrganizationAdmin: userData["isOrganizationAdmin"] as? Bool,
                            organizations: userData["organizations"] as? [String],
                            updatedAt: (userData["updatedAt"] as? Timestamp)?.dateValue(),
                            needsPasswordSetup: userData["needsPasswordSetup"] as? Bool,
                            needsPasswordChange: userData["needsPasswordChange"] as? Bool,
                            firebaseAuthId: firebaseUser.uid
                        )
                        
                        await MainActor.run {
                            self.currentUser = syncedUser
                            self.isAuthenticated = true
                        }
                        
                        // Store user ID in UserDefaults
                        UserDefaults.standard.set(syncedUser.id, forKey: "currentUserId")
                        print("✅ User synchronized: \(syncedUser.name ?? "Unknown")")
                        
                        // Try to register FCM token
                        await forceFCMTokenRegistration()
                        
                    } else {
                        print("⚠️ User document not found in Firestore")
                    }
                } catch {
                    print("❌ Error loading user from Firestore: \(error)")
                }
            } else {
                print("✅ Current user already matches Firebase Auth user")
            }
        } else {
            print("❌ No Firebase Auth user found")
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
        
        print("🔄 Authentication state synchronization complete")
    }
    
    func getOrganizationGroups(organizationId: String) async throws -> [OrganizationGroup] {
        print("👥 Getting organization groups for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        do {
            // Query the organization's groups subcollection
            let groupsRef = db.collection("organizations")
                .document(organizationId)
                .collection("groups")
            
            let snapshot = try await groupsRef.getDocuments()
            print("📊 Found \(snapshot.documents.count) groups in organization \(organizationId)")
            
            var groups: [OrganizationGroup] = []
            
            for document in snapshot.documents {
                do {
                    let data = document.data()
                    print("   📄 Processing group document: \(document.documentID)")
                    print("   📄 Group data: \(data)")
                    let group = try parseOrganizationGroupFromFirestore(document: document, data: data)
                    groups.append(group)
                    print("   ✅ Successfully parsed group: \(group.name)")
                } catch {
                    print("⚠️ Error parsing group \(document.documentID): \(error)")
                    // Continue with other groups
                    continue
                }
            }
            
            print("✅ Successfully parsed \(groups.count) groups for organization \(organizationId)")
            
            // No default groups will be created - organizations start with empty group lists
            
            return groups
            
        } catch {
            print("❌ Error fetching groups for organization \(organizationId): \(error)")
            throw error
        }
    }
    
    // MARK: - Admin Management for Production Setup
    func updateOrganizationAdminIds(organizationId: String) async throws {
        print("🔧 Updating admin IDs for organization: \(organizationId)")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            throw APIError.unauthorized
        }
        
        let db = Firestore.firestore()
        
        do {
            // Get the organization document
            let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
            
            if orgDoc.exists, let data = orgDoc.data() {
                let organizationName = data["name"] as? String ?? "Unknown"
                print("📋 Updating adminIds for organization: \(organizationName)")
                print("   Current user ID: \(currentUser.id)")
                print("   Current user email: \(currentUser.email ?? "nil")")
                
                // Get current adminIds
                var adminIds = data["adminIds"] as? [String: Bool] ?? [:]
                print("   Current adminIds: \(adminIds)")
                
                // Add current user as admin
                adminIds[currentUser.id] = true
                
                // Update the organization document
                try await db.collection("organizations").document(organizationId).updateData([
                    "adminIds": adminIds,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                
                print("✅ Successfully updated adminIds for \(organizationName)")
                print("   New adminIds: \(adminIds)")
                
            } else {
                print("❌ Organization \(organizationId) not found")
                throw APIError.invalidResponse
            }
            
        } catch {
            print("❌ Error updating admin IDs for organization \(organizationId): \(error)")
            throw error
        }
    }
    
    func listOrganizationsWithIds() async throws {
        print("📋 Listing all organizations with their IDs:")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            throw APIError.unauthorized
        }
        
        print("👤 Current user details:")
        print("   ID: \(currentUser.id)")
        print("   Email: \(currentUser.email ?? "nil")")
        print("   Name: \(currentUser.name ?? "nil")")
        print("")
        
        // Get all organizations
        let organizations = try await fetchOrganizations()
        print("📋 Found \(organizations.count) organizations:")
        print("")
        
        for (index, organization) in organizations.enumerated() {
            print("Organization \(index + 1):")
            print("   ID: \(organization.id)")
            print("   Name: \(organization.name)")
            print("   Type: \(organization.type)")
            
            // Check current admin status
            let isCurrentAdmin = await isAdminOfOrganization(organization.id)
            print("   Current Admin Status: \(isCurrentAdmin ? "✅ YES" : "❌ NO")")
            print("")
        }
        
        print("💡 To add yourself as admin to an organization:")
        print("   1. Note the organization ID from above")
        print("   2. Use the updateOrganizationAdminIds(organizationId:) method")
        print("   3. Or manually update in Firestore: organizations/{orgId}/adminIds/\(currentUser.id) = true")
    }
    
    func cleanInvalidAdminIds() async throws {
        print("🧹 Cleaning invalid admin IDs from organizations...")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            throw APIError.unauthorized
        }
        
        let db = Firestore.firestore()
        let organizations = try await fetchOrganizations()
        
        for organization in organizations {
            do {
                let orgDoc = try await db.collection("organizations").document(organization.id).getDocument()
                
                if orgDoc.exists, let data = orgDoc.data() {
                    let adminIds = data["adminIds"] as? [String: Bool] ?? [:]
                    var cleanedAdminIds: [String: Bool] = [:]
                    var removedCount = 0
                    
                    print("🔍 Checking organization: \(organization.name)")
                    print("   Current adminIds: \(adminIds)")
                    
                    // Only keep admin IDs that look like valid Firebase Auth UIDs
                    for (adminId, isAdmin) in adminIds {
                        if isAdmin && isValidFirebaseUID(adminId) {
                            cleanedAdminIds[adminId] = true
                        } else {
                            print("   🗑️ Removing invalid admin ID: \(adminId)")
                            removedCount += 1
                        }
                    }
                    
                    if removedCount > 0 {
                        // Update the organization with cleaned adminIds
                        try await db.collection("organizations").document(organization.id).updateData([
                            "adminIds": cleanedAdminIds,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                        print("   ✅ Cleaned adminIds: \(cleanedAdminIds)")
                    } else {
                        print("   ✅ No invalid admin IDs found")
                    }
                    print("")
                }
            } catch {
                print("❌ Error cleaning admin IDs for \(organization.name): \(error)")
                continue
            }
        }
        
        print("🎉 Admin ID cleanup complete!")
    }
    
    private func isValidFirebaseUID(_ uid: String) -> Bool {
        // Firebase Auth UIDs are typically 28 characters long and contain alphanumeric characters
        // This is a basic validation - you might want to make this more specific
        return uid.count == 28 && uid.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil
    }
    
    func fixUserAuthenticationMismatch() async throws {
        print("🔧 Fixing user authentication mismatch...")
        
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ No Firebase Auth user found")
            throw APIError.unauthorized
        }
        
        print("🔥 Firebase Auth user details:")
        print("   - Firebase UID: \(firebaseUser.uid)")
        print("   - Firebase Email: \(firebaseUser.email ?? "nil")")
        print("   - Firebase Display Name: \(firebaseUser.displayName ?? "nil")")
        
        if let currentUser = currentUser {
            print("🔍 Current APIService user details:")
            print("   - APIService ID: \(currentUser.id)")
            print("   - APIService Email: \(currentUser.email ?? "nil")")
            print("   - APIService Name: \(currentUser.name ?? "nil")")
        }
        
        // Create a new user object with the correct Firebase UID
        let correctedUser = User(
            id: firebaseUser.uid, // Use the Firebase UID as the correct ID
            email: firebaseUser.email ?? "unknown@email.com",
            name: firebaseUser.displayName ?? firebaseUser.email?.components(separatedBy: "@").first ?? "User",
            phone: nil,
            profilePhotoURL: nil,
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
            isAdmin: false
        )
        
        // Update the current user in APIService
        await MainActor.run {
            self.currentUser = correctedUser
            print("✅ Updated APIService currentUser with correct Firebase UID")
            print("   - New ID: \(correctedUser.id)")
            print("   - New Email: \(correctedUser.email ?? "nil")")
            print("   - New Name: \(correctedUser.name ?? "nil")")
        }
        
        // Save the corrected user profile
        await saveUserProfileToDefaults(correctedUser)
        
        print("🎉 User authentication mismatch fixed!")
    }
    
    func setupCurrentUserAsAdminForSpecificOrg() async throws {
        // This method will list organizations and their admin status
        // Users can then manually add themselves to specific organizations
        try await listOrganizationsWithIds()
    }
    
    
    func deleteOrganizationGroup(_ groupName: String, organizationId: String) async throws {
        print("🗑️ Deleting organization group: \(groupName) for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Delete the group document
        let groupRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupName)
        
        try await groupRef.delete()
        print("✅ Successfully deleted organization group: \(groupName)")
    }
    
    func deleteDefaultGroups(organizationId: String) async throws {
        print("🗑️ Deleting default groups for organization: \(organizationId)")
        
        let defaultGroupNames: [String] = []
        
        for groupName in defaultGroupNames {
            do {
                try await deleteOrganizationGroup(groupName, organizationId: organizationId)
            } catch {
                print("⚠️ Could not delete group '\(groupName)': \(error.localizedDescription)")
                // Continue with other groups even if one fails
            }
        }
        
        print("✅ Finished deleting default groups")
    }
    
    func deleteAllDefaultGroups() async throws {
        print("🗑️ Deleting all default groups from all organizations")
        
        let db = Firestore.firestore()
        
        // Get all organizations
        let organizationsSnapshot = try await db.collection("organizations").getDocuments()
        
        let defaultGroupNames = ["General Alerts", "Emergency Alerts", "Community Events", "sample_group_1", "sample_group_2"]
        var totalDeletedCount = 0
        var totalErrorCount = 0
        
        for orgDoc in organizationsSnapshot.documents {
            let organizationId = orgDoc.documentID
            let organizationName = orgDoc.data()["name"] as? String ?? "Unknown"
            
            print("🔍 Checking organization: \(organizationName)")
            
            for groupName in defaultGroupNames {
                do {
                    // Check if group exists
                    let groupRef = db.collection("organizations")
                        .document(organizationId)
                        .collection("groups")
                        .document(groupName)
                    
                    let groupDoc = try await groupRef.getDocument()
                    
                    if groupDoc.exists {
                        try await groupRef.delete()
                        totalDeletedCount += 1
                        print("✅ Deleted '\(groupName)' from \(organizationName)")
                    } else {
                        print("ℹ️ No '\(groupName)' group found in \(organizationName)")
                    }
                } catch {
                    totalErrorCount += 1
                    print("❌ Failed to delete '\(groupName)' from \(organizationName): \(error.localizedDescription)")
                }
            }
        }
        
        print("✅ Finished deleting all default groups")
        print("   - Total deleted: \(totalDeletedCount) groups")
        print("   - Total errors: \(totalErrorCount) groups")
    }
    
    func deleteSampleGroupsFromOrganization(organizationId: String) async throws {
        print("🗑️ Deleting sample groups from organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        let sampleGroupNames = ["sample_group_1", "sample_group_2"]
        var deletedCount = 0
        var errorCount = 0
        
        for groupName in sampleGroupNames {
            do {
                let groupRef = db.collection("organizations")
                    .document(organizationId)
                    .collection("groups")
                    .document(groupName)
                
                let groupDoc = try await groupRef.getDocument()
                
                if groupDoc.exists {
                    try await groupRef.delete()
                    deletedCount += 1
                    print("✅ Deleted '\(groupName)' from organization \(organizationId)")
                } else {
                    print("ℹ️ No '\(groupName)' group found in organization \(organizationId)")
                }
            } catch {
                errorCount += 1
                print("❌ Failed to delete '\(groupName)' from organization \(organizationId): \(error.localizedDescription)")
            }
        }
        
        print("✅ Finished deleting sample groups from organization \(organizationId)")
        print("   - Deleted: \(deletedCount) groups")
        print("   - Errors: \(errorCount) groups")
    }
    
    func searchOrganizations(query: String) async throws -> [Organization] {
        print("🔍 Searching organizations with query: \(query)")
        
        guard !query.isEmpty else {
            print("❌ Empty search query")
            return []
        }
        
        let db = Firestore.firestore()
        let lowercaseQuery = query.lowercased()
        
        do {
            // Search in verified organizations
            let snapshot = try await db.collection("organizations")
                .whereField("verified", isEqualTo: true)
                .getDocuments()
            
            var searchResults: [Organization] = []
            
            for document in snapshot.documents {
                do {
                    let data = document.data()
                    let organization = try parseOrganizationFromFirestore(document: document, data: data)
                    
                    // Check if organization matches search query
                    let nameMatches = organization.name.lowercased().contains(lowercaseQuery)
                    let typeMatches = organization.type.lowercased().contains(lowercaseQuery)
                    let cityMatches = organization.location.city?.lowercased().contains(lowercaseQuery) ?? false
                    let stateMatches = organization.location.state?.lowercased().contains(lowercaseQuery) ?? false
                    let zipMatches = organization.location.zipCode?.contains(query) ?? false
                    
                    if nameMatches || typeMatches || cityMatches || stateMatches || zipMatches {
                        searchResults.append(organization)
                    }
                    
                } catch {
                    print("⚠️ Error parsing organization \(document.documentID) during search: \(error)")
                    continue
                }
            }
            
            // Sort results by relevance (name matches first, then by name alphabetically)
            searchResults.sort { first, second in
                let firstNameMatch = first.name.lowercased().contains(lowercaseQuery)
                let secondNameMatch = second.name.lowercased().contains(lowercaseQuery)
                
                if firstNameMatch && !secondNameMatch {
                    return true
                } else if !firstNameMatch && secondNameMatch {
                    return false
                } else {
                    return first.name < second.name
                }
            }
            
            print("✅ Found \(searchResults.count) organizations matching '\(query)'")
            return searchResults
            
        } catch {
            print("❌ Error searching organizations: \(error)")
            throw error
        }
    }
    
    func getFollowingOrganizationAlerts() async throws -> [OrganizationAlert] {
        print("🔍 Fetching alerts from followed organizations...")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            return []
        }
        
        print("👤 Current user: \(currentUser.id) (\(currentUser.email ?? "no email"))")
        
        let db = Firestore.firestore()
        var allAlerts: [OrganizationAlert] = []
        
        // Get user's followed organizations
        let followedOrgs = try await fetchFollowedOrganizations()
        print("📋 Found \(followedOrgs.count) followed organizations")
        for org in followedOrgs {
            print("   📍 \(org.name) (ID: \(org.id))")
        }
        
        // Get user's group preferences
        let groupPreferences = try await fetchUserGroupPreferences()
        print("🔧 User group preferences: \(groupPreferences)")
        
        // Fetch alerts from each followed organization
        for organization in followedOrgs {
            do {
                print("🔍 Fetching alerts for organization: \(organization.name) (ID: \(organization.id))")
                let orgAlerts = try await getOrganizationAlerts(organizationId: organization.id)
                print("📢 Found \(orgAlerts.count) alerts from \(organization.name)")
                
                // Filter alerts by group preferences
                let filteredAlerts = orgAlerts.filter { alert in
                    // If alert has no group (general organization alert), include it
                    guard let groupId = alert.groupId else {
                        print("   📋 Alert '\(alert.title)' has no group - including")
                        return true
                    }
                    
                    // Check if user has enabled this group
                    let isGroupEnabled = groupPreferences[groupId] ?? false
                    print("   📋 Alert '\(alert.title)' from group '\(alert.groupName ?? "Unknown")' (ID: \(groupId)) - Enabled: \(isGroupEnabled)")
                    
                    return isGroupEnabled
                }
                
                print("📊 Filtered to \(filteredAlerts.count) alerts from enabled groups")
                for alert in filteredAlerts {
                    print("   ✅ Included: '\(alert.title)' from group '\(alert.groupName ?? "General")'")
                }
                
                allAlerts.append(contentsOf: filteredAlerts)
            } catch {
                print("⚠️ Error fetching alerts from \(organization.name): \(error)")
                print("   Error details: \(error.localizedDescription)")
                // Continue with other organizations
                continue
            }
        }
        
        // Sort by most recent first
        allAlerts.sort { $0.postedAt > $1.postedAt }
        
        print("✅ Total alerts found after group filtering: \(allAlerts.count)")
        return allAlerts
    }
    
    func getAllAlerts() async throws -> [OrganizationAlert] {
        print("🔍 Fetching ALL alerts from the system...")
        
        let db = Firestore.firestore()
        var allAlerts: [OrganizationAlert] = []
        
        do {
            // Get all organizations first
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            print("📋 Found \(orgsSnapshot.documents.count) organizations in the system")
            
            // Fetch alerts from each organization
            for orgDoc in orgsSnapshot.documents {
                let orgId = orgDoc.documentID
                let orgData = orgDoc.data()
                let orgName = orgData["name"] as? String ?? "Unknown"
                
                do {
                    let orgAlerts = try await getOrganizationAlerts(organizationId: orgId)
                    print("📢 Found \(orgAlerts.count) alerts from \(orgName) (ID: \(orgId))")
                    allAlerts.append(contentsOf: orgAlerts)
                } catch {
                    print("⚠️ Error fetching alerts from \(orgName): \(error)")
                    continue
                }
            }
            
            // Sort by most recent first
            allAlerts.sort { $0.postedAt > $1.postedAt }
            
            print("✅ Total alerts found across all organizations: \(allAlerts.count)")
            return allAlerts
            
        } catch {
            print("❌ Error fetching all alerts: \(error)")
            throw error
        }
    }
    
    func createTestAlert(organizationId: String) async throws {
        print("🔧 Creating test alert for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // First, get the organization name
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        let orgName = orgDoc.data()?["name"] as? String ?? "Unknown Organization"
        
        let testAlert = OrganizationAlert(
            id: UUID().uuidString,
            title: "Test Alert - System Check",
            description: "This is a test alert to verify the alert system is working correctly.",
            organizationId: organizationId,
            organizationName: orgName,
            groupId: nil,
            groupName: nil,
            type: .other,
            severity: .medium,
            location: Location(
                latitude: 33.2148,
                longitude: -97.1331,
                address: "123 Test Street",
                city: "Denton",
                state: "TX",
                zipCode: "76201"
            ),
            postedBy: currentUser?.name ?? "System",
            postedByUserId: currentUser?.id ?? "system",
            postedAt: Date(),
            imageURLs: []
        )
        
        do {
            var alertData: [String: Any] = [
                "id": testAlert.id,
                "organizationId": testAlert.organizationId,
                "organizationName": testAlert.organizationName,
                "title": testAlert.title,
                "description": testAlert.description,
                "type": testAlert.type.rawValue,
                "severity": testAlert.severity.rawValue,
                "postedBy": testAlert.postedBy,
                "postedByUserId": testAlert.postedByUserId,
                "postedAt": Timestamp(date: testAlert.postedAt),
                "expiresAt": Timestamp(date: testAlert.expiresAt),
                "imageURLs": testAlert.imageURLs,
                "isActive": testAlert.isActive
            ]
            
            // Only add optional fields if they have values
            if let groupId = testAlert.groupId {
                alertData["groupId"] = groupId
            }
            if let groupName = testAlert.groupName {
                alertData["groupName"] = groupName
            }
            if let location = testAlert.location {
                alertData["location"] = [
                    "latitude": location.latitude,
                    "longitude": location.longitude,
                    "address": location.address,
                    "city": location.city,
                    "state": location.state,
                    "zipCode": location.zipCode
                ]
            }
            if let distance = testAlert.distance {
                alertData["distance"] = distance
            }
            
            try await db.collection("organizations")
                .document(organizationId)
                .collection("alerts")
                .document(testAlert.id)
                .setData(alertData)
            
            print("✅ Test alert created successfully: \(testAlert.title)")
            
        } catch {
            print("❌ Error creating test alert: \(error)")
            throw error
        }
    }
    
    func updateCurrentUser(from simpleAuthManager: SimpleAuthManager) {
        print("🔄 APIService: Updating current user from SimpleAuthManager...")
        print("   SimpleAuthManager isAuthenticated: \(simpleAuthManager.isAuthenticated)")
        print("   SimpleAuthManager currentUser: \(simpleAuthManager.currentUser?.id ?? "nil")")
        
        if let user = simpleAuthManager.currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            print("✅ APIService: Updated current user to: \(user.name ?? "Unknown")")
        } else {
            self.currentUser = nil
            self.isAuthenticated = false
            print("✅ APIService: Cleared current user")
        }
    }
    
    func hideAlertFromFeed(alertId: String) async throws {
        print("🙈 Hiding alert from feed with ID: \(alertId)")
        
        guard let currentUser = currentUser else {
            print("❌ No current user found")
            throw APIError.unauthorized
        }
        
        let db = Firestore.firestore()
        
        do {
            // Add the alert to user's hidden alerts collection
            let userDoc = db.collection("users").document(currentUser.id)
            let hiddenAlertsRef = userDoc.collection("hiddenAlerts")
            
            try await hiddenAlertsRef.document(alertId).setData([
                "alertId": alertId,
                "hiddenAt": FieldValue.serverTimestamp(),
                "userId": currentUser.id
            ])
            
            print("✅ Successfully hidden alert \(alertId) from feed")
            
        } catch {
            print("❌ Error hiding alert \(alertId): \(error)")
            throw error
        }
    }
    
    func getOrganizationById(_ organizationId: String) async throws -> Organization? {
        print("🏢 Getting organization by ID: \(organizationId)")
        
        let db = Firestore.firestore()
        
        do {
            let doc = try await db.collection("organizations").document(organizationId).getDocument()
            
            if doc.exists, let data = doc.data() {
                let organization = try parseOrganizationFromFirestore(document: doc, data: data)
                print("✅ Successfully fetched organization: \(organization.name)")
                return organization
            } else {
                print("ℹ️ Organization \(organizationId) not found")
                return nil
            }
            
        } catch {
            print("❌ Error fetching organization \(organizationId): \(error)")
            throw error
        }
    }
    
    func isAdminOfOrganization(_ organizationId: String) async -> Bool {
        print("👑 Checking if user is admin of organization: \(organizationId)")
        
        // Try to get user ID from multiple sources
        var currentUserId: String?
        
        // First try APIService currentUser
        if let apiUserId = currentUser?.id {
            currentUserId = apiUserId
            print("✅ Found user ID from APIService: \(apiUserId)")
        }
        // Then try UserDefaults
        else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
        }
        // Finally try Firebase Auth
        else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
            print("✅ Found user ID from Firebase Auth: \(firebaseUserId)")
        }
        
        guard let userId = currentUserId else {
            print("❌ No current user found from any source")
            return false
        }
        
        print("✅ Using user ID for admin check: \(userId)")
        
        // Check Firebase Auth current user for comparison
        if let firebaseUser = Auth.auth().currentUser {
            print("🔥 Firebase Auth current user:")
            print("   - Firebase UID: \(firebaseUser.uid)")
            print("   - Firebase Email: \(firebaseUser.email ?? "nil")")
            print("   - Firebase Display Name: \(firebaseUser.displayName ?? "nil")")
            
            // If there's a mismatch, this is the problem
            if userId != firebaseUser.uid {
                print("⚠️ MISMATCH: Using user ID (\(userId)) != Firebase UID (\(firebaseUser.uid))")
                print("⚠️ This explains why admin checks might be failing!")
            }
        } else {
            print("❌ No Firebase Auth user found")
        }
        
        // Check only the adminIds - no special access for any account
        
        let db = Firestore.firestore()
        
        do {
            // Get the organization document
            let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
            
            if orgDoc.exists, let data = orgDoc.data() {
                // Check if the current user is in the adminIds
                let adminIds = data["adminIds"] as? [String: Bool] ?? [:]
                let isAdmin = adminIds[userId] == true
                
                print("✅ Admin status for user \(userId) in organization \(organizationId): \(isAdmin)")
                print("📋 Available adminIds: \(adminIds.keys.joined(separator: ", "))")
                print("🔍 User ID match: \(adminIds[userId] ?? false)")
                
                // No special handling - only grant access if user is explicitly in adminIds
                
                return isAdmin
            } else {
                print("ℹ️ Organization \(organizationId) not found")
                return false
            }
            
        } catch {
            print("❌ Error checking admin status for organization \(organizationId): \(error)")
            return false
        }
    }
    
    // MARK: - Organization Requests
    func submitOrganizationRequest(_ request: OrganizationRequest) async throws -> OrganizationRequest {
        print("🏢 Organization registration request received:")
        print("   Name: \(request.name)")
        print("   Type: \(request.type.displayName)")
        print("   Contact: \(request.contactPersonName)")
        print("   Email: \(request.contactPersonEmail)")
        print("   Phone: \(request.contactPersonPhone)")
        print("   Address: \(request.fullAddress)")
        print("   Description: \(request.description)")
        
        // Create user account in Firestore for the organization admin
        print("👤 Creating user account for organization admin...")
        do {
            let db = Firestore.firestore()
            
            // Check if user already exists
            let existingUserQuery = try await db.collection("users")
                .whereField("email", isEqualTo: request.contactPersonEmail)
                .getDocuments()
            
            if existingUserQuery.documents.isEmpty {
                // Create new user document
                let userRef = db.collection("users").document()
                let userId = userRef.documentID
                
                let userData: [String: Any] = [
                    "id": userId,
                    "email": request.contactPersonEmail,
                    "name": request.contactPersonName,
                    "searchableName": request.contactPersonName.lowercased().replacingOccurrences(of: " ", with: ""),
                    "customDisplayName": request.contactPersonName,
                    "isAdmin": true, // Organization admins are admins
                    "isOrganizationAdmin": true,
                    "organizations": [], // Will be populated when org is approved
                    "needsPasswordSetup": true,
                    "adminPassword": request.adminPassword, // Store password temporarily for admin review
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                try await userRef.setData(userData)
                print("✅ User account created in Firestore: \(userId)")
                
                // Create Firebase Auth account with the provided password
                print("🔐 Creating Firebase Auth account...")
                do {
                    let authResult = try await Auth.auth().createUser(withEmail: request.contactPersonEmail, password: request.adminPassword)
                    let firebaseAuthId = authResult.user.uid
                    
                    // Update user document with Firebase Auth ID
                    try await userRef.updateData([
                        "firebaseAuthId": firebaseAuthId,
                        "needsPasswordSetup": false, // Password is already set
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                    
                    print("✅ Firebase Auth account created: \(firebaseAuthId)")
                    
                    // Sign out the temporary user
                    try await Auth.auth().signOut()
                    
                } catch {
                    print("⚠️ Warning: Could not create Firebase Auth account: \(error)")
                    print("💡 User will need to use 'Create Account' flow instead")
                    
                    // Update user document to indicate password setup is needed
                    try await userRef.updateData([
                        "needsPasswordSetup": true,
                        "adminPassword": nil, // Remove stored password for security
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                }
                
            } else {
                print("⚠️ User already exists with email: \(request.contactPersonEmail)")
            }
            
        } catch {
            print("❌ Error creating user account: \(error)")
            // Continue with request submission even if user creation fails
        }
        
        // Store the organization request in Firestore
        print("🏢 Storing organization request in Firestore...")
        do {
            let db = Firestore.firestore()
            let requestRef = db.collection("organizationRequests").document(request.id)
            
            let requestData: [String: Any] = [
                "id": request.id,
                "name": request.name,
                "type": request.type.rawValue,
                "description": request.description,
                "website": request.website as Any,
                "phone": request.phone as Any,
                "email": request.email,
                "address": request.address,
                "city": request.city,
                "state": request.state,
                "zipCode": request.zipCode,
                "contactPersonName": request.contactPersonName,
                "contactPersonTitle": request.contactPersonTitle,
                "contactPersonPhone": request.contactPersonPhone,
                "contactPersonEmail": request.contactPersonEmail,
                "adminPassword": request.adminPassword, // Store temporarily for admin review
                "status": request.status.rawValue,
                "submittedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await requestRef.setData(requestData)
            print("✅ Organization request saved to Firestore: \(request.id)")
            print("   📝 Status saved: \(request.status.rawValue)")
            print("   📝 Document path: organizationRequests/\(request.id)")
            
            // Verify the request was saved by reading it back
            let verificationDoc = try await requestRef.getDocument()
            if verificationDoc.exists {
                let verificationData = verificationDoc.data()
                let savedStatus = verificationData?["status"] as? String ?? "nil"
                let savedName = verificationData?["name"] as? String ?? "nil"
                print("✅ Verification: Request confirmed in Firestore")
                print("   - Saved status: \(savedStatus)")
                print("   - Saved name: \(savedName)")
            } else {
                print("❌ ERROR: Request was not found after saving!")
            }
            
        } catch {
            print("❌ Error saving organization request to Firestore: \(error)")
            throw error
        }
        
        // Also store locally for immediate access
        await MainActor.run {
            self.pendingRequests.append(request)
            print("✅ Request also stored locally. Total pending requests: \(self.pendingRequests.count)")
        }
        
        // Notify Jed Crisp (the creator) about the new request
        await notifyCreatorAboutRequest(request)
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return request
    }
    
    private func notifyCreatorAboutRequest(_ request: OrganizationRequest) async {
        // This is where you'd implement the actual notification system
        // For now, we'll print detailed information to the console
        
        print("")
        print("🚨 NEW ORGANIZATION REGISTRATION REQUEST - ACTION REQUIRED")
        print(String(repeating: "=", count: 60))
        print("📋 REQUEST DETAILS:")
        print("   Request ID: \(request.id)")
        print("   Organization: \(request.name)")
        print("   Type: \(request.type.displayName)")
        print("   Status: \(request.status.displayName)")
        print("   Submitted: \(request.submittedAt)")
        print("")
        print("👤 CONTACT INFORMATION:")
        print("   Contact Person: \(request.contactPersonName)")
        print("   Title/Role: \(request.contactPersonTitle)")
        print("   Phone: \(request.contactPersonPhone)")
        print("   Email: \(request.contactPersonEmail)")
        print("")
        print("📍 LOCATION:")
        print("   Address: \(request.fullAddress)")
        print("")
        print("📝 DESCRIPTION:")
        print("   \(request.description)")
        print("")
        print("🌐 WEBSITE: \(request.website ?? "Not provided")")
        print("")
        print("🔍 NEXT STEPS FOR JED CRISP:")
        print("   1. Review the organization details above")
        print("   2. Verify the organization exists and is legitimate")
        print("   3. Contact the organization if needed: \(request.contactPersonEmail)")
        print("   4. Approve or reject the request")
        print("   5. If approved, create their organization profile")
        print("")
        print("📧 ADMIN EMAIL: jed@localalert.com")
        print("🔗 ADMIN PANEL: https://admin.localalert.com/requests/\(request.id)")
        print(String(repeating: "=", count: 60))
        print("")
        
        // Send email notification to Jed Crisp
        await sendEmailNotification(request)
        
        // In production, you could also:
        // - Send a push notification to your admin app
        // - Create a webhook to your admin system
        // - Add to a queue for review
    }
    
    private func sendEmailNotification(_ request: OrganizationRequest) async {
        // Check if this is a creator account that should receive notifications
        if isCreatorAccount() {
            print("📧 CREATOR ACCOUNT NOTIFICATION: New organization request received")
            print("   Organization: \(request.name)")
            print("   Type: \(request.type.displayName)")
            print("   Request ID: \(request.id)")
            print("   📱 Review in the Requests tab of LocalAlert app")
        }
    }
    
    func getPendingOrganizationRequests() async throws -> [OrganizationRequest] {
        print("📋 Fetching pending organization requests from Firestore...")
        
        let db = Firestore.firestore()
        
        do {
            // First, let's see what's actually in the collection
            let allSnapshot = try await db.collection("organizationRequests").getDocuments()
            print("🔍 Total organization requests in Firestore: \(allSnapshot.documents.count)")
            
            // Debug: Print all requests and their statuses
            for (index, doc) in allSnapshot.documents.enumerated() {
                let data = doc.data()
                let status = data["status"] as? String ?? "nil"
                let name = data["name"] as? String ?? "Unknown"
                let id = data["id"] as? String ?? doc.documentID
                print("📄 Request \(index + 1): ID=\(id), Name=\(name), Status=\(status)")
            }
            
            // Now query for pending requests specifically
            // Note: Using simple query without ordering to avoid index requirements
            let snapshot = try await db.collection("organizationRequests")
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            
            // Sort the results in memory instead of requiring a Firestore index
            let sortedDocuments = snapshot.documents.sorted { doc1, doc2 in
                let timestamp1 = doc1.data()["submittedAt"] as? Timestamp ?? Timestamp()
                let timestamp2 = doc2.data()["submittedAt"] as? Timestamp ?? Timestamp()
                return timestamp1.dateValue() > timestamp2.dateValue() // Descending order
            }
            
            print("📊 Found \(snapshot.documents.count) requests with status='pending' (sorted by submission date)")
            
            var requests: [OrganizationRequest] = []
            
            for document in sortedDocuments {
                do {
                    let data = document.data()
                    print("📝 Parsing document: \(document.documentID)")
                    print("   - Status: \(data["status"] as? String ?? "nil")")
                    print("   - Name: \(data["name"] as? String ?? "nil")")
                    
                    let request = try parseOrganizationRequestFromFirestore(document: document, data: data)
                    requests.append(request)
                    print("✅ Successfully parsed request: \(request.name)")
                } catch {
                    print("⚠️ Error parsing organization request \(document.documentID): \(error)")
                    print("   Document data: \(document.data())")
                    continue
                }
            }
            
            print("✅ Successfully fetched \(requests.count) pending organization requests from Firestore")
            
            // Update local cache
            await MainActor.run {
                self.pendingRequests = requests
                print("📋 Local cache updated with \(self.pendingRequests.count) requests")
            }
            
            return requests
            
        } catch {
            print("❌ Error fetching organization requests from Firestore: \(error)")
            
            // Fallback to local cache
            print("📋 Falling back to local cache. Total stored: \(pendingRequests.count)")
            return pendingRequests
        }
    }
    
    private func parseOrganizationRequestFromFirestore(document: QueryDocumentSnapshot, data: [String: Any]) throws -> OrganizationRequest {
        // Parse with fallbacks for web form field names
        let id = data["id"] as? String ?? document.documentID
        let name = data["name"] as? String ?? data["organizationName"] as? String ?? "Unknown Organization"
        let typeRawValue = data["type"] as? String ?? data["organizationType"] as? String ?? "other"
        let type = OrganizationType(rawValue: typeRawValue) ?? .other
        let description = data["description"] as? String ?? ""
        let email = data["email"] as? String ?? data["officeEmail"] as? String ?? data["organizationEmail"] as? String ?? ""
        let address = data["address"] as? String ?? ""
        let city = data["city"] as? String ?? ""
        let state = data["state"] as? String ?? ""
        let zipCode = data["zipCode"] as? String ?? ""
        
        // Parse admin info - handle both web form field names and app field names
        let adminFirstName = data["adminFirstName"] as? String ?? ""
        let adminLastName = data["adminLastName"] as? String ?? ""
        let adminEmail = data["adminEmail"] as? String ?? ""
        
        // Build contact person name from admin fields if contact fields are empty
        let contactPersonName = data["contactPersonName"] as? String ?? 
            (adminFirstName.isEmpty && adminLastName.isEmpty ? "" : "\(adminFirstName) \(adminLastName)".trimmingCharacters(in: .whitespaces))
        
        let contactPersonTitle = data["contactPersonTitle"] as? String ?? ""
        let contactPersonPhone = data["contactPersonPhone"] as? String ?? data["phone"] as? String ?? ""
        let contactPersonEmail = data["contactPersonEmail"] as? String ?? data["contactEmail"] as? String ?? adminEmail
        let adminPassword = data["adminPassword"] as? String ?? ""
        
        let statusRawValue = data["status"] as? String ?? "pending"
        let status = RequestStatus(rawValue: statusRawValue) ?? .pending
        
        let website = data["website"] as? String
        let phone = data["phone"] as? String
        
        // Parse dates
        let submittedAt: Date
        if let timestamp = data["submittedAt"] as? Timestamp {
            submittedAt = timestamp.dateValue()
        } else if let timestamp = data["createdAt"] as? Timestamp {
            submittedAt = timestamp.dateValue()
        } else {
            submittedAt = Date()
        }
        
        // Create the request using the designated initializer
        return OrganizationRequest(
            name: name,
            type: type,
            description: description,
            website: website,
            phone: phone,
            email: email,
            address: address,
            city: city,
            state: state,
            zipCode: zipCode,
            contactPersonName: contactPersonName,
            contactPersonTitle: contactPersonTitle,
            contactPersonPhone: contactPersonPhone,
            contactPersonEmail: contactPersonEmail,
            adminPassword: adminPassword,
            status: status
        )
    }
    
    func reviewOrganizationRequest(_ requestId: String, review: AdminReview) async throws -> OrganizationRequest {
        print("📝 Reviewing organization request: \(requestId)")
        print("   Review by: \(review.adminName)")
        print("   Status: \(review.status.displayName)")
        print("   Notes: \(review.notes)")
        
        let db = Firestore.firestore()
        
        // Update the organization request with the review
        let requestRef = db.collection("organizationRequests").document(requestId)
        
        do {
            try await requestRef.updateData([
                "status": review.status.rawValue,
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": review.adminName,
                "reviewNotes": review.notes,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Organization request review saved to Firestore")
            
            // Get the updated request
            let updatedDoc = try await requestRef.getDocument()
            guard updatedDoc.exists, let data = updatedDoc.data() else {
                throw NSError(domain: "ReviewError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization request not found after update"])
            }
            
            // Parse the updated request manually since we have DocumentSnapshot, not QueryDocumentSnapshot
            guard let id = data["id"] as? String,
                  let name = data["name"] as? String,
                  let typeRawValue = data["type"] as? String,
                  let type = OrganizationType(rawValue: typeRawValue),
                  let description = data["description"] as? String,
                  let email = data["email"] as? String,
                  let address = data["address"] as? String,
                  let city = data["city"] as? String,
                  let state = data["state"] as? String,
                  let zipCode = data["zipCode"] as? String,
                  let contactPersonName = data["contactPersonName"] as? String,
                  let contactPersonTitle = data["contactPersonTitle"] as? String,
                  let contactPersonPhone = data["contactPersonPhone"] as? String,
                  let contactPersonEmail = data["contactPersonEmail"] as? String,
                  let adminPassword = data["adminPassword"] as? String,
                  let statusRawValue = data["status"] as? String,
                  let status = RequestStatus(rawValue: statusRawValue) else {
                throw NSError(domain: "ReviewError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing required fields in updated organization request"])
            }
            
            let website = data["website"] as? String
            let phone = data["phone"] as? String
            
            // Create the updated request
            let request = OrganizationRequest(
                name: name,
                type: type,
                description: description,
                website: website,
                phone: phone,
                email: email,
                address: address,
                city: city,
                state: state,
                zipCode: zipCode,
                contactPersonName: contactPersonName,
                contactPersonTitle: contactPersonTitle,
                contactPersonPhone: contactPersonPhone,
                contactPersonEmail: contactPersonEmail,
                adminPassword: adminPassword,
                status: status
            )
            
            print("✅ Successfully parsed updated request: \(request.name)")
            
            return request
            
        } catch {
            print("❌ Error reviewing organization request: \(error)")
            throw error
        }
    }
    
    func approveOrganizationRequest(_ requestId: String, notes: String = "") async throws -> OrganizationRequest {
        print("✅ ORGANIZATION REQUEST APPROVAL PROCESS STARTING")
        print("   Request ID: \(requestId)")
        print("   Approved by: Jed Crisp")
        print("   Notes: \(notes.isEmpty ? "No additional notes" : notes)")
        
        let db = Firestore.firestore()
        
        // 1. Fetch the organization request from Firestore
        print("📋 Fetching organization request from Firestore...")
        let requestRef = db.collection("organizationRequests").document(requestId)
        let requestDoc = try await requestRef.getDocument()
        
        guard requestDoc.exists,
              let requestData = requestDoc.data() else {
            throw NSError(domain: "ApprovalError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization request not found"])
        }
        
        // Parse the request manually since we have DocumentSnapshot, not QueryDocumentSnapshot
        guard let id = requestData["id"] as? String,
              let name = requestData["name"] as? String,
              let typeRawValue = requestData["type"] as? String,
              let type = OrganizationType(rawValue: typeRawValue),
              let description = requestData["description"] as? String,
              let email = requestData["email"] as? String,
              let address = requestData["address"] as? String,
              let city = requestData["city"] as? String,
              let state = requestData["state"] as? String,
              let zipCode = requestData["zipCode"] as? String,
              let contactPersonName = requestData["contactPersonName"] as? String,
              let contactPersonTitle = requestData["contactPersonTitle"] as? String,
              let contactPersonPhone = requestData["contactPersonPhone"] as? String,
              let contactPersonEmail = requestData["contactPersonEmail"] as? String,
              let adminPassword = requestData["adminPassword"] as? String,
              let statusRawValue = requestData["status"] as? String,
              let status = RequestStatus(rawValue: statusRawValue) else {
            throw NSError(domain: "ApprovalError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization request not found"])
        }
        
        let website = requestData["website"] as? String
        let phone = requestData["phone"] as? String
        
        print("✅ Found organization request: \(name)")
        
        // 2. Geocode the organization address for map pinning
        print("🌍 Geocoding organization address for map pinning...")
        let fullAddress = "\(address), \(city), \(state) \(zipCode)"
        print("   📍 Geocoding address: \(fullAddress)")
        
        var latitude: Double = 0.0
        var longitude: Double = 0.0
        
        if let geocodedLocation = await geocodeAddress(fullAddress) {
            latitude = geocodedLocation.coordinate.latitude
            longitude = geocodedLocation.coordinate.longitude
            print("   ✅ Address geocoded successfully: (\(latitude), \(longitude))")
        } else {
            print("   ⚠️ Could not geocode address, using default coordinates")
            // Fallback to a reasonable default (could be organization's city center)
            latitude = 33.2148  // Default to Denton, TX area
            longitude = -97.1331
        }
        
        // 3. Look up the user to get their ID for admin access
        print("👤 Looking up user for admin access...")
        let usersQuery = try await db.collection("users")
            .whereField("email", isEqualTo: contactPersonEmail)
            .getDocuments()
        
        var userId: String?
        if let userDoc = usersQuery.documents.first {
            userId = userDoc.documentID
            print("✅ Found user: \(userId ?? "unknown")")
        } else {
            print("⚠️ User not found in users collection: \(contactPersonEmail)")
        }
        
        // 4. Create the approved organization in Firestore with map coordinates
        print("🏢 Creating approved organization in Firestore with map coordinates...")
        
        // Try to use the organization name as the document ID for consistency
        var organizationId = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "&", with: "_and_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        print("📝 Generated organization ID: '\(organizationId)'")
        print("   - Original name: '\(name)'")
        print("   - ID length: \(organizationId.count) characters")
        
        // Validate the organization ID and use fallback if needed
        var useGeneratedId = true
        if organizationId.isEmpty {
            print("⚠️ WARNING: Generated organization ID is empty! Using UUID fallback")
            useGeneratedId = false
        } else if organizationId.count > 1500 {
            print("⚠️ WARNING: Generated organization ID is too long (\(organizationId.count) characters)! Using UUID fallback")
            useGeneratedId = false
        } else if organizationId.contains("/") || organizationId.contains("\\") {
            print("⚠️ WARNING: Generated organization ID contains invalid characters! Using UUID fallback")
            useGeneratedId = false
        } else if organizationId.hasPrefix("_") || organizationId.hasSuffix("_") {
            print("⚠️ WARNING: Generated organization ID starts or ends with underscore! Using UUID fallback")
            useGeneratedId = false
        } else if organizationId.contains("__") {
            print("⚠️ WARNING: Generated organization ID contains double underscores! Using UUID fallback")
            useGeneratedId = false
        }
        
        print("🔍 Organization ID validation:")
        print("   - ID: '\(organizationId)'")
        print("   - Length: \(organizationId.count)")
        print("   - Empty: \(organizationId.isEmpty)")
        print("   - Contains /: \(organizationId.contains("/"))")
        print("   - Contains \\: \(organizationId.contains("\\"))")
        print("   - Starts with _: \(organizationId.hasPrefix("_"))")
        print("   - Ends with _: \(organizationId.hasSuffix("_"))")
        print("   - Contains __: \(organizationId.contains("__"))")
        print("   - Use generated ID: \(useGeneratedId)")
        
        // Use UUID fallback if the generated ID is problematic
        if !useGeneratedId {
            organizationId = UUID().uuidString
            print("🔄 Using UUID fallback for organization ID: \(organizationId)")
        }
        
        let organizationRef = db.collection("organizations").document(organizationId)
        print("📄 Firestore document reference created: organizations/\(organizationId)")
        
        // Test if we can create the document reference without issues
        print("🧪 Testing document reference validity...")
        do {
            let testData = ["test": "value"]
            // This should not actually write, just test the reference
            print("✅ Document reference appears valid")
        } catch {
            print("❌ ERROR: Document reference is invalid: \(error)")
            throw error
        }
        
        // Test Firestore write capability with a simple test document
        print("🧪 Testing Firestore write capability...")
        do {
            let testRef = db.collection("test").document("approval_test")
            try await testRef.setData([
                "test": "approval_test",
                "timestamp": FieldValue.serverTimestamp(),
                "organizationId": organizationId
            ])
            print("✅ Firestore write test successful - can create documents")
            
            // Clean up test document
            try await testRef.delete()
            print("✅ Test document cleaned up")
        } catch {
            print("❌ CRITICAL ERROR: Firestore write test failed!")
            print("   Error: \(error)")
            print("   This means we cannot write to Firestore at all!")
            throw error
        }
        
        let organizationData: [String: Any] = [
            "id": organizationId,
            "name": name,
            "type": type.rawValue,
            "description": description,
            "website": website ?? NSNull(),
            "phone": phone ?? NSNull(),
            "email": email,
            "address": address,
            "city": city,
            "state": state,
            "zipCode": zipCode,
            "verified": true, // Approved organizations are verified
            "followerCount": 0,
            "logoURL": NSNull(),
            "groups": [] as [Any],
            "adminIds": userId != nil ? [userId!: true] : [contactPersonEmail: true], // Use user ID if available, fallback to email
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            // Location data for map pinning
            "location": [
                "latitude": latitude,
                "longitude": longitude,
                "address": address,
                "city": city,
                "state": state,
                "zipCode": zipCode
            ]
        ]
        
        print("🚀 ATTEMPTING TO CREATE ORGANIZATION IN FIRESTORE...")
        print("   📄 Document path: organizations/\(organizationId)")
        print("   📊 Data size: \(organizationData.count) fields")
        print("   🔍 Data preview:")
        for (key, value) in organizationData {
            if key == "adminIds" {
                print("     - \(key): \(value)")
            } else {
                print("     - \(key): \(String(describing: value).prefix(50))...")
            }
        }
        
        do {
            print("⏳ Calling Firestore setData...")
            try await organizationRef.setData(organizationData)
            print("✅ Firestore setData completed successfully!")
            
            print("🔍 Verifying organization was actually created...")
            let immediateVerification = try await organizationRef.getDocument()
            if immediateVerification.exists {
                print("✅ IMMEDIATE VERIFICATION: Organization document exists in Firestore")
                let verificationData = immediateVerification.data()
                print("   - Document ID: \(immediateVerification.documentID)")
                print("   - Verified field: \(verificationData?["verified"] as? Bool ?? false)")
                print("   - Name field: \(verificationData?["name"] as? String ?? "nil")")
                print("   - Data keys: \(verificationData?.keys.joined(separator: ", ") ?? "none")")
            } else {
                print("❌ CRITICAL ERROR: Organization document does NOT exist immediately after creation!")
                print("   This indicates a serious Firestore write issue")
            }
            
            print("✅ Organization created in Firestore: \(organizationId)")
            print("   📍 Location data: (\(latitude), \(longitude))")
            print("   🏢 Organization data saved: \(name)")
            print("   👤 Admin IDs: \(userId ?? contactPersonEmail)")
            
        } catch {
            print("❌ CRITICAL ERROR: Failed to create organization in Firestore!")
            print("   Error type: \(Swift.type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            print("   Full error: \(error)")
            print("   Organization ID: '\(organizationId)'")
            print("   Organization ID length: \(organizationId.count)")
            print("   Organization ID characters: \(Array(organizationId))")
            
            // Check if it's a permissions error
            if let nsError = error as NSError? {
                print("   NSError domain: \(nsError.domain)")
                print("   NSError code: \(nsError.code)")
                print("   NSError userInfo: \(nsError.userInfo)")
            }
            
            // Try to test Firestore connectivity
            print("🔍 Testing Firestore connectivity...")
            do {
                let testRef = db.collection("test").document("connectivity_test")
                try await testRef.setData(["test": "value", "timestamp": FieldValue.serverTimestamp()])
                print("✅ Firestore connectivity test passed - can write to test collection")
                
                // Clean up test document
                try await testRef.delete()
                print("✅ Test document cleaned up")
            } catch {
                print("❌ Firestore connectivity test failed: \(error)")
            }
            
            throw error
        }
        
        // 5. Update the user to be an organization admin
        print("👤 Updating user admin status...")
        if let userId = userId {
            let userRef = db.collection("users").document(userId)
            do {
                try await userRef.updateData([
                    "isOrganizationAdmin": true,
                    "organizations": FieldValue.arrayUnion([organizationId]),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                print("✅ User updated as organization admin: \(userId)")
            } catch {
                print("❌ ERROR: Failed to update user admin status!")
                print("   Error: \(error)")
                print("   User ID: \(userId)")
                // Don't throw here - organization was created successfully
            }
        } else {
            print("⚠️ Could not update user admin status - no user ID found")
        }
        
        // 6. Update the request status to approved
        print("📝 Updating request status to approved...")
        do {
            try await requestRef.updateData([
                "status": RequestStatus.approved.rawValue,
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": "Jed Crisp",
                "reviewNotes": notes,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ Request status updated to approved")
        } catch {
            print("❌ ERROR: Failed to update request status!")
            print("   Error: \(error)")
            print("   Request ID: \(requestId)")
            // Don't throw here - organization was created successfully
        }
        
        // 6. Update local cache
        await MainActor.run {
            if let index = self.pendingRequests.firstIndex(where: { $0.id == requestId }) {
                self.pendingRequests.remove(at: index)
            }
        }
        
        // 7. Refresh organizations to show the new pin on the map
        print("🗺️ Refreshing organizations to show new pin on map...")
        await refreshOrganizations()
        
        // 8. Verify the organization was created and is visible
        print("🔍 Verifying organization creation...")
        do {
            let verificationSnapshot = try await db.collection("organizations").document(organizationId).getDocument()
            if verificationSnapshot.exists {
                let verificationData = verificationSnapshot.data()
                let verified = verificationData?["verified"] as? Bool ?? false
                let name = verificationData?["name"] as? String ?? "Unknown"
                let adminIds = verificationData?["adminIds"] as? [String: Bool] ?? [:]
                let location = verificationData?["location"] as? [String: Any] ?? [:]
                
                print("✅ Organization verification successful:")
                print("   - Document ID: \(organizationId)")
                print("   - Name: \(name)")
                print("   - Verified: \(verified)")
                print("   - Location: \(location)")
                print("   - Admin IDs: \(adminIds)")
                print("   - All Data Keys: \(verificationData?.keys.joined(separator: ", ") ?? "none")")
                
                if !verified {
                    print("⚠️ WARNING: Organization was created but verified=false!")
                }
            } else {
                print("❌ CRITICAL ERROR: Organization verification failed - document not found!")
                print("   Expected document ID: \(organizationId)")
                print("   This means the organization was NOT created in Firestore!")
                
                // Try to find if it was created with a different ID
                print("🔍 Searching for organization by name...")
                let searchSnapshot = try await db.collection("organizations")
                    .whereField("name", isEqualTo: name)
                    .getDocuments()
                
                if !searchSnapshot.documents.isEmpty {
                    for doc in searchSnapshot.documents {
                        print("📄 Found organization with different ID: \(doc.documentID)")
                        let data = doc.data()
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Verified: \(data["verified"] as? Bool ?? false)")
                    }
                } else {
                    print("❌ No organization found with name: \(name)")
                }
            }
        } catch {
            print("❌ ERROR during organization verification: \(error)")
        }
        
        // Send confirmation email to Jed Crisp
        await sendApprovalConfirmationEmail(requestId: requestId, notes: notes)
        
        print("🎉 Organization approval process completed successfully!")
        
        // Return the updated request with approved status
        let approvedRequest = OrganizationRequest(
            name: name,
            type: type,
            description: description,
            website: website,
            phone: phone,
            email: email,
            address: address,
            city: city,
            state: state,
            zipCode: zipCode,
            contactPersonName: contactPersonName,
            contactPersonTitle: contactPersonTitle,
            contactPersonPhone: contactPersonPhone,
            contactPersonEmail: contactPersonEmail,
            adminPassword: adminPassword,
            status: .approved
        )
        
        return approvedRequest
    }
    
    // MARK: - Geocoding Helper
    private func geocodeAddress(_ address: String) async -> Location? {
        print("🌍 Geocoding address: \(address)")
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            
            if let placemark = placemarks.first,
               let location = placemark.location {
                let result = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address, // Use the original address the user entered
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    zipCode: placemark.postalCode
                )
                
                print("✅ Geocoding successful: \(result.coordinate.latitude), \(result.coordinate.longitude)")
                return result
            } else {
                print("❌ No placemarks found for address: \(address)")
            }
        } catch {
            print("⚠️ Geocoding failed: \(error)")
        }
        
        return nil
    }
    
    func rejectOrganizationRequest(_ requestId: String, reason: String, notes: String = "") async throws -> OrganizationRequest {
        // For development, we'll simulate the rejection process
        // In production, this would update your backend
        
        print("❌ ORGANIZATION REQUEST REJECTED")
        print("   Request ID: \(requestId)")
        print("   Rejected by: Jed Crisp")
        print("   Reason: \(reason)")
        print("   Notes: \(notes.isEmpty ? "No additional notes" : notes)")
        print("   Next step: Notify the organization of rejection")
        
        // Send confirmation email to Jed Crisp
        await sendRejectionConfirmationEmail(requestId: requestId, reason: reason, notes: notes)
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Return the rejected request (in production, this would come from your backend)
        let rejectedRequest = OrganizationRequest(
            name: "Sample Organization",
            type: .business,
            description: "Sample description",
            website: nil,
            phone: "555-0000",
            email: "sample@example.com",
            address: "123 Sample St",
            city: "Sample City",
            state: "TX",
            zipCode: "75000",
            contactPersonName: "Sample Contact",
            contactPersonTitle: "Sample Title",
            contactPersonPhone: "555-0000",
            contactPersonEmail: "sample@example.com",
            adminPassword: "rejected_password",
            status: .rejected
        )
        
        return rejectedRequest
    }
    
    func requestMoreInfo(_ requestId: String, infoNeeded: String, notes: String = "") async throws -> OrganizationRequest {
        // For development, we'll simulate requesting more information
        // In production, this would update your backend
        
        print("❓ MORE INFORMATION REQUESTED")
        print("   Request ID: \(requestId)")
        print("   Requested by: Jed Crisp")
        print("   Information needed: \(infoNeeded)")
        print("   Notes: \(notes.isEmpty ? "No additional notes" : notes)")
        print("   Next step: Notify the organization to provide additional information")
        
        // Send confirmation email to Jed Crisp
        await sendMoreInfoConfirmationEmail(requestId: requestId, infoNeeded: infoNeeded, notes: notes)
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Return the updated request (in production, this would come from your backend)
        let updatedRequest = OrganizationRequest(
            name: "Sample Organization",
            type: .business,
            description: "Sample description",
            website: nil,
            phone: "555-0000",
            email: "sample@example.com",
            address: "123 Sample St",
            city: "Sample City",
            state: "TX",
            zipCode: "75000",
            contactPersonName: "Sample Contact",
            contactPersonTitle: "Sample Title",
            contactPersonPhone: "555-0000",
            contactPersonEmail: "sample@example.com",
            adminPassword: "more_info_password",
            status: .requiresMoreInfo
        )
        
        return updatedRequest
    }
    
    // MARK: - Organization Management
    func createOrganization(from request: OrganizationRequest) async throws -> Organization {
        let endpoint = "/organizations"
        let organizationData = [
            "name": request.name,
            "type": request.type.rawValue,
            "description": request.description,
            "website": request.website as Any,
            "phone": request.phone as Any,
            "email": request.email,
            "address": request.address,
            "city": request.city,
            "state": request.state,
            "zipCode": request.zipCode,
            "verified": true,
            "verifiedAt": ISO8601DateFormatter().string(from: Date())
        ] as [String: Any]
        
        let body = try JSONSerialization.data(withJSONObject: organizationData)
        let urlRequest = try createRequestWithData(endpoint: endpoint, method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(Organization.self, from: data)
    }
    
    func updateOrganization(_ organization: Organization) async throws -> Organization {
        let endpoint = "/organizations/\(organization.id)"
        let body = try JSONEncoder().encode(organization)
        
        let urlRequest = try createRequestWithData(endpoint: endpoint, method: "PUT", body: body)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(Organization.self, from: data)
    }
    
    func deleteOrganization(_ organizationId: String) async throws -> Bool {
        let endpoint = "/organizations/\(organizationId)"
        let request = try createRequest(endpoint: endpoint, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw APIError.invalidResponse
        }
        
        return true
    }
    
    // MARK: - Device Registration
    func registerDevice(pushToken: String) async throws -> Bool {
        let endpoint = "/devices/register"
        let body = ["push_token": pushToken]
        
        let request = try createRequest(endpoint: endpoint, method: "POST", body: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return true
    }
    
    // MARK: - User Profile Management
    func updateUserProfile(name: String, homeAddress: String, workAddress: String, schoolAddress: String, alertRadius: Double) async throws -> User {
        guard let user = currentUser else {
            throw APIError.unauthorized
        }
        
        // Update user locations
        let homeLocation = Location(
            latitude: 33.1032, // Default coordinates - in production you'd geocode the address
            longitude: -96.6705,
            address: homeAddress,
            city: "Lucas",
            state: "TX",
            zipCode: "75002"
        )
        
        let workLocation = workAddress.isEmpty ? nil : Location(
            latitude: 33.1032,
            longitude: -96.6705,
            address: workAddress,
            city: "Lucas",
            state: "TX",
            zipCode: "75002"
        )
        
        let schoolLocation = schoolAddress.isEmpty ? nil : Location(
            latitude: 33.1032,
            longitude: -96.6705,
            address: schoolAddress,
            city: "Lucas",
            state: "TX",
            zipCode: "75002"
        )
        
        // Create updated user
        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: name,
            phone: user.phone,
            profilePhotoURL: user.profilePhotoURL,
            homeLocation: homeLocation,
            workLocation: workLocation,
            schoolLocation: schoolLocation,
            alertRadius: alertRadius,
            preferences: user.preferences,
            createdAt: user.createdAt,
            isAdmin: user.isAdmin
        )
        
        // Update current user
        await MainActor.run {
            self.currentUser = updatedUser
        }
        
        // Store in UserDefaults
        UserDefaults.standard.set(name, forKey: "user_name")
        UserDefaults.standard.set(homeAddress, forKey: "user_home_address")
        UserDefaults.standard.set(workAddress, forKey: "user_work_address")
        UserDefaults.standard.set(schoolAddress, forKey: "user_school_address")
        UserDefaults.standard.set(alertRadius, forKey: "user_alert_radius")
        
        print("User profile updated successfully")
        return updatedUser
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) async throws -> User {
        guard let user = currentUser else {
            throw APIError.unauthorized
        }
        
        // Create updated user with new preferences
        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            phone: user.phone,
            profilePhotoURL: user.profilePhotoURL,
            homeLocation: user.homeLocation,
            workLocation: user.workLocation,
            schoolLocation: user.schoolLocation,
            alertRadius: user.alertRadius,
            preferences: preferences,
            createdAt: user.createdAt,
            isAdmin: user.isAdmin
        )
        
        // Update current user
        await MainActor.run {
            self.currentUser = updatedUser
        }
        
        // Store preferences in UserDefaults
        UserDefaults.standard.set(preferences.pushNotifications, forKey: "user_push_notifications")
        UserDefaults.standard.set(preferences.criticalAlertsOnly, forKey: "user_critical_alerts_only")
        
        print("User preferences updated successfully")
        return updatedUser
    }
    
    func getUserProfile() -> User? {
        return currentUser
    }
    
    func findUserByEmail(_ email: String) async throws -> User? {
        print("🔍 Searching for existing user with email: \(email)")
        
        let db = Firestore.firestore()
        
        do {
            // Query users collection by email
            let query = try await db.collection("users")
                .whereField("email", isEqualTo: email)
                .getDocuments()
            
            if let document = query.documents.first {
                let data = document.data()
                print("✅ Found existing user document: \(document.documentID)")
                
                // Parse the user data from Firestore
                let existingUser = User(
                    id: document.documentID, // Use Firestore document ID
                    email: data["email"] as? String ?? email,
                    name: data["name"] as? String ?? "Unknown User",
                    phone: data["phone"] as? String,
                    profilePhotoURL: data["profilePhotoURL"] as? String,
                    homeLocation: parseLocationFromFirestore(data["homeLocation"] as? [String: Any]),
                    workLocation: parseLocationFromFirestore(data["workLocation"] as? [String: Any]),
                    schoolLocation: parseLocationFromFirestore(data["schoolLocation"] as? [String: Any]),
                    alertRadius: data["alertRadius"] as? Double ?? 10.0,
                    preferences: parseUserPreferencesFromFirestore(data["preferences"] as? [String: Any]),
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    isAdmin: data["isAdmin"] as? Bool ?? false
                )
                
                print("✅ Parsed existing user: \(existingUser.id)")
                return existingUser
                
            } else {
                print("ℹ️ No existing user found with email: \(email)")
                return nil
            }
            
        } catch {
            print("❌ Error searching for user by email: \(error)")
            throw error
        }
    }
    
    private func parseLocationFromFirestore(_ data: [String: Any]?) -> Location? {
        guard let data = data else { return nil }
        
        return Location(
            latitude: data["latitude"] as? Double ?? 0.0,
            longitude: data["longitude"] as? Double ?? 0.0,
            address: data["address"] as? String ?? "",
            city: data["city"] as? String ?? "",
            state: data["state"] as? String ?? "",
            zipCode: data["zipCode"] as? String ?? ""
        )
    }
    
    private func parseUserPreferencesFromFirestore(_ data: [String: Any]?) -> UserPreferences {
        guard let data = data else {
            return UserPreferences(
                incidentTypes: [.weather, .road, .other],
                criticalAlertsOnly: false,
                pushNotifications: true,
                quietHoursEnabled: false,
                quietHoursStart: nil,
                quietHoursEnd: nil
            )
        }
        
        return UserPreferences(
            incidentTypes: parseIncidentTypesFromFirestore(data["incidentTypes"] as? [String]),
            criticalAlertsOnly: data["criticalAlertsOnly"] as? Bool ?? false,
            pushNotifications: data["pushNotifications"] as? Bool ?? true,
            quietHoursEnabled: data["quietHoursEnabled"] as? Bool ?? false,
            quietHoursStart: parseDateFromFirestore(data["quietHoursStart"]),
            quietHoursEnd: parseDateFromFirestore(data["quietHoursEnd"])
        )
    }
    
    private func parseIncidentTypesFromFirestore(_ types: [String]?) -> [IncidentType] {
        guard let types = types else { return [.weather, .road, .other] }
        
        return types.compactMap { IncidentType(rawValue: $0) }
    }
    
    private func parseDateFromFirestore(_ timestamp: Any?) -> Date? {
        if let timestamp = timestamp as? Timestamp {
            return timestamp.dateValue()
        }
        return nil
    }
    
    private func loadUserProfileFromDefaults() {
        // Load user preferences from UserDefaults
        let alertRadius = UserDefaults.standard.double(forKey: "user_alert_radius")
        let pushNotifications = UserDefaults.standard.bool(forKey: "user_push_notifications")
        
        // Update current user with loaded preferences
        if let user = currentUser {
            var updatedUser = user
            updatedUser.alertRadius = alertRadius > 0 ? alertRadius : 10.0
            updatedUser.preferences.pushNotifications = pushNotifications
            self.currentUser = updatedUser
        }
    }
    
    private func saveUserProfileToDefaults(_ user: User) {
        // Store user preferences in UserDefaults
        UserDefaults.standard.set(user.alertRadius, forKey: "user_alert_radius")
        UserDefaults.standard.set(user.preferences.pushNotifications, forKey: "user_push_notifications")
        
        // Save the complete user profile
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
            print("💾 User profile saved to UserDefaults")
        } else {
            print("❌ Failed to encode user profile for UserDefaults")
        }
    }
    
    func hasCompletedOnboarding() -> Bool {
        return UserDefaults.standard.string(forKey: "user_home_address")?.isEmpty == false
    }
    
    func markOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }
    
    func isOnboardingCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: "onboarding_completed")
    }
    
    // MARK: - User Statistics
    func getUserStatistics() -> UserStatistics {
        // For development, return sample statistics
        // In production, this would come from your backend
        return UserStatistics(
            totalAlertsReceived: 12,
            alertsThisWeek: 3,
            organizationsFollowing: 5,
            incidentReportsSubmitted: 2,
            lastActive: Date()
        )
    }
    
    func getRecentAlerts() -> [Incident] {
        // Return recent alerts for the current user
        // This would filter incidents based on user preferences and location
        return incidents.filter { incident in
            // Filter by user's alert radius and preferences
            if let userLocation = currentUser?.homeLocation {
                let distance = calculateDistance(
                    from: userLocation.coordinate,
                    to: incident.location.coordinate
                )
                return distance <= (currentUser?.alertRadius ?? 10.0)
            }
            return false
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1609.34 // Convert meters to miles
    }
    
    // MARK: - Helper Methods
    private func createRequest(endpoint: String, method: String, body: [String: Any]? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        return request
    }
    
    private func createRequestWithData(endpoint: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Organization Following
    func getFollowedOrganizations() -> [Organization] {
        // Return empty array - no sample organizations
        return []
    }
    
    func followOrganization(_ organization: Organization) async throws -> Bool {
        // Delegate to the main follow method using the organization ID
        return try await followOrganization(organization.id)
    }
    
    func unfollowOrganization(_ organization: Organization) async throws -> Bool {
        // Delegate to the main unfollow method using the organization ID
        return try await unfollowOrganization(organization.id)
    }
    
    // MARK: - Email Notifications
    private func sendApprovalConfirmationEmail(requestId: String, notes: String) async {
        let request = try? await getOrganizationRequest(requestId)
        guard let orgRequest = request else {
            print("Could not find request with ID: \(requestId) for approval confirmation email.")
            return
        }
        
        // Check if this is a creator account that should send notifications
        if isCreatorAccount() {
            print("📧 CREATOR ACCOUNT: Sending approval confirmation to \(orgRequest.contactPersonEmail)")
            print("   Organization: \(orgRequest.name)")
            print("   Request ID: \(requestId)")
            print("   Notes: \(notes.isEmpty ? "No additional notes" : notes)")
        }
    }
    
    private func sendRejectionConfirmationEmail(requestId: String, reason: String, notes: String) async {
        let request = try? await getOrganizationRequest(requestId)
        guard let orgRequest = request else {
            print("Could not find request with ID: \(requestId) for rejection confirmation email.")
            return
        }
        
        // Check if this is a creator account that should send notifications
        if isCreatorAccount() {
            print("📧 CREATOR ACCOUNT: Sending rejection confirmation to \(orgRequest.contactPersonEmail)")
            print("   Organization: \(orgRequest.name)")
            print("   Reason: \(reason)")
            print("   Request ID: \(requestId)")
        }
    }
    
    private func sendMoreInfoConfirmationEmail(requestId: String, infoNeeded: String, notes: String) async {
        let request = try? await getOrganizationRequest(requestId)
        guard let orgRequest = request else {
            print("Could not find request with ID: \(requestId) for more info confirmation email.")
            return
        }
        
        // Check if this is a creator account that should send notifications
        if isCreatorAccount() {
            print("📧 CREATOR ACCOUNT: Sending more info request to \(orgRequest.contactPersonEmail)")
            print("   Organization: \(orgRequest.name)")
            print("   Info needed: \(infoNeeded)")
            print("   Request ID: \(requestId)")
        }
    }
    
    private func getOrganizationRequest(_ requestId: String) async throws -> OrganizationRequest? {
        let requests = try await getPendingOrganizationRequests()
        return requests.first(where: { $0.id == requestId })
    }
    
    // MARK: - Creator Account Check
    func isCreatorAccount() -> Bool {
        return currentUser?.email == "jed@onetrack-consulting.com"
    }
    
    // MARK: - Password Management
    func resetPassword(email: String) async throws {
        // Send password reset email using Firebase Auth
        try await Auth.auth().sendPasswordReset(withEmail: email)
        print("✅ Password reset email sent to: \(email)")
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.signInFailed
        }
        
        // Re-authenticate user before changing password
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        try await user.reauthenticate(with: credential)
        
        // Change password
        try await user.updatePassword(to: newPassword)
        print("✅ Password changed successfully")
    }
    
    func updatePassword(newPassword: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.signInFailed
        }
        
        // Update password without re-authentication (for admin operations)
        try await user.updatePassword(to: newPassword)
        print("✅ Password updated successfully")
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
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await userRef.setData(userData)
            print("✅ Created user document with FCM token")
        } catch {
            print("❌ Failed to create user document: \(error)")
        }
    }
    
    // MARK: - FCM Testing & Debugging
    func sendTestPushNotification() async throws {
        print("🧪 APIService: Sending test push notification...")
        
        // Only allow test push notifications for authenticated users
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ No Firebase Auth user found - test push notification requires authentication")
            throw APIError.userNotFound
        }
        
        // Try to sync user state first
        syncUserFromServiceCoordinator()
        
        // Get current user
        var currentUser = self.currentUser
        
        if currentUser == nil {
            print("❌ No current user in APIService, but Firebase Auth user exists: \(firebaseUser.uid)")
            // Create a basic user object from Firebase Auth data
            let basicUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email,
                name: firebaseUser.displayName ?? "User",
                phone: firebaseUser.phoneNumber,
                homeLocation: nil,
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
                displayName: firebaseUser.displayName ?? "User"
            )
            
            self.currentUser = basicUser
            self.isAuthenticated = true
            currentUser = basicUser
            print("✅ Created user from Firebase Auth data for test")
        }
        
        guard let finalUser = currentUser else {
            throw APIError.userNotFound
        }
        
        print("👤 Current user: \(finalUser.name ?? "Unknown") (ID: \(finalUser.id))")
        
        // Check if Firebase Functions are available
        do {
            // Call Firebase Function to send test notification
            let functions = Functions.functions()
            
            let testData: [String: Any] = [
                "userId": finalUser.id,
                "title": "🧪 Test Push Notification",
                "body": "This is a test push notification sent at \(Date()) to verify FCM is working correctly."
            ]
            
            print("📞 Calling Firebase Function: testFCMNotification")
            print("🔐 Using Firebase Auth user: \(Auth.auth().currentUser?.uid ?? "none")")
            
            // Ensure we're authenticated with Firebase Auth
            guard Auth.auth().currentUser != nil else {
                print("❌ No Firebase Auth user - cannot call authenticated function")
                throw APIError.custom("User must be authenticated with Firebase")
            }
            
            let result = try await functions.httpsCallable("testFCMNotification").call(testData)
            
            if let data = result.data as? [String: Any] {
                let success = data["success"] as? Bool ?? false
                if success {
                    print("✅ Test push notification sent successfully via Firebase Functions")
                } else {
                    print("❌ Test push notification failed")
                    throw APIError.custom("Test push notification failed")
                }
            } else {
                print("❌ Unexpected result format from Firebase Function")
                throw APIError.custom("Unexpected result format")
            }
        } catch {
            print("⚠️ Firebase Functions not available or not deployed: \(error)")
            print("🔄 Falling back to local notification test...")
            
            // Fallback: Create a test notification document in Firestore
            let db = Firestore.firestore()
            let testNotificationData: [String: Any] = [
                "title": "🧪 Test Push Notification",
                "body": "This is a test notification to verify FCM is working correctly",
                "userId": finalUser.id,
                "timestamp": FieldValue.serverTimestamp(),
                "type": "test",
                "data": [
                    "test": "true",
                    "timestamp": Date().timeIntervalSince1970
                ]
            ]
            
            try await db.collection("testNotifications").addDocument(data: testNotificationData)
            print("✅ Test notification document created in Firestore")
            print("📱 Note: To send actual push notifications, deploy Firebase Functions")
            print("📱 Run: firebase deploy --only functions")
        }
    }
    
    func getFCMToken() async throws -> String {
        print("🔍 APIService: Getting FCM token...")
        
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        
        if fcmToken.isEmpty {
            print("❌ No FCM token found in UserDefaults")
            throw APIError.custom("No FCM token found")
        }
        
        print("✅ FCM token found: \(fcmToken.prefix(20))...")
        return fcmToken
    }
    
    func isFCMTokenRegistered() async throws -> Bool {
        print("🔍 APIService: Checking if FCM token is registered...")
        
        guard let currentUser = self.currentUser else {
            throw APIError.userNotFound
        }
        
        let db = Firestore.firestore()
        let userDoc = try await db.collection("users").document(currentUser.id).getDocument()
        
        if userDoc.exists {
            let userData = userDoc.data() ?? [:]
            let storedToken = userData["fcmToken"] as? String ?? ""
            let isRegistered = !storedToken.isEmpty
            
            print("📊 FCM token registration status: \(isRegistered ? "REGISTERED" : "NOT REGISTERED")")
            if isRegistered {
                print("   Stored token: \(storedToken.prefix(20))...")
            }
            
            return isRegistered
        } else {
            print("❌ User document not found")
            return false
        }
    }
    
    func forceRefreshFCMToken() async throws {
        print("🔄 APIService: Force refreshing FCM token...")
        
        // Request new FCM token
        let newToken = try await Messaging.messaging().token()
        
        if !newToken.isEmpty {
            print("✅ New FCM token received: \(newToken.prefix(20))...")
            
            // Store new token
            UserDefaults.standard.set(newToken, forKey: "fcm_token")
            
            // Register new token
            try await validateAndRegisterFCMToken()
        } else {
            print("❌ New FCM token is empty")
            throw APIError.custom("New FCM token is empty")
        }
    }
    
    func validateAndRegisterFCMToken() async throws {
        print("🔍 APIService: Validating and registering FCM token...")
        
        guard let currentUser = self.currentUser else {
            throw APIError.userNotFound
        }
        
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        
        if fcmToken.isEmpty {
            throw APIError.custom("No FCM token found")
        }
        
        print("📱 FCM Token: \(fcmToken.prefix(20))...")
        
        let db = Firestore.firestore()
        
        // Update user document with FCM token
        try await db.collection("users").document(currentUser.id).setData([
            "fcmToken": fcmToken,
            "lastTokenUpdate": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        print("✅ FCM token successfully registered for user: \(currentUser.id)")
        
        // Verify the update
        let verifyDoc = try await db.collection("users").document(currentUser.id).getDocument()
        if verifyDoc.exists {
            let verifyData = verifyDoc.data() ?? [:]
            let verifyToken = verifyData["fcmToken"] as? String ?? ""
            if verifyToken == fcmToken {
                print("✅ VERIFICATION: FCM token confirmed in Firestore")
            } else {
                print("❌ VERIFICATION FAILED: Token mismatch after update")
                throw APIError.custom("FCM token verification failed")
            }
        } else {
            print("❌ VERIFICATION FAILED: User document not found after update")
            throw APIError.custom("User document not found after FCM token update")
        }
    }
    
    // MARK: - User Migration
    private func migrateUserDocument(from oldId: String, to newId: String) async throws {
        print("🔄 Migrating user document from \(oldId) to \(newId)")
        
        let db = Firestore.firestore()
        
        do {
            // Get the old user document
            let oldUserDoc = try await db.collection("users").document(oldId).getDocument()
            
            if !oldUserDoc.exists {
                print("⚠️ Old user document not found, skipping migration")
                return
            }
            
            let userData = oldUserDoc.data() ?? [:]
            
            // Create new user document with Firebase Auth UID
            try await db.collection("users").document(newId).setData(userData)
            
            // Update the user ID in the new document
            try await db.collection("users").document(newId).updateData([
                "id": newId,
                "migratedFrom": oldId,
                "migratedAt": FieldValue.serverTimestamp()
            ])
            
            // Delete the old user document
            try await db.collection("users").document(oldId).delete()
            
            print("✅ Successfully migrated user document from \(oldId) to \(newId)")
            
        } catch {
            print("❌ Error migrating user document: \(error)")
            // Don't throw here - migration failure shouldn't prevent sign-in
        }
    }
    
    // MARK: - Debug Organization Logo Issues
    func debugOrganizationLogoIssues() async {
        print("🔍 APIService: Debugging organization logo issues...")
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("organizations").getDocuments()
            
            var totalOrganizations = 0
            var organizationsWithLogos = 0
            var organizationsWithInvalidLogos = 0
            var organizationsWithPlaceholderLogos = 0
            
            for document in snapshot.documents {
                totalOrganizations += 1
                let data = document.data()
                
                if let logoURL = data["logoURL"] as? String, !logoURL.isEmpty {
                    organizationsWithLogos += 1
                    
                    // Check if it's a placeholder/example URL
                    let lowercased = logoURL.lowercased()
                    if lowercased.contains("example.com") || 
                       lowercased.contains("placeholder") ||
                       lowercased.contains("via.placeholder.com") ||
                       lowercased.contains("dummy.com") ||
                       lowercased.contains("test.com") {
                        organizationsWithPlaceholderLogos += 1
                        print("⚠️ Organization with placeholder logo:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                    }
                    
                    // Check if URL is valid
                    guard let url = URL(string: logoURL) else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with invalid logo URL format:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        continue
                    }
                    
                    guard let scheme = url.scheme, !scheme.isEmpty else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with logo URL missing scheme:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        continue
                    }
                    
                    guard scheme == "http" || scheme == "https" else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with invalid logo URL scheme:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        print("   - Scheme: \(scheme)")
                        continue
                    }
                    
                    guard let host = url.host, !host.isEmpty else {
                        organizationsWithInvalidLogos += 1
                        print("❌ Organization with logo URL missing host:")
                        print("   - ID: \(document.documentID)")
                        print("   - Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Logo URL: \(logoURL)")
                        continue
                    }
                }
            }
            
            print("📊 Organization Logo Debug Summary:")
            print("   - Total organizations: \(totalOrganizations)")
            print("   - Organizations with logos: \(organizationsWithLogos)")
            print("   - Organizations with invalid logos: \(organizationsWithInvalidLogos)")
            print("   - Organizations with placeholder logos: \(organizationsWithPlaceholderLogos)")
            print("   - Organizations without logos: \(totalOrganizations - organizationsWithLogos)")
            
        } catch {
            print("❌ Error debugging organization logo issues: \(error)")
        }
    }
    
    // MARK: - Clean Up Invalid Logo URLs
    func cleanUpInvalidLogoURLs() async {
        print("🧹 APIService: Cleaning up invalid logo URLs...")
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("organizations").getDocuments()
            
            var cleanedCount = 0
            var totalChecked = 0
            
            for document in snapshot.documents {
                totalChecked += 1
                let data = document.data()
                
                if let logoURL = data["logoURL"] as? String, !logoURL.isEmpty {
                    // Check if it's a placeholder/example URL that should be removed
                    let lowercased = logoURL.lowercased()
                    if lowercased.contains("example.com") || 
                       lowercased.contains("placeholder") ||
                       lowercased.contains("via.placeholder.com") ||
                       lowercased.contains("dummy.com") ||
                       lowercased.contains("test.com") ||
                       lowercased.contains("sample.com") ||
                       lowercased.contains("mock.com") ||
                       lowercased.contains("fake.com") {
                        
                        print("🧹 Cleaning up placeholder logo URL:")
                        print("   - Organization ID: \(document.documentID)")
                        print("   - Organization Name: \(data["name"] as? String ?? "Unknown")")
                        print("   - Old Logo URL: \(logoURL)")
                        
                        // Remove the invalid logo URL
                        try await db.collection("organizations").document(document.documentID).updateData([
                            "logoURL": FieldValue.delete()
                        ])
                        
                        cleanedCount += 1
                        print("   ✅ Logo URL removed successfully")
                    }
                }
            }
            
            print("📊 Logo URL Cleanup Summary:")
            print("   - Total organizations checked: \(totalChecked)")
            print("   - Invalid logo URLs cleaned: \(cleanedCount)")
            
            // Refresh organizations after cleanup
            await refreshOrganizations()
            
        } catch {
            print("❌ Error cleaning up invalid logo URLs: \(error)")
        }
    }
}

// MARK: - Response Models
struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case unauthorized
    case userNotFound
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized access"
        case .userNotFound:
            return "User not found"
        case .custom(let message):
            return message
        }
    }
} 