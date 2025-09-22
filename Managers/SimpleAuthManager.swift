import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import SwiftUI

class SimpleAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    init() {
        // Check if user is already signed in
        checkAuthState()
        
        // Setup FCM token registration
        setupFCMTokenRegistration()
    }
    
    // MARK: - Authentication State Check
    private func checkAuthState() {
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ User already signed in: \(firebaseUser.uid)")
            Task {
                await loadUserData(from: firebaseUser)
            }
        } else {
            print("❌ No user signed in")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    // MARK: - Manual Authentication State Check
    func checkAndRestoreAuthState() {
        print("🔄 Manual authentication state check...")
        checkAuthState()
    }
    
    // MARK: - Sign In with Email
    func signInWithEmail(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ Firebase Auth sign in successful: \(authResult.user.uid)")
            
            await loadUserData(from: authResult.user)
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                print("❌ Sign in failed: \(error)")
            }
        }
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() async {
        print("🔐 SimpleAuthManager: Starting Google sign-in...")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw SimpleAuthError.clientIDNotFound
            }
            
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let presentingViewController = windowScene.windows.first?.rootViewController else {
                throw SimpleAuthError.noRootViewController
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw SimpleAuthError.noIDToken
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
            
            print("✅ Google sign in successful: \(authResult.user.uid)")
            print("   Email: \(authResult.user.email ?? "NIL")")
            print("   Display Name: \(authResult.user.displayName ?? "NIL")")
            print("🔄 Starting loadUserData for Google user...")
            await loadUserData(from: authResult.user)
            print("✅ loadUserData completed for Google user")
            print("🔍 After loadUserData - isAuthenticated: \(isAuthenticated)")
            print("🔍 After loadUserData - currentUser: \(currentUser?.id ?? "NIL")")
            
            // Final check - verify the state is properly set
            await MainActor.run {
                print("🔍 Final state check in SimpleAuthManager:")
                print("   isAuthenticated: \(self.isAuthenticated)")
                print("   currentUser: \(self.currentUser?.id ?? "NIL")")
                print("   currentUser email: \(self.currentUser?.email ?? "NIL")")
            }
            
            // If somehow the user wasn't set, create a fallback user
            if !isAuthenticated || currentUser == nil {
                print("⚠️ Authentication state not properly set after Google sign-in, creating fallback user...")
                let fallbackUser = User(
                    id: authResult.user.uid,
                    email: authResult.user.email,
                    name: authResult.user.displayName ?? "User",
                    phone: authResult.user.phoneNumber,
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
                    displayName: authResult.user.displayName ?? "User"
                )
                
                await MainActor.run {
                    self.currentUser = fallbackUser
                    self.isAuthenticated = true
                    self.isLoading = false
                    print("✅ Fallback user created and set as authenticated")
                }
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                print("❌ Google sign in failed: \(error)")
            }
        }
    }
    
    // MARK: - Load User Data
    private func loadUserData(from firebaseUser: FirebaseAuth.User) async {
        print("🔄 Loading user data for Firebase user: \(firebaseUser.uid)")
        print("   Email: \(firebaseUser.email ?? "NIL")")
        print("   Display Name: \(firebaseUser.displayName ?? "NIL")")
        
        do {
            // Try to find existing user in Firestore
            print("🔍 Searching for user in Firestore by email: \(firebaseUser.email ?? "NIL")")
            let userQuery = try await db.collection("users")
                .whereField("email", isEqualTo: firebaseUser.email ?? "")
                .getDocuments()
            
            print("🔍 Firestore query returned \(userQuery.documents.count) documents")
            
            if let existingUserDoc = userQuery.documents.first {
                // Load existing user
                let userData = existingUserDoc.data()
                let user = User(
                    id: firebaseUser.uid,
                    email: userData["email"] as? String ?? firebaseUser.email ?? "",
                    name: userData["name"] as? String ?? firebaseUser.displayName ?? "User",
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
                    displayName: userData["displayName"] as? String ?? firebaseUser.displayName ?? "User"
                )
                
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.isLoading = false
                }
                
            } else {
                // Create new user
                let newUser = User(
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
                
                // Save to Firestore
                try await db.collection("users").document(firebaseUser.uid).setData([
                    "id": newUser.id,
                    "email": newUser.email ?? "",
                    "name": newUser.name ?? "User",
                    "displayName": newUser.displayName ?? "User",
                    "createdAt": FieldValue.serverTimestamp(),
                    "isAdmin": false
                ])
                
                await MainActor.run {
                    self.currentUser = newUser
                    self.isAuthenticated = true
                    self.isLoading = false
                }
            }
            
        } catch {
            print("❌ Failed to load user data: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error details: \(error.localizedDescription)")
            
            // Fallback: Create a basic user from Firebase Auth data even if Firestore fails
            print("🔄 Creating fallback user from Firebase Auth data...")
            let fallbackUser = User(
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
            
            await MainActor.run {
                self.currentUser = fallbackUser
                self.isAuthenticated = true
                self.isLoading = false
                self.errorMessage = nil // Clear any previous error
                print("✅ Fallback user created and authenticated: \(fallbackUser.name ?? "Unknown")")
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        print("🚪 Signing out...")
        
        do {
            try Auth.auth().signOut()
            print("✅ Signed out from Firebase Auth")
        } catch {
            print("❌ Error signing out: \(error)")
        }
        
        // Clear local state
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        
        print("✅ Sign out completed")
    }
    
    // MARK: - Get Current User ID for FCM
    func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // MARK: - FCM Token Registration
    private func setupFCMTokenRegistration() {
        // Listen for FCM token updates
        NotificationCenter.default.addObserver(
            forName: .fcmTokenReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let token = notification.userInfo?["token"] as? String {
                self?.registerFCMTokenWithUser(token)
            }
        }
    }
    
    private func registerFCMTokenWithUser(_ token: String) {
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID for FCM token registration")
            return
        }
        
        print("📱 Registering FCM token for user: \(userId)")
        
        Task {
            do {
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                
                try await db.collection("users").document(userId).updateData([
                    "fcmToken": token,
                    "lastTokenUpdate": FieldValue.serverTimestamp(),
                    "platform": "ios",
                    "appVersion": appVersion,
                    "tokenStatus": "active"
                ])
                print("✅ FCM token registered for user: \(userId)")
            } catch {
                print("❌ Failed to register FCM token: \(error)")
            }
        }
    }
    
    // MARK: - FCM Token Testing
    func testFCMToken() async -> String? {
        print("🧪 SimpleAuthManager: Testing FCM token...")
        
        // Check if we have a stored FCM token
        if let storedToken = UserDefaults.standard.string(forKey: "fcm_token"), !storedToken.isEmpty {
            print("✅ Found stored FCM token: \(String(storedToken.prefix(20)))...")
            return storedToken
        }
        
        print("❌ No stored FCM token found")
        return nil
    }
    
    func getFCMTokenStatus() async -> [String: Any] {
        print("🔍 SimpleAuthManager: Getting FCM token status...")
        
        var status: [String: Any] = [:]
        
        // Check stored token
        if let storedToken = UserDefaults.standard.string(forKey: "fcm_token"), !storedToken.isEmpty {
            status["hasStoredToken"] = true
            status["tokenLength"] = storedToken.count
            status["tokenPreview"] = String(storedToken.prefix(20))
        } else {
            status["hasStoredToken"] = false
        }
        
        // Check if user is authenticated
        status["isAuthenticated"] = isAuthenticated
        status["hasCurrentUser"] = currentUser != nil
        
        // Check Firestore for user's FCM token
        if let userId = getCurrentUserId() {
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if userDoc.exists {
                    let userData = userDoc.data() ?? [:]
                    let firestoreToken = userData["fcmToken"] as? String
                    status["hasFirestoreToken"] = firestoreToken != nil && !firestoreToken!.isEmpty
                    status["firestoreTokenLength"] = firestoreToken?.count ?? 0
                } else {
                    status["hasFirestoreToken"] = false
                }
            } catch {
                status["firestoreError"] = error.localizedDescription
            }
        }
        
        return status
    }
}

// MARK: - Auth Errors
enum SimpleAuthError: Error, LocalizedError {
    case clientIDNotFound
    case noRootViewController
    case noIDToken
    
    var errorDescription: String? {
        switch self {
        case .clientIDNotFound:
            return "Firebase configuration not found"
        case .noRootViewController:
            return "Unable to present sign-in flow"
        case .noIDToken:
            return "Google authentication failed"
        }
    }
}
