import Foundation
import UserNotifications
import Combine
import UIKit
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth

// MARK: - Notification Names
extension Notification.Name {
    static let organizationAlertPosted = Notification.Name("organizationAlertPosted")
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
}

class NotificationManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var unreadNotificationCount = 0
    @Published var fcmToken: String?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
        
        // Listen for organization alert notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrganizationAlertPosted),
            name: .organizationAlertPosted,
            object: nil
        )
        
        // Also listen for the alternative notification name
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrganizationAlertPosted),
            name: NSNotification.Name("OrganizationAlertPosted"),
            object: nil
        )
        
        // Listen for FCM token updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFCMTokenReceived),
            name: .fcmTokenReceived,
            object: nil
        )
        
        // Initialize app badge count
        updateAppBadge()
        
        // Get current FCM token if available
        if let token = UserDefaults.standard.string(forKey: "fcm_token"), !token.isEmpty {
            self.fcmToken = token
            print("📱 Loaded stored FCM token: \(token.prefix(20))...")
        }
    }
    
    // MARK: - FCM Token Management
    @objc private func handleFCMTokenReceived(_ notification: Notification) {
        if let token = notification.userInfo?["token"] as? String {
            DispatchQueue.main.async {
                self.fcmToken = token
                print("📱 FCM token updated in NotificationManager: \(token)")
                
                // Store the token in UserDefaults
                UserDefaults.standard.set(token, forKey: "fcm_token")
                
                // Automatically register the token with the user profile
                Task {
                    await self.registerFCMTokenWithUser(token)
                }
            }
        }
    }
    
    func updateFCMToken(_ token: String) {
        DispatchQueue.main.async {
            self.fcmToken = token
            UserDefaults.standard.set(token, forKey: "fcm_token")
            print("📱 FCM token updated: \(token)")
            
            // Post notification for other components
            NotificationCenter.default.post(
                name: .fcmTokenReceived,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
    
    // MARK: - Push Notification Registration
    func registerForPushNotifications() {
        print("📱 Registering for push notifications...")
        
        // Request authorization first
        requestPermissions { [weak self] granted in
            if granted {
                print("✅ Notification permissions granted, registering for remote notifications")
                
                // Register for remote notifications on main thread
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📱 Registered for remote notifications (APNS)")
                }
                
                // Wait a moment for APNS token to be set, then request FCM token
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.requestFCMToken()
                }
            } else {
                print("❌ Notification permissions denied")
            }
        }
    }
    
    private func requestFCMToken() {
        print("🔥 Requesting FCM token...")
        
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error getting FCM token: \(error)")
                return
            }
            
            if let token = token, !token.isEmpty {
                print("✅ FCM token received: \(token)")
                self?.updateFCMToken(token)
                
                // Automatically register the token with the user profile
                Task {
                    await self?.registerFCMTokenWithUser(token)
                }
            } else {
                print("⚠️ FCM token is empty")
            }
        }
    }
    
    private func registerFCMTokenWithUser(_ token: String) async {
        print("📱 Registering FCM token with user profile...")
        
        // Get current user ID using centralized method
        guard let userId = getCurrentUserId() else {
            print("❌ No current user found for FCM token registration")
            // Store token for later registration
            UserDefaults.standard.set(token, forKey: "pending_fcm_token")
            return
        }
        
        print("✅ Found user ID for FCM registration: \(userId)")
        
        // Update user's FCM token in Firestore
        do {
            let db = Firestore.firestore()
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            
            try await db.collection("users").document(userId).updateData([
                "fcmToken": token,
                "lastTokenUpdate": FieldValue.serverTimestamp(),
                "platform": "ios",
                "appVersion": appVersion,
                "tokenStatus": "active"
            ])
            print("✅ FCM token registered for user: \(userId)")
            
            // Clear any pending token
            UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        } catch {
            print("❌ Failed to register FCM token: \(error)")
        }
    }
    
    // MARK: - Centralized User ID Resolution
    private func getCurrentUserId() -> String? {
        print("🔍 NotificationManager.getCurrentUserId: Checking for user ID...")
        
        // First try Firebase Auth (most reliable)
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Found Firebase Auth user: \(firebaseUser.uid)")
            return firebaseUser.uid
        }
        
        // Then try UserDefaults
        if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            print("✅ Found user ID from UserDefaults: \(defaultsUserId)")
            return defaultsUserId
        }
        
        // If no user found, don't register FCM tokens
        print("❌ No user found - skipping FCM token registration")
        
        return nil
    }
    
    // MARK: - Retry FCM Token Registration
    func retryFCMTokenRegistration() {
        print("🔄 Retrying FCM token registration...")
        
        // Check if we have a pending token
        if let pendingToken = UserDefaults.standard.string(forKey: "pending_fcm_token") {
            print("📱 Found pending FCM token, attempting registration...")
            Task {
                await registerFCMTokenWithUser(pendingToken)
            }
        } else if let currentToken = fcmToken {
            print("📱 Re-registering current FCM token...")
            Task {
                await registerFCMTokenWithUser(currentToken)
            }
        } else {
            print("📱 No FCM token available, checking for stored token...")
            
            // Debug: Check what's actually in UserDefaults
            let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
            let fcmKeys = allKeys.filter { $0.contains("fcm") }
            print("🔍 Debug - FCM related keys in UserDefaults: \(fcmKeys)")
            
            // Check if we have a stored FCM token in UserDefaults
            if let storedToken = UserDefaults.standard.string(forKey: "fcm_token"), !storedToken.isEmpty {
                print("📱 Found stored FCM token, using it...")
                self.fcmToken = storedToken
                Task {
                    await registerFCMTokenWithUser(storedToken)
                }
            } else {
                print("📱 No stored FCM token found in UserDefaults")
                
                // Check if APNS token is set before attempting FCM token retrieval
                if Messaging.messaging().apnsToken == nil {
                    print("⏳ APNS token not set yet, storing request for later...")
                    UserDefaults.standard.set(true, forKey: "pending_fcm_request")
                    return
                }
                
                // Try to get FCM token directly from Firebase Messaging
                print("🔄 Attempting to get FCM token directly from Firebase...")
                Messaging.messaging().token { [weak self] token, error in
                    if let error = error {
                        print("❌ Error getting FCM token directly: \(error)")
                    } else if let token = token, !token.isEmpty {
                        print("✅ Got FCM token directly from Firebase: \(token.prefix(20))...")
                        self?.updateFCMToken(token)
                        Task {
                            await self?.registerFCMTokenWithUser(token)
                        }
                    } else {
                        print("❌ No FCM token available from Firebase")
                        
                        // Check if APNS token is set before requesting FCM token
                        if Messaging.messaging().apnsToken != nil {
                            print("✅ APNS token is set, requesting FCM token...")
                            self?.requestFCMToken()
                        } else {
                            print("⏳ APNS token not set yet, storing request for later...")
                            // Store a flag that we need to request FCM token once APNS is ready
                            UserDefaults.standard.set(true, forKey: "pending_fcm_request")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Force FCM Token Registration
    func forceFCMTokenRegistration() {
        print("🔄 Force FCM token registration...")
        
        // Check if APNS token is set first
        if Messaging.messaging().apnsToken == nil {
            print("⏳ APNS token not set yet, waiting...")
            // Store request for later
            UserDefaults.standard.set(true, forKey: "pending_fcm_request")
            return
        }
        
        print("✅ APNS token is set, requesting FCM token...")
        
        // First try to get token directly from Firebase
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error getting FCM token: \(error)")
            } else if let token = token, !token.isEmpty {
                print("✅ FCM token received: \(token.prefix(20))...")
                self?.updateFCMToken(token)
                Task {
                    await self?.registerFCMTokenWithUser(token)
                }
            } else {
                print("❌ No FCM token available from Firebase")
            }
        }
    }
    
    // MARK: - Wait for APNS Token
    func waitForAPNSTokenAndRegisterFCM() {
        print("⏳ Waiting for APNS token to be available...")
        
        // First, try to manually trigger APNS registration
        print("🔄 Attempting to manually trigger APNS registration...")
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        // Check every 500ms for APNS token
        var attempts = 0
        let maxAttempts = 20 // 10 seconds total
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            attempts += 1
            
            if Messaging.messaging().apnsToken != nil {
                print("✅ APNS token is now available, registering FCM token...")
                timer.invalidate()
                self.forceFCMTokenRegistration()
            } else if attempts >= maxAttempts {
                print("❌ Timeout waiting for APNS token")
                timer.invalidate()
                
                // Try one more time to register for remote notifications
                print("🔄 Final attempt to register for remote notifications...")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("⏳ Still waiting for APNS token... (attempt \(attempts)/\(maxAttempts))")
            }
        }
    }
    
    // MARK: - Force APNS Registration
    func forceAPNSRegistration() {
        print("🔄 Force APNS registration...")
        
        // Check current notification authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Current notification settings: \(settings.authorizationStatus.rawValue)")
            
            if settings.authorizationStatus == .authorized {
                print("✅ Notifications authorized, registering for remote notifications...")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Notifications not authorized, requesting permissions...")
                DispatchQueue.main.async {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if granted {
                            print("✅ Notification permissions granted, registering for remote notifications...")
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        } else {
                            print("❌ Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Debug FCM Token Status
    func debugFCMTokenStatus() {
        print("🔍 FCM Token Debug Status:")
        print("   - Current FCM Token: \(fcmToken ?? "nil")")
        print("   - Pending Token: \(UserDefaults.standard.string(forKey: "pending_fcm_token") ?? "nil")")
        print("   - Stored Token: \(UserDefaults.standard.string(forKey: "fcm_token") ?? "nil")")
        print("   - Current User ID: \(getCurrentUserId() ?? "nil")")
        print("   - Is Authorized: \(isAuthorized)")
        print("   - Authorization Status: \(authorizationStatus.rawValue)")
        
        // Check Firestore for user's FCM token
        if let userId = getCurrentUserId() {
            Task {
                do {
                    let db = Firestore.firestore()
                    let userDoc = try await db.collection("users").document(userId).getDocument()
                    if userDoc.exists {
                        let userData = userDoc.data() ?? [:]
                        let storedToken = userData["fcmToken"] as? String ?? "nil"
                        print("   - Stored FCM Token in Firestore: \(storedToken)")
                        print("   - Token matches current: \(storedToken == fcmToken)")
                    } else {
                        print("   - User document not found in Firestore")
                    }
                } catch {
                    print("   - Error checking Firestore: \(error)")
                }
            }
        }
    }
    
    // MARK: - Comprehensive Push Notification Debug
    func debugPushNotificationSystem() {
        print("🔍 ===== PUSH NOTIFICATION SYSTEM DEBUG =====")
        
        // 1. Check FCM Token Status
        print("📱 1. FCM Token Status:")
        print("   - Current FCM Token: \(fcmToken ?? "nil")")
        print("   - Stored Token: \(UserDefaults.standard.string(forKey: "fcm_token") ?? "nil")")
        print("   - Pending Token: \(UserDefaults.standard.string(forKey: "pending_fcm_token") ?? "nil")")
        print("   - Pending Request: \(UserDefaults.standard.bool(forKey: "pending_fcm_request"))")
        
        // 2. Check APNS Status
        print("📱 2. APNS Status:")
        print("   - APNS Token: \(Messaging.messaging().apnsToken != nil ? "SET" : "NOT SET")")
        print("   - Authorization Status: \(authorizationStatus.rawValue)")
        print("   - Is Authorized: \(isAuthorized)")
        
        // 3. Check User Authentication
        print("👤 3. User Authentication:")
        if let userId = getCurrentUserId() {
            print("   - User ID: \(userId)")
            
            // Check Firestore for user's FCM token
            Task {
                do {
                    let db = Firestore.firestore()
                    let userDoc = try await db.collection("users").document(userId).getDocument()
                    if userDoc.exists {
                        let userData = userDoc.data() ?? [:]
                        let storedToken = userData["fcmToken"] as? String ?? "nil"
                        let platform = userData["platform"] as? String ?? "unknown"
                        let tokenStatus = userData["tokenStatus"] as? String ?? "unknown"
                        let lastUpdate = userData["lastTokenUpdate"] as? Timestamp
                        
                        print("   - Stored FCM Token in Firestore: \(storedToken)")
                        print("   - Platform: \(platform)")
                        print("   - Token Status: \(tokenStatus)")
                        print("   - Last Update: \(lastUpdate?.dateValue() ?? Date.distantPast)")
                        print("   - Token matches current: \(storedToken == fcmToken)")
                        
                        // Check if user is following any organizations
                        let followingQuery = try await db.collection("users").document(userId).collection("following").getDocuments()
                        print("   - Following \(followingQuery.documents.count) organizations")
                        
                        if followingQuery.documents.count > 0 {
                            print("   - Following organizations:")
                            for doc in followingQuery.documents {
                                let orgData = doc.data()
                                let orgName = orgData["name"] as? String ?? "Unknown"
                                print("     • \(orgName) (ID: \(doc.documentID))")
                            }
                        }
                        
                    } else {
                        print("   - User document not found in Firestore")
                    }
                } catch {
                    print("   - Error checking Firestore: \(error)")
                }
            }
        } else {
            print("   - No current user ID found")
        }
        
        // 4. Check Notification Settings
        print("🔔 4. Notification Settings:")
        print("   - Push Notifications Enabled: \(UserDefaults.standard.bool(forKey: "pushNotificationsEnabled"))")
        print("   - Critical Alerts Enabled: \(UserDefaults.standard.bool(forKey: "criticalAlertsEnabled"))")
        
        // 5. Check Recent Notifications
        print("📬 5. Recent Notifications:")
        print("   - Unread Count: \(unreadNotificationCount)")
        print("   - Is Authorized: \(isAuthorized)")
        print("   - Authorization Status: \(authorizationStatus.rawValue)")
        
        print("🔍 ===== END DEBUG =====")
    }
    
    // MARK: - Check Following Status
    func checkFollowingStatus() async {
        print("🔍 ===== FOLLOWING STATUS CHECK =====")
        
        guard let userId = getCurrentUserId() else {
            print("❌ No current user ID found")
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // Check all organizations and see which ones the user follows
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            print("📊 Total organizations in database: \(orgsSnapshot.documents.count)")
            
            var followingCount = 0
            var followedOrganizations: [String] = []
            
            for orgDoc in orgsSnapshot.documents {
                let orgId = orgDoc.documentID
                let orgData = orgDoc.data()
                let orgName = orgData["name"] as? String ?? "Unknown"
                
                // Check if user follows this organization
                let followerDoc = try await db.collection("organizations").document(orgId).collection("followers").document(userId).getDocument()
                
                if followerDoc.exists {
                    followingCount += 1
                    followedOrganizations.append("\(orgName) (ID: \(orgId))")
                    print("✅ Following: \(orgName) (ID: \(orgId))")
                    
                    // Check follower preferences
                    let followerData = followerDoc.data() ?? [:]
                    let alertsEnabled = followerData["alertsEnabled"] as? Bool ?? true
                    print("   - Alerts enabled: \(alertsEnabled)")
                    
                    // Check group preferences
                    if let groups = followerData["groups"] as? [String: Bool] {
                        print("   - Group preferences: \(groups)")
                    } else {
                        print("   - No group preferences set")
                    }
                } else {
                    print("❌ Not following: \(orgName) (ID: \(orgId))")
                }
            }
            
            print("📊 Summary:")
            print("   - Following \(followingCount) organizations")
            print("   - Followed organizations: \(followedOrganizations)")
            
            if followingCount == 0 {
                print("⚠️ WARNING: You are not following any organizations!")
                print("   This means you won't receive any push notifications.")
                print("   Go to the Map view and follow some organizations.")
            }
            
        } catch {
            print("❌ Error checking following status: \(error)")
        }
        
        print("🔍 ===== END FOLLOWING CHECK =====")
    }
    
    // MARK: - Test FCM Token Registration
    func testFCMTokenRegistration() {
        print("🧪 Testing FCM Token Registration...")
        
        // Get current FCM token
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("❌ Error getting FCM token: \(error)")
                return
            }
            
            guard let token = token, !token.isEmpty else {
                print("❌ No FCM token available")
                return
            }
            
            print("✅ FCM Token: \(token.prefix(20))...")
            print("   - Token Length: \(token.count)")
            
            // Update local token
            self?.updateFCMToken(token)
            
            // Register with user profile
            Task {
                await self?.registerFCMTokenWithUser(token)
            }
        }
    }
    
    // MARK: - Test Local Notification
    func testLocalNotification() {
        print("🧪 Testing local notification...")
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This is a test notification to verify the system is working"
        content.sound = .default
        content.categoryIdentifier = "TEST_NOTIFICATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification failed: \(error)")
            } else {
                print("✅ Test notification scheduled successfully")
                print("🧪 Test notification will appear in 2 seconds")
            }
        }
    }
    
    // MARK: - Comprehensive Notification System Test
    func testNotificationSystem() {
        print("🧪 ===== COMPREHENSIVE NOTIFICATION SYSTEM TEST =====")
        
        // 1. Test local notification
        print("📱 1. Testing local notification...")
        testLocalNotification()
        
        // 2. Test FCM token registration
        print("📱 2. Testing FCM token registration...")
        testFCMTokenRegistration()
        
        // 3. Debug system status
        print("📱 3. Debugging system status...")
        debugPushNotificationSystem()
        
        // 4. Check following status
        print("📱 4. Checking following status...")
        Task {
            await checkFollowingStatus()
        }
        
        // 5. Test push notification sending
        print("📱 5. Testing push notification sending...")
        testPushNotificationSending()
        
        print("🧪 ===== END COMPREHENSIVE TEST =====")
    }
    
    // MARK: - Test Push Notification Sending
    func testPushNotificationSending() {
        print("🧪 Testing push notification sending...")
        
        // Check if we have a valid FCM token
        guard let token = fcmToken, !token.isEmpty else {
            print("❌ No FCM token available for testing")
            return
        }
        
        print("✅ FCM token available: \(token.prefix(20))...")
        
        // Check if user is authenticated
        guard let userId = getCurrentUserId() else {
            print("❌ No user ID available for testing")
            return
        }
        
        print("✅ User ID available: \(userId)")
        
        // Test sending a notification to ourselves
        Task {
            do {
                let db = Firestore.firestore()
                
                // Create a test notification document
                let testNotificationData: [String: Any] = [
                    "title": "🧪 Test Push Notification",
                    "body": "This is a test notification to verify push notifications are working",
                    "userId": userId,
                    "fcmToken": token,
                    "timestamp": FieldValue.serverTimestamp(),
                    "type": "test",
                    "data": [
                        "test": "true",
                        "timestamp": Date().timeIntervalSince1970
                    ]
                ]
                
                // Add to a test collection
                try await db.collection("testNotifications").addDocument(data: testNotificationData)
                print("✅ Test notification document created in Firestore")
                
                // Also try to send via FCM directly (this would require Firebase Functions)
                print("📱 Note: To send actual push notifications, you need Firebase Functions deployed")
                print("📱 The test notification document has been created in Firestore")
                
            } catch {
                print("❌ Error creating test notification: \(error)")
            }
        }
    }
    
    // MARK: - Permission Request with Completion Handler
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        print("🔔 Requesting notification permissions...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                self.checkAuthorizationStatus()
                completion(granted)
            }
            
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied")
            }
        }
    }
    
    // MARK: - Force Request APNs Permission
    func forceRequestAPNsPermission() async -> Bool {
        print("🔄 Force requesting APNs permission...")
        
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.checkAuthorizationStatus()
                    
                    if let error = error {
                        print("❌ APNs permission error: \(error)")
                    } else if granted {
                        print("✅ APNs permissions granted")
                        // Immediately register for remote notifications
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        print("❌ APNs permissions denied")
                    }
                    
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Delete and Refresh FCM Token
    func deleteAndRefreshFCMToken() async -> String? {
        print("🔄 Deleting old FCM token and getting new one...")
        
        return await withCheckedContinuation { continuation in
            // First, clear all local FCM data
            UserDefaults.standard.removeObject(forKey: "fcm_token")
            UserDefaults.standard.removeObject(forKey: "fcmToken")
            UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
            UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
            
            // Clear from NotificationManager
            self.fcmToken = nil
            
            // Delete the token from Firebase
            Messaging.messaging().deleteToken { error in
                if let error = error {
                    print("❌ Error deleting token: \(error)")
                    continuation.resume(returning: nil)
                } else {
                    print("✅ Old token deleted from Firebase")
                    
                    // Wait a moment for the deletion to propagate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Force re-register for APNs to get a fresh token
                        UIApplication.shared.registerForRemoteNotifications()
                        
                        // Wait a bit more for APNs token to be set
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Now get the new FCM token
                            Messaging.messaging().token { token, error in
                                if let error = error {
                                    print("❌ Error getting new token: \(error)")
                                    continuation.resume(returning: nil)
                                } else if let token = token, !token.isEmpty {
                                    print("🎯 New FCM token: \(token)")
                                    
                                    // Update local state
                                    DispatchQueue.main.async {
                                        self.fcmToken = token
                                        UserDefaults.standard.set(token, forKey: "fcm_token")
                                        
                                        // Register token in Firestore
                                        Task {
                                            await self.registerFCMTokenWithUser(token)
                                        }
                                    }
                                    
                                    continuation.resume(returning: token)
                                } else {
                                    print("❌ No new token received")
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Force New APNs Token
    func forceNewAPNsToken() async -> String? {
        print("🔄 Forcing new APNs token...")
        
        return await withCheckedContinuation { continuation in
            // Step 1: Clear all FCM data
            UserDefaults.standard.removeObject(forKey: "fcm_token")
            UserDefaults.standard.removeObject(forKey: "fcmToken")
            UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
            UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
            self.fcmToken = nil
            
            // Step 2: Delete FCM token from Firebase
            Messaging.messaging().deleteToken { error in
                if let error = error {
                    print("❌ Error deleting FCM token: \(error)")
                } else {
                    print("✅ FCM token deleted from Firebase")
                }
                
                // Step 3: Unregister from APNs completely
                DispatchQueue.main.async {
                    UIApplication.shared.unregisterForRemoteNotifications()
                    print("📱 Unregistered from APNs")
                    
                    // Step 4: Wait and re-register for APNs
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        UIApplication.shared.registerForRemoteNotifications()
                        print("📱 Re-registered for APNs")
                        
                        // Step 5: Wait for new APNs token and get FCM token
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            Messaging.messaging().token { token, error in
                                if let error = error {
                                    print("❌ Error getting new FCM token: \(error)")
                                    continuation.resume(returning: nil)
                                } else if let token = token, !token.isEmpty {
                                    print("🎯 New FCM token after APNs reset: \(token)")
                                    
                                    DispatchQueue.main.async {
                                        self.fcmToken = token
                                        UserDefaults.standard.set(token, forKey: "fcm_token")
                                        
                                        Task {
                                            await self.registerFCMTokenWithUser(token)
                                        }
                                    }
                                    
                                    continuation.resume(returning: token)
                                } else {
                                    print("❌ No new FCM token received")
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleLocalNotification(for incident: Incident) {
        let content = UNMutableNotificationContent()
        content.title = "Local Alert: \(incident.title)"
        content.body = incident.description
        content.sound = .default
        content.categoryIdentifier = "INCIDENT_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "incident-\(incident.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                // Increment app badge for new notification
                DispatchQueue.main.async {
                    self.incrementBadge()
                }
            }
        }
    }
    
    func scheduleCriticalAlert(for incident: Incident) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 CRITICAL ALERT: \(incident.title)"
        content.body = incident.description
        content.sound = .defaultCritical
        content.categoryIdentifier = "CRITICAL_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "critical-\(incident.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling critical notification: \(error)")
            } else {
                // Increment app badge for new notification
                DispatchQueue.main.async {
                    self.incrementBadge()
                }
            }
        }
    }
    
    // MARK: - Organization Alert Notifications
    func scheduleOrganizationAlertNotification(for alert: OrganizationAlert) {
        let content = UNMutableNotificationContent()
        
        // Customize notification based on alert severity
        switch alert.severity {
        case .critical:
            content.title = "🚨 CRITICAL: \(alert.title)"
            content.sound = .defaultCritical
            content.categoryIdentifier = "ORGANIZATION_CRITICAL_ALERT"
        case .high:
            content.title = "⚠️ HIGH PRIORITY: \(alert.title)"
            content.sound = .default
            content.categoryIdentifier = "ORGANIZATION_HIGH_ALERT"
        case .medium:
            content.title = "📢 \(alert.title)"
            content.sound = .default
            content.categoryIdentifier = "ORGANIZATION_MEDIUM_ALERT"
        case .low:
            content.title = "ℹ️ \(alert.title)"
            content.sound = .default
            content.categoryIdentifier = "ORGANIZATION_LOW_ALERT"
        }
        
        content.body = "\(alert.organizationName): \(alert.description)"
        content.subtitle = "From \(alert.organizationName)"
        
        // Add organization info to user info
        content.userInfo = [
            "alertId": alert.id,
            "organizationId": alert.organizationId,
            "organizationName": alert.organizationName,
            "alertType": alert.type.rawValue,
            "severity": alert.severity.rawValue
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "org-alert-\(alert.id)", content: content, trigger: trigger)
        
        print("📱 Scheduling notification with identifier: org-alert-\(alert.id)")
        print("📱 Notification content: \(content.title) - \(content.body)")
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling organization alert notification: \(error)")
            } else {
                print("✅ Organization alert notification scheduled: \(alert.title)")
                print("📱 Notification will appear in 1 second")
                
                // Increment app badge for new notification
                DispatchQueue.main.async {
                    self.incrementBadge()
                }
            }
        }
    }
    
    func scheduleOrganizationAlertNotificationForFollowers(alert: OrganizationAlert, followerIds: [String]) {
        print("📱 Scheduling notifications for \(followerIds.count) followers of \(alert.organizationName)")
        
        for followerId in followerIds {
            // In a real app, you'd send this to your backend to push to specific users
            // For now, we'll just log it
            print("   📱 Would send notification to user: \(followerId)")
        }
        
        // For now, just schedule a local notification
        scheduleOrganizationAlertNotification(for: alert)
    }
    
    func getDeviceToken() -> String? {
        // In a real app, you'd get this from the app delegate
        // after registering for remote notifications
        return nil
    }
    
    // MARK: - Handle Organization Alert Notifications
    @objc private func handleOrganizationAlertPosted(_ notification: Notification) {
        print("📱 NotificationManager: Received notification: \(notification.name)")
        print("📱 NotificationManager: Object: \(notification.object ?? "nil")")
        print("📱 NotificationManager: UserInfo: \(notification.userInfo ?? [:])")
        
        guard let alert = notification.object as? OrganizationAlert else {
            print("❌ Invalid alert object in notification")
            return
        }
        
        print("📱 NotificationManager received organization alert: \(alert.title)")
        print("📱 NotificationManager: Alert details - ID: \(alert.id), Org: \(alert.organizationName), Group: \(alert.groupName ?? "None")")
        
        // Schedule the notification
        scheduleOrganizationAlertNotification(for: alert)
    }
    
    func setupNotificationCategories() {
        let incidentActions = [
            UNNotificationAction(identifier: "VIEW_DETAILS", title: "View Details", options: .foreground),
            UNNotificationAction(identifier: "REPORT_SIMILAR", title: "Report Similar", options: .foreground),
            UNNotificationAction(identifier: "GET_DIRECTIONS", title: "Get Directions", options: .foreground)
        ]
        
        let criticalActions = [
            UNNotificationAction(identifier: "ACKNOWLEDGE", title: "Acknowledge", options: .foreground),
            UNNotificationAction(identifier: "CALL_EMERGENCY", title: "Call Emergency", options: .foreground)
        ]
        
        let incidentCategory = UNNotificationCategory(identifier: "INCIDENT_ALERT", actions: incidentActions, intentIdentifiers: [], options: [])
        let criticalCategory = UNNotificationCategory(identifier: "CRITICAL_ALERT", actions: criticalActions, intentIdentifiers: [], options: [])
        
        // Organization alert categories
        let orgCriticalActions = [
            UNNotificationAction(identifier: "VIEW_ALERT", title: "View Alert", options: .foreground),
            UNNotificationAction(identifier: "VIEW_ORGANIZATION", title: "View Organization", options: .foreground),
            UNNotificationAction(identifier: "GET_DIRECTIONS", title: "Get Directions", options: .foreground)
        ]
        
        let orgHighActions = [
            UNNotificationAction(identifier: "VIEW_ALERT", title: "View Alert", options: .foreground),
            UNNotificationAction(identifier: "VIEW_ORGANIZATION", title: "View Organization", options: .foreground)
        ]
        
        let orgMediumActions = [
            UNNotificationAction(identifier: "VIEW_ALERT", title: "View Alert", options: .foreground),
            UNNotificationAction(identifier: "VIEW_ORGANIZATION", title: "View Organization", options: .foreground)
        ]
        
        let orgLowActions = [
            UNNotificationAction(identifier: "VIEW_ALERT", title: "View Alert", options: .foreground)
        ]
        
        let orgCriticalCategory = UNNotificationCategory(identifier: "ORGANIZATION_CRITICAL_ALERT", actions: orgCriticalActions, intentIdentifiers: [], options: [])
        let orgHighCategory = UNNotificationCategory(identifier: "ORGANIZATION_HIGH_ALERT", actions: orgHighActions, intentIdentifiers: [], options: [])
        let orgMediumCategory = UNNotificationCategory(identifier: "ORGANIZATION_MEDIUM_ALERT", actions: orgMediumActions, intentIdentifiers: [], options: [])
        let orgLowCategory = UNNotificationCategory(identifier: "ORGANIZATION_LOW_ALERT", actions: orgLowActions, intentIdentifiers: [], options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([
            incidentCategory, 
            criticalCategory,
            orgCriticalCategory,
            orgHighCategory,
            orgMediumCategory,
            orgLowCategory
        ])
    }
    
    func removePendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func removeDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        updateAppBadge()
    }
    
    func markNotificationAsRead() {
        // Decrement badge when user views a notification in the app
        decrementBadge()
    }
    
    // MARK: - Badge Management
    func updateAppBadge() {
        Task {
            let deliveredNotifications = await getDeliveredNotifications()
            let unreadCount = deliveredNotifications.count
            
            await MainActor.run {
                self.unreadNotificationCount = unreadCount
                UIApplication.shared.applicationIconBadgeNumber = unreadCount
                print("📱 App badge updated: \(unreadCount)")
            }
        }
    }
    
    func clearAppBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        unreadNotificationCount = 0
        print("📱 App badge cleared")
    }
    
    func incrementBadge() {
        unreadNotificationCount += 1
        UIApplication.shared.applicationIconBadgeNumber = unreadNotificationCount
        print("📱 App badge incremented to: \(unreadNotificationCount)")
    }
    
    func decrementBadge() {
        if unreadNotificationCount > 0 {
            unreadNotificationCount -= 1
            UIApplication.shared.applicationIconBadgeNumber = unreadNotificationCount
            print("📱 App badge decremented to: \(unreadNotificationCount)")
        }
    }
    
    // MARK: - Test Notification Function
    func testNotification() {
        print("🧪 Testing notification system...")
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This is a test notification to verify the system is working"
        content.sound = .default
        content.categoryIdentifier = "TEST_NOTIFICATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification failed: \(error)")
            } else {
                print("✅ Test notification scheduled successfully")
                print("🧪 Test notification will appear in 2 seconds")
            }
        }
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return await UNUserNotificationCenter.current().deliveredNotifications()
    }
    
    // MARK: - App Lifecycle Badge Management
    func handleAppDidBecomeActive() {
        // Clear badge when app becomes active (user opens the app)
        clearAppBadge()
        print("📱 App became active - badge cleared")
    }
    
    func handleAppWillResignActive() {
        // Update badge count when app goes to background
        updateAppBadge()
        print("📱 App will resign active - badge updated")
    }
    
    // MARK: - FCM Message Handling
    func handleFCMNotification(_ userInfo: [AnyHashable: Any]) {
        print("📱 Handling FCM notification: \(userInfo)")
        
        // Increment badge for new notification
        incrementBadge()
        
        // Check if this is an alert notification
        if let alertId = userInfo["alertId"] as? String {
            print("📱 Alert notification received: \(alertId)")
            // Store the alert ID to open when the app becomes active
            UserDefaults.standard.set(alertId, forKey: "pendingAlertToOpen")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        let userInfo = notification.request.content.userInfo
        
        // Handle FCM notification in foreground
        if userInfo["alertId"] != nil {
            handleFCMNotification(userInfo)
        }
        
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        print("📱 Notification tapped: \(userInfo)")
        
        // Decrement badge when notification is tapped
        decrementBadge()
        
        // Handle FCM notification tap
        if let alertId = userInfo["alertId"] as? String {
            print("📱 Alert notification tapped: \(alertId)")
            // Post notification to open the alert in the app
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenAlertFromNotification"),
                object: nil,
                userInfo: ["alertId": alertId]
            )
        }
        
        switch identifier {
        case "VIEW_DETAILS":
            // Handle view details action
            break
        case "REPORT_SIMILAR":
            // Handle report similar action
            break
        case "GET_DIRECTIONS":
            // Handle get directions action
            break
        case "ACKNOWLEDGE":
            // Handle acknowledge action
            break
        case "CALL_EMERGENCY":
            // Handle emergency call action
            break
        default:
            break
        }
        
        completionHandler()
    }
} 