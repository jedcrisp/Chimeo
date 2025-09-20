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
        if let token = UserDefaults.standard.string(forKey: "fcm_token") {
            self.fcmToken = token
        }
    }
    
    // MARK: - FCM Token Management
    @objc private func handleFCMTokenReceived(_ notification: Notification) {
        if let token = notification.userInfo?["token"] as? String {
            DispatchQueue.main.async {
                self.fcmToken = token
                print("📱 FCM token updated in NotificationManager: \(token)")
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
                
                // Request FCM token
                self?.requestFCMToken()
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
        
        // First try to get current user from Firebase Auth
        var userId: String?
        
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Found Firebase Auth user for FCM registration: \(firebaseUser.uid)")
            userId = firebaseUser.uid
        } else if let data = UserDefaults.standard.data(forKey: "currentUser"),
                  let user = try? JSONDecoder().decode(User.self, from: data) {
            print("✅ Found UserDefaults user for FCM registration: \(user.id)")
            userId = user.id
        }
        
        guard let userId = userId else {
            print("❌ No current user found for FCM token registration")
            // Store token for later registration
            UserDefaults.standard.set(token, forKey: "pending_fcm_token")
            return
        }
        
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
    
    // MARK: - Permission Request with Completion Handler
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                self.checkAuthorizationStatus()
                completion(granted)
            }
            
            if let error = error {
                print("Notification permission error: \(error)")
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