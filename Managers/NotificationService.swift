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
        do {
            // Get user's FCM token from Firestore
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            guard userDoc.exists else {
                print("❌ User document does not exist: \(userId)")
                return
            }
            
            guard let userData = userDoc.data() else {
                print("❌ User document has no data: \(userId)")
                return
            }
            
            print("🔍 User data for \(userId): \(userData.keys.joined(separator: ", "))")
            
            guard let fcmToken = userData["fcmToken"] as? String, !fcmToken.isEmpty else {
                print("❌ No FCM token found for user \(userId)")
                print("   Available fields: \(userData.keys.joined(separator: ", "))")
                print("   fcmToken value: \(userData["fcmToken"] ?? "nil")")
                return
            }
            
            print("📱 Sending push notification to user \(userId) with token: \(fcmToken.prefix(20))...")
            
            // For now, just log the notification details instead of actually sending
            // This helps us debug without requiring the Vercel API endpoint
            print("📱 PUSH NOTIFICATION DETAILS:")
            print("   To: \(userId)")
            print("   Token: \(fcmToken.prefix(20))...")
            print("   Title: New Alert: \(alert.title)")
            print("   Body: \(alert.description)")
            print("   Organization: \(alert.organizationName)")
            print("   Group: \(alert.groupName ?? "None")")
            
            // TODO: Uncomment when Vercel API endpoint is ready
            /*
            try await sendFCMPushNotification(
                to: fcmToken,
                title: "New Alert: \(alert.title)",
                body: alert.description,
                data: [
                    "alertId": alert.id ?? "",
                    "organizationId": alert.organizationId,
                    "organizationName": alert.organizationName,
                    "groupName": alert.groupName ?? "",
                    "type": alert.type.rawValue,
                    "severity": alert.severity.rawValue
                ]
            )
            */
            
            print("✅ Push notification details logged for user \(userId)")
            
        } catch {
            print("❌ Failed to process push notification for user \(userId): \(error)")
        }
    }
    
    func sendFCMPushNotification(to token: String, title: String, body: String, data: [String: String]) async throws {
        // Use Vercel API to send push notifications
        let url = URL(string: "https://www.chimeo.app/api/send-push-notification")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "to": token,
            "title": title,
            "body": body,
            "data": data
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "NotificationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "NotificationError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Push notification request failed with status \(httpResponse.statusCode)"])
        }
    }
    
    // Methods for ServiceCoordinator
    func sendEmailNotification(to email: String, subject: String, body: String) async throws {
        try await sendEmailViaVercelAPI(to: email, subject: subject, text: body, html: nil)
    }
    
    func sendEmailViaVercelAPI(to email: String, subject: String, text: String, html: String? = nil, from: String = "noreply@chimeo.app") async throws {
        let vercelAPIURL = "https://www.chimeo.app/api/send-email"
        
        guard let url = URL(string: vercelAPIURL) else {
            throw NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Vercel API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let emailData: [String: Any] = [
            "to": email,
            "subject": subject,
            "text": text,
            "html": html ?? text,
            "from": from
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "NotificationService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Vercel API"])
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Email sent successfully via Vercel API to: \(email)")
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "NotificationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Vercel API error (\(httpResponse.statusCode)): \(errorMessage)"])
            }
        } catch {
            print("❌ Failed to send email via Vercel API: \(error)")
            throw error
        }
    }
    
    func sendOrganizationRequestNotification(request: OrganizationRequest) async throws {
        // For now, just log - implement notification sending later
        print("📱 Would send organization request notification for: \(request.name)")
    }
    
    func sendOrganizationApprovalNotification(organizationName: String, contactEmail: String, password: String) async throws {
        let subject = "Your Organization Has Been Approved - Chimeo"
        let text = """
        Congratulations! Your organization \(organizationName) has been approved for Chimeo.
        
        You can now access the platform and start creating alerts for your community.
        
        Next Steps:
        1. Download the Chimeo app from the App Store
        2. Sign in with your registered email: \(contactEmail)
        3. Start creating and managing alerts for your organization
        
        If you have any questions or need assistance getting started, please don't hesitate to contact our support team.
        
        Welcome to Chimeo!
        The Chimeo Team
        """
        
        let html = """
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <h2 style="color: #16a34a;">🎉 Congratulations! Your Organization Has Been Approved!</h2>
            <p>Your organization <strong>\(organizationName)</strong> has been approved for Chimeo.</p>
            
            <p>You can now access the platform and start creating alerts for your community.</p>
            
            <h3>Next Steps:</h3>
            <ol>
                <li>Download the Chimeo app from the App Store</li>
                <li>Sign in with your registered email: <strong>\(contactEmail)</strong></li>
                <li>Start creating and managing alerts for your organization</li>
            </ol>
            
            <p>If you have any questions or need assistance getting started, please don't hesitate to contact our support team.</p>
            
            <p style="margin-top: 30px; padding: 15px; background-color: #f0f9ff; border-left: 4px solid #2563eb;">
                <strong>Welcome to Chimeo!</strong><br>
                The Chimeo Team
            </p>
        </body>
        </html>
        """
        
        try await sendEmailViaVercelAPI(to: contactEmail, subject: subject, text: text, html: html)
    }
    
    func sendAlertNotificationEmail(to email: String, alert: OrganizationAlert) async throws {
        let subject = "New Alert: \(alert.title) - \(alert.organizationName)"
        
        let locationText: String
        if let location = alert.location {
            var locationParts: [String] = []
            if let address = location.address, !address.isEmpty { locationParts.append(address) }
            if let city = location.city, !city.isEmpty { locationParts.append(city) }
            if let state = location.state, !state.isEmpty { locationParts.append(state) }
            if let zipCode = location.zipCode, !zipCode.isEmpty { locationParts.append(zipCode) }
            locationText = locationParts.isEmpty ? "No specific location" : locationParts.joined(separator: ", ")
        } else {
            locationText = "No specific location"
        }
        
        let text = """
        A new alert has been posted by \(alert.organizationName):
        
        Title: \(alert.title)
        Description: \(alert.description)
        Type: \(alert.type.displayName)
        Severity: \(alert.severity.displayName)
        Location: \(locationText)
        Posted by: \(alert.postedBy)
        Posted at: \(alert.postedAt.formatted(date: .abbreviated, time: .shortened))
        
        \(alert.groupName != nil ? "Group: \(alert.groupName!)" : "")
        
        Please check the Chimeo app for more details and to manage your notification preferences.
        
        Best regards,
        The Chimeo Team
        """
        
        let html = """
        <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
            <h2 style="color: #dc2626;">🚨 New Alert: \(alert.title)</h2>
            <p><strong>Organization:</strong> \(alert.organizationName)</p>
            
            <div style="background-color: #fef2f2; border-left: 4px solid #dc2626; padding: 15px; margin: 20px 0;">
                <h3 style="margin-top: 0; color: #dc2626;">Alert Details</h3>
                <p><strong>Description:</strong> \(alert.description)</p>
                <p><strong>Type:</strong> \(alert.type.displayName)</p>
                <p><strong>Severity:</strong> \(alert.severity.displayName)</p>
                <p><strong>Location:</strong> \(locationText)</p>
                <p><strong>Posted by:</strong> \(alert.postedBy)</p>
                <p><strong>Posted at:</strong> \(alert.postedAt.formatted(date: .abbreviated, time: .shortened))</p>
                \(alert.groupName != nil ? "<p><strong>Group:</strong> \(alert.groupName!)</p>" : "")
            </div>
            
            <p>Please check the Chimeo app for more details and to manage your notification preferences.</p>
            
            <p style="margin-top: 30px; padding: 15px; background-color: #f0f9ff; border-left: 4px solid #2563eb;">
                <strong>Best regards,</strong><br>
                The Chimeo Team
            </p>
        </body>
        </html>
        """
        
        try await sendEmailViaVercelAPI(to: email, subject: subject, text: text, html: html, from: "alerts@chimeo.app")
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
