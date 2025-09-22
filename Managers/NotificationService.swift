import Foundation
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import Combine
import SwiftUI

class iOSNotificationService: ObservableObject {
    @Published var isConnected = false
    @Published var lastNotification: PushNotification?
    @Published var notificationHistory: [PushNotification] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    
    init() {
        setupNotificationHandling()
        loadNotificationHistory()
    }
    
    // MARK: - FCM Token Management
    func registerFCMToken(_ token: String) async -> Bool {
        do {
            // Get current user ID
            guard let userId = getCurrentUserId() else {
                print("❌ No current user ID found for FCM registration")
                return false
            }
            
            // Update token in Firestore
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            
            try await db.collection("users").document(userId).updateData([
                "fcmToken": token,
                "lastTokenUpdate": FieldValue.serverTimestamp(),
                "platform": "ios",
                "appVersion": appVersion,
                "tokenStatus": "active"
            ])
            
            print("✅ FCM token registered successfully for user: \(userId)")
            return true
            
        } catch {
            print("❌ Failed to register FCM token: \(error)")
            return false
        }
    }
    
    func unregisterFCMToken() async -> Bool {
        do {
            guard let userId = getCurrentUserId() else {
                print("❌ No current user ID found for FCM unregistration")
                return false
            }
            
            // Remove token from Firestore
            try await db.collection("users").document(userId).updateData([
                "fcmToken": FieldValue.delete(),
                "iosToken": FieldValue.delete(),
                "tokenStatus": "unregistered",
                "lastTokenUpdate": FieldValue.serverTimestamp()
            ])
            
            print("✅ FCM token unregistered successfully for user: \(userId)")
            return true
            
        } catch {
            print("❌ Failed to unregister FCM token: \(error)")
            return false
        }
    }
    
    func validateFCMToken(_ token: String) async -> Bool {
        do {
            guard let userId = getCurrentUserId() else {
                print("❌ No current user ID found for FCM validation")
                return false
            }
            
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data()
                let storedToken = userData?["fcmToken"] as? String
                let isValid = storedToken == token && storedToken != nil && storedToken!.count > 100
                
                print("🔍 FCM token validation: \(isValid ? "VALID" : "INVALID")")
                return isValid
            } else {
                print("❌ User document not found for FCM validation")
                return false
            }
            
        } catch {
            print("❌ Error validating FCM token: \(error)")
            return false
        }
    }
    
    // MARK: - Notification Handling
    private func setupNotificationHandling() {
        // Listen for FCM token updates
        NotificationCenter.default.publisher(for: .fcmTokenReceived)
            .sink { [weak self] notification in
                if let token = notification.userInfo?["token"] as? String {
                    Task {
                        await self?.registerFCMToken(token)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for push notifications
        NotificationCenter.default.publisher(for: .pushNotificationReceived)
            .sink { [weak self] notification in
                if let pushNotification = notification.object as? PushNotification {
                    DispatchQueue.main.async {
                        self?.lastNotification = pushNotification
                        self?.addToHistory(pushNotification)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification History
    private func loadNotificationHistory() {
        // Load from UserDefaults for now
        if let data = UserDefaults.standard.data(forKey: "notificationHistory"),
           let history = try? JSONDecoder().decode([PushNotification].self, from: data) {
            DispatchQueue.main.async {
                self.notificationHistory = history
            }
        }
    }
    
    private func addToHistory(_ notification: PushNotification) {
        notificationHistory.insert(notification, at: 0)
        
        // Keep only last 100 notifications
        if notificationHistory.count > 100 {
            notificationHistory = Array(notificationHistory.prefix(100))
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(notificationHistory) {
            UserDefaults.standard.set(data, forKey: "notificationHistory")
        }
    }
    
    func clearNotificationHistory() {
        notificationHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "notificationHistory")
    }
    
    // MARK: - Utility Methods
    private func getCurrentUserId() -> String? {
        // Only return user ID if Firebase Auth has a current user
        // This ensures FCM tokens are only registered for authenticated users
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Found Firebase Auth user for FCM: \(firebaseUser.uid)")
            return firebaseUser.uid
        }
        
        // If no Firebase Auth user, don't register FCM tokens
        // This prevents registering tokens for stale/unauthenticated users
        print("❌ No Firebase Auth user found - skipping FCM token registration")
        return nil
    }
    
    // MARK: - Test Methods
    func sendTestNotification() {
        let testNotification = PushNotification(
            id: UUID().uuidString,
            title: "🧪 Test Notification",
            body: "This is a test notification from the iOS app",
            data: ["test": "true", "timestamp": Date().timeIntervalSince1970],
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.lastNotification = testNotification
            self.addToHistory(testNotification)
        }
        
        // Post notification for other components
        NotificationCenter.default.post(
            name: .pushNotificationReceived,
            object: testNotification
        )
    }
    
    // MARK: - Additional Methods for Other Services
    
    // Method for OrganizationAlertService
    func filterFollowersByGroupPreferences(followers: [String], alert: OrganizationAlert) async throws -> [String] {
        // For now, return all followers - implement group preference filtering later
        return followers
    }
    
    func sendNotificationToUser(userId: String, alert: OrganizationAlert) async {
        // For now, just log - implement actual notification sending later
        print("📱 Would send notification to user \(userId) for alert: \(alert.title)")
    }
    
    // Methods for ServiceCoordinator
    func sendEmailNotification(to email: String, subject: String, body: String) async throws {
        // For now, just log - implement email sending later
        print("📧 Would send email to \(email): \(subject)")
    }
    
    func sendOrganizationRequestNotification(request: OrganizationRequest) async throws {
        // For now, just log - implement notification sending later
        print("📱 Would send organization request notification for: \(request.name)")
    }
    
    func sendOrganizationApprovalNotification(organizationName: String, contactEmail: String, password: String) async throws {
        // For now, just log - implement notification sending later
        print("📱 Would send organization approval notification for: \(organizationName)")
    }
    
    func sendPushNotification(title: String, body: String, userId: String, data: [String: Any]) async throws {
        // For now, just log - implement push notification sending later
        print("📱 Would send push notification to user \(userId): \(title)")
    }
    
    // Methods for SettingsView
    func debugGlobalFCMTokens() async -> [String: Any] {
        // For now, return empty status - implement debugging later
        return ["status": "not implemented", "error": "Debug method not yet implemented"]
    }
    
    func checkForDuplicateFCMTokens() async -> [String: Any] {
        // For now, return empty status - implement duplicate checking later
        return ["status": "not implemented", "error": "Duplicate check method not yet implemented"]
    }
    
    func cleanUpDuplicateFCMTokens() async -> [String: Any] {
        // For now, return empty status - implement cleanup later
        return ["status": "not implemented", "error": "Cleanup method not yet implemented"]
    }
}

// MARK: - Push Notification Model
struct PushNotification: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let data: [String: Any]
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, body, timestamp
    }
    
    init(id: String, title: String, body: String, data: [String: Any], timestamp: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.data = data
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        data = [:] // Initialize empty data for decoded notifications
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(timestamp, forKey: .timestamp)
        // Note: data is not encoded as it's not Codable
    }
}
