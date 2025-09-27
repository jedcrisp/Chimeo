import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

// MARK: - Organization Alert Service
class OrganizationAlertService: ObservableObject {
    
    private let notificationService: iOSNotificationService
    
    init(notificationService: iOSNotificationService = iOSNotificationService()) {
        self.notificationService = notificationService
    }
    
    // MARK: - Alert Management
    func postOrganizationAlert(_ alert: OrganizationAlert) async throws {
        print("🚨 Posting organization alert: \(alert.title)")
        print("   Organization: \(alert.organizationName)")
        print("   Group: \(alert.groupName ?? "None")")
        print("   Type: \(alert.type.displayName)")
        print("   Severity: \(alert.severity.displayName)")
        
        // Create alert data
        let alertData: [String: Any] = [
            "title": alert.title,
            "description": alert.description,
            "organizationId": alert.organizationId,
            "organizationName": alert.organizationName,
            "groupId": alert.groupId ?? "",
            "groupName": alert.groupName ?? "",
            "type": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": [
                "latitude": alert.location?.latitude ?? 0.0,
                "longitude": alert.location?.longitude ?? 0.0,
                "address": alert.location?.address ?? "",
                "city": alert.location?.city ?? "",
                "state": alert.location?.state ?? "",
                "zipCode": alert.location?.zipCode ?? ""
            ],
            "postedBy": alert.postedBy,
            "postedByUserId": alert.postedByUserId,
            "postedAt": alert.postedAt,
            "scheduledAlertId": alert.scheduledAlertId as Any,
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "expiresAt": Calendar.current.date(byAdding: .day, value: 14, to: alert.postedAt) ?? alert.postedAt
        ]
        
        // Add to organization's alerts subcollection
        let alertRef = Firestore.firestore().collection("organizations")
            .document(alert.organizationId)
            .collection("alerts")
            .document()
        
        try await alertRef.setData(alertData)
        
        print("✅ Organization alert posted successfully")
        print("   📍 Location: organizations/\(alert.organizationId)/alerts/\(alertRef.documentID)")
        print("   🔥 This should trigger Firebase function: sendAlertNotifications")
        print("   📊 Alert data: \(alertData)")
        
        // Update organization alert count
        try await Firestore.firestore().collection("organizations").document(alert.organizationId).updateData([
            "alertCount": FieldValue.increment(Int64(1))
        ])
        
        print("📊 Organization alert count updated")
        
        // Send notifications to followers
        print("📱 About to call sendNotificationsToFollowers...")
        print("🔥 NOTE: Firebase Cloud Function should also trigger automatically!")
        print("🔥 Check Firebase Functions logs for: sendAlertNotifications")
        await sendNotificationsToFollowers(for: alert)
        print("📱 sendNotificationsToFollowers completed")
    }
    
    // MARK: - Test Alert Creation
    func createTestAlert(organizationId: String, organizationName: String) async throws {
        print("🧪 Creating test alert for debugging...")
        
        let testAlert = OrganizationAlert(
            id: UUID().uuidString,
            title: "Test Alert - Debug Push Notifications",
            description: "This is a test alert to verify push notifications are working correctly.",
            organizationId: organizationId,
            organizationName: organizationName,
            groupId: nil,
            groupName: nil,
            type: .other,
            severity: .medium,
            location: nil,
            postedBy: "Test User",
            postedByUserId: "test-user-id",
            postedAt: Date()
        )
        
        try await postOrganizationAlert(testAlert)
        print("🧪 Test alert created successfully")
    }
    
    // MARK: - Test Notification System
    func testNotificationSystem() async {
        print("🧪 Testing notification system with existing alert...")
        
        // Create a test alert object
        let testAlert = OrganizationAlert(
            id: "test-alert-id",
            title: "Test Push Notification",
            description: "Testing if push notifications work for followers",
            organizationId: "velocity_physical_therapy_north_denton",
            organizationName: "Velocity Physical Therapy North Denton",
            groupId: "Road Closures",
            groupName: "Road Closures",
            type: .other,
            severity: .medium,
            location: nil,
            postedBy: "Test User",
            postedByUserId: "test-user-id",
            postedAt: Date()
        )
        
        // Test the notification system directly
        await sendNotificationsToFollowers(for: testAlert)
        print("🧪 Notification system test completed")
    }
    
    // MARK: - Test Firebase Cloud Function
    func testFirebaseCloudFunction() async throws {
        print("🔥 Testing Firebase Cloud Function...")
        
        // Create a real alert that should trigger the Firebase Cloud Function
        let testAlert = OrganizationAlert(
            id: UUID().uuidString,
            title: "Firebase Cloud Function Test",
            description: "This alert should trigger the Firebase Cloud Function automatically",
            organizationId: "velocity_physical_therapy_north_denton",
            organizationName: "Velocity Physical Therapy North Denton",
            groupId: "Road Closures",
            groupName: "Road Closures",
            type: .other,
            severity: .medium,
            location: nil,
            postedBy: "Test User",
            postedByUserId: "test-user-id",
            postedAt: Date()
        )
        
        print("🔥 Creating alert that should trigger Firebase Cloud Function...")
        print("🔥 Check Firebase Functions logs for: sendAlertNotifications")
        
        // This should trigger the Firebase Cloud Function automatically
        try await postOrganizationAlert(testAlert)
        
        print("🔥 Alert created - Firebase Cloud Function should have triggered!")
        print("🔥 Check Firebase Console > Functions > Logs for sendAlertNotifications")
    }
    
    // MARK: - Send Notifications to Followers
    private func sendNotificationsToFollowers(for alert: OrganizationAlert) async {
        print("🚨🚨🚨 iOS APP NOTIFICATION SYSTEM TRIGGERED 🚨🚨🚨")
        print("📱 Alert: \(alert.title)")
        print("   Organization: \(alert.organizationName)")
        print("   Group: \(alert.groupName ?? "None")")
        print("   🚫 Alert creator ID: \(alert.postedByUserId)")
        
        do {
            // Get organization followers
            print("🔍 Looking up organization: \(alert.organizationId)")
            let orgDoc = try await Firestore.firestore().collection("organizations").document(alert.organizationId).getDocument()
            
            if !orgDoc.exists {
                print("❌ Organization document does not exist: \(alert.organizationId)")
                
                // Try to find the organization by name as a fallback
                print("🔍 Attempting to find organization by name: \(alert.organizationName)")
                let orgsQuery = try await Firestore.firestore().collection("organizations")
                    .whereField("name", isEqualTo: alert.organizationName)
                    .getDocuments()
                
                if let matchingOrg = orgsQuery.documents.first {
                    let actualOrgId = matchingOrg.documentID
                    print("✅ Found organization by name with ID: \(actualOrgId)")
                    print("   Original ID: \(alert.organizationId)")
                    print("   Actual ID: \(actualOrgId)")
                    
                    // Use the actual organization document
                    let actualOrgData = matchingOrg.data()
                    // Try to get followers from the actual organization document first
                    var activeFollowers: [String] = []
                    
                    print("🔍 Actual organization data keys: \(actualOrgData.keys.sorted())")
                    print("🔍 Follower count from actual org data: \(actualOrgData["followerCount"] ?? "nil")")
                    
                    if let followerIds = actualOrgData["followers"] as? [String: Bool] {
                        activeFollowers = followerIds.compactMap { $0.value ? $0.key : nil }
                        print("📋 Found \(activeFollowers.count) active followers in actual organization document")
                        print("📋 Follower IDs: \(activeFollowers)")
                    } else {
                        print("⚠️ No followers field in actual organization document, checking subcollection...")
                        print("🔍 Available fields: \(actualOrgData.keys.sorted())")
                        
                        // Try to get followers from the subcollection
                        let followersSnapshot = try await Firestore.firestore()
                            .collection("organizations")
                            .document(actualOrgId)
                            .collection("followers")
                            .getDocuments()
                        
                        print("🔍 Subcollection query returned \(followersSnapshot.documents.count) documents")
                        
                        activeFollowers = followersSnapshot.documents.compactMap { doc in
                            let data = doc.data()
                            print("🔍 Follower doc \(doc.documentID): \(data)")
                            if let isActive = data["isActive"] as? Bool, isActive {
                                return doc.documentID
                            }
                            return nil
                        }
                        print("📋 Found \(activeFollowers.count) active followers in actual organization subcollection")
                        print("📋 Active follower IDs: \(activeFollowers)")
                    }
                    
                    if activeFollowers.isEmpty {
                        print("❌ No followers found in actual organization: \(actualOrgId)")
                        return
                    }
                    
                    // Filter out the alert creator (if we have a valid postedByUserId)
                    let followersExcludingCreator: [String]
                    if alert.postedByUserId != "unknown" && !alert.postedByUserId.isEmpty {
                        followersExcludingCreator = activeFollowers.filter { $0 != alert.postedByUserId }
                        print("🚫 Excluded alert creator (\(alert.postedByUserId)) - \(followersExcludingCreator.count) followers remaining")
                    } else {
                        followersExcludingCreator = activeFollowers
                        print("⚠️ Alert creator ID is unknown, not excluding anyone - \(followersExcludingCreator.count) followers")
                    }
                    
                    // Filter followers by group preferences if alert has a specific group
                    let eligibleFollowers: [String]
                    if alert.groupId != nil {
                        eligibleFollowers = try await notificationService.filterFollowersByGroupPreferences(
                            followers: followersExcludingCreator, 
                            alert: alert
                        )
                        print("✅ Filtered down to \(eligibleFollowers.count) eligible followers for group: \(alert.groupName ?? "Unknown")")
                    } else {
                        eligibleFollowers = followersExcludingCreator
                        print("✅ Alert has no specific group - all \(followersExcludingCreator.count) followers are eligible")
                    }
                    
                    // Send notifications to eligible followers using FCM and email
                    print("📱 SENDING NOTIFICATIONS TO \(eligibleFollowers.count) ELIGIBLE FOLLOWERS:")
                    for followerId in eligibleFollowers {
                        print("   📱 Sending to follower: \(followerId)")
                        
                        // Send push notification
                        await notificationService.sendNotificationToUser(userId: followerId, alert: alert)
                        
                        // Send email notification
                        do {
                            let followerEmail = try await getFollowerEmail(userId: followerId)
                            try await notificationService.sendAlertNotificationEmail(to: followerEmail, alert: alert)
                            print("   📧 Email sent to: \(followerEmail)")
                        } catch {
                            print("   ❌ Failed to send email to follower \(followerId): \(error)")
                        }
                    }
                    
                    print("✅ FCM and email notifications sent to \(eligibleFollowers.count) eligible followers")
                    print("🚨🚨🚨 NOTIFICATION FUNCTION COMPLETED 🚨🚨🚨")
                    return
                } else {
                    print("❌ No organization found with name: \(alert.organizationName)")
                    return
                }
            }
            
            guard let orgData = orgDoc.data() else {
                print("❌ No organization data found for: \(alert.organizationId)")
                return
            }
            
            // Try to get followers from the organization document first
            var activeFollowers: [String] = []
            
            print("🔍 Organization data keys: \(orgData.keys.sorted())")
            print("🔍 Follower count from org data: \(orgData["followerCount"] ?? "nil")")
            
            if let followerIds = orgData["followers"] as? [String: Bool] {
                activeFollowers = followerIds.compactMap { $0.value ? $0.key : nil }
                print("📋 Found \(activeFollowers.count) active followers in organization document")
                print("📋 Follower IDs: \(activeFollowers)")
            } else {
                print("⚠️ No followers field in organization document, checking subcollection...")
                print("🔍 Available fields: \(orgData.keys.sorted())")
                
                // Try to get followers from the subcollection
                let followersSnapshot = try await Firestore.firestore()
                    .collection("organizations")
                    .document(alert.organizationId)
                    .collection("followers")
                    .getDocuments()
                
                print("🔍 Subcollection query returned \(followersSnapshot.documents.count) documents")
                
                activeFollowers = followersSnapshot.documents.compactMap { doc in
                    let data = doc.data()
                    print("🔍 Follower doc \(doc.documentID): \(data)")
                    if let isActive = data["isActive"] as? Bool, isActive {
                        return doc.documentID
                    }
                    return nil
                }
                print("📋 Found \(activeFollowers.count) active followers in subcollection")
                print("📋 Active follower IDs: \(activeFollowers)")
            }
            
            if activeFollowers.isEmpty {
                print("❌ No followers found for organization: \(alert.organizationId)")
                print("   Organization data: \(orgData)")
                return
            }
            
            // Filter out the alert creator (if we have a valid postedByUserId)
            let followersExcludingCreator: [String]
            if alert.postedByUserId != "unknown" && !alert.postedByUserId.isEmpty {
                followersExcludingCreator = activeFollowers.filter { $0 != alert.postedByUserId }
                print("🚫 Excluded alert creator (\(alert.postedByUserId)) - \(followersExcludingCreator.count) followers remaining")
            } else {
                followersExcludingCreator = activeFollowers
                print("⚠️ Alert creator ID is unknown, not excluding anyone - \(followersExcludingCreator.count) followers")
            }
            
            // Filter followers by group preferences if alert has a specific group
            let eligibleFollowers: [String]
            if alert.groupId != nil {
                eligibleFollowers = try await notificationService.filterFollowersByGroupPreferences(
                    followers: followersExcludingCreator, 
                    alert: alert
                )
                print("✅ Filtered down to \(eligibleFollowers.count) eligible followers for group: \(alert.groupName ?? "Unknown")")
            } else {
                eligibleFollowers = followersExcludingCreator
                print("✅ Alert has no specific group - all \(followersExcludingCreator.count) followers are eligible")
            }
            
            // Send notifications to eligible followers using FCM and email
            print("📱 SENDING NOTIFICATIONS TO \(eligibleFollowers.count) ELIGIBLE FOLLOWERS:")
            print("   🔍 Follower IDs: \(eligibleFollowers)")
            
            for followerId in eligibleFollowers {
                print("   📱 Processing follower: \(followerId)")
                
                // Send push notification
                print("   📱 Sending push notification to: \(followerId)")
                await notificationService.sendNotificationToUser(userId: followerId, alert: alert)
                
                // Send email notification
                do {
                    let followerEmail = try await getFollowerEmail(userId: followerId)
                    print("   📧 Sending email to: \(followerEmail)")
                    try await notificationService.sendAlertNotificationEmail(to: followerEmail, alert: alert)
                    print("   ✅ Email sent successfully to: \(followerEmail)")
                } catch {
                    print("   ❌ Failed to send email to follower \(followerId): \(error)")
                }
            }
            
            print("🎉 NOTIFICATION PROCESSING COMPLETE")
            
            print("✅ FCM and email notifications sent to \(eligibleFollowers.count) eligible followers")
            print("🚨🚨🚨 NOTIFICATION FUNCTION COMPLETED 🚨🚨🚨")
        
        } catch {
            print("❌ Error sending notifications to followers: \(error)")
            print("🚨🚨🚨 NOTIFICATION FUNCTION FAILED 🚨🚨��")
        }
    }

// MARK: - Helper Functions
private func getFollowerEmail(userId: String) async throws -> String {
    let db = Firestore.firestore()
    let userDoc = try await db.collection("users").document(userId).getDocument()
    
    guard let userData = userDoc.data(),
          let email = userData["email"] as? String else {
        throw NSError(domain: "OrganizationAlertService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User email not found"])
    }
    
    return email
}

private func getCurrentUser() async throws -> User {
    // First try to get current user from Firebase Auth
    if let firebaseUser = Auth.auth().currentUser {
        print("✅ Found Firebase Auth user: \(firebaseUser.uid)")
        
        // Try to get user data from Firestore
        let db = Firestore.firestore()
        do {
            let userDoc = try await db.collection("users").document(firebaseUser.uid).getDocument()
            
            if userDoc.exists, let userData = userDoc.data() {
                let user = User(
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
                
                print("✅ Current user found from Firestore: \(user.name ?? "Unknown") (ID: \(user.id))")
                return user
            } else {
                print("⚠️ Firebase user exists but no Firestore document found")
            }
        } catch {
            print("⚠️ Error getting user from Firestore: \(error)")
        }
    }
    
    // Fallback: Try to get current user from UserDefaults (stored by AuthenticationService)
    if let data = UserDefaults.standard.data(forKey: "currentUser"),
       let user = try? JSONDecoder().decode(User.self, from: data) {
        print("✅ Current user found from UserDefaults: \(user.name ?? "Unknown") (ID: \(user.id))")
        return user
    }
    
    // Additional fallback: Try to get user ID from UserDefaults and fetch from Firestore
    if let userId = UserDefaults.standard.string(forKey: "currentUserId"), !userId.isEmpty {
        print("🔍 Found user ID in UserDefaults, fetching user from Firestore: \(userId)")
        let db = Firestore.firestore()
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if userDoc.exists, let userData = userDoc.data() {
                let user = User(
                    id: userId,
                    email: userData["email"] as? String ?? "unknown@example.com",
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
                    displayName: userData["customDisplayName"] as? String ?? userData["name"] as? String ?? "User",
                    isOrganizationAdmin: userData["isOrganizationAdmin"] as? Bool,
                    organizations: userData["organizations"] as? [String],
                    updatedAt: (userData["updatedAt"] as? Timestamp)?.dateValue(),
                    needsPasswordSetup: userData["needsPasswordSetup"] as? Bool,
                    needsPasswordChange: userData["needsPasswordChange"] as? Bool,
                    firebaseAuthId: userId
                )
                print("✅ Current user found from UserDefaults + Firestore: \(user.name ?? "Unknown") (ID: \(user.id))")
                return user
            }
        } catch {
            print("⚠️ Error fetching user from Firestore with UserDefaults ID: \(error)")
        }
    }
    
    print("❌ No current user found in Firebase Auth or UserDefaults")
    throw NSError(domain: "UserNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "Current user not found"])
}
    
    func updateOrganizationAlert(_ alert: OrganizationAlert) async throws {
        print("✏️ Updating organization alert: \(alert.title)")
        
        let updateData: [String: Any] = [
            "title": alert.title,
            "description": alert.description,
            "type": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": [
                "latitude": alert.location?.latitude ?? 0.0,
                "longitude": alert.location?.longitude ?? 0.0,
                "address": alert.location?.address ?? "",
                "city": alert.location?.city ?? "",
                "state": alert.location?.state ?? "",
                "zipCode": alert.location?.zipCode ?? ""
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Update in organization's alerts subcollection
        let alertRef = Firestore.firestore().collection("organizations")
            .document(alert.organizationId)
            .collection("alerts")
            .document(alert.id)
        
        try await alertRef.updateData(updateData)
        
        print("✅ Organization alert updated successfully")
    }
    
    func deleteOrganizationAlert(_ alertId: String, organizationId: String) async throws {
        print("🗑️ Deleting organization alert: \(alertId)")
        
        // Delete from organization's alerts subcollection
        let alertRef = Firestore.firestore().collection("organizations")
            .document(organizationId)
            .collection("alerts")
            .document(alertId)
        
        try await alertRef.delete()
        
        // Update organization alert count
        try await Firestore.firestore().collection("organizations").document(organizationId).updateData([
            "alertCount": FieldValue.increment(Int64(-1))
        ])
        
        print("✅ Organization alert deleted successfully")
    }
    
    // MARK: - Alert Fetching
    func getOrganizationAlerts(organizationId: String) async throws -> [OrganizationAlert] {
        print("🔍 Fetching alerts for organization: \(organizationId)")
        
        let alertsRef = Firestore.firestore().collection("organizations")
            .document(organizationId)
            .collection("alerts")
        
        let snapshot = try await alertsRef.getDocuments()
        
        var alerts: [OrganizationAlert] = []
        
        for document in snapshot.documents {
            do {
                let data = document.data()
                let alert = try parseOrganizationAlert(data: data, id: document.documentID)
                alerts.append(alert)
            } catch {
                print("⚠️ Warning: Could not parse alert document \(document.documentID): \(error)")
            }
        }
        
        print("✅ Found \(alerts.count) alerts for organization \(organizationId)")
        return alerts
    }
    
    func getFollowingOrganizationAlerts() async throws -> [OrganizationAlert] {
        print("🔍 Fetching alerts from followed organizations")
        
        var allAlerts: [OrganizationAlert] = []
        
        // Get current user's followed organizations
        guard let currentUser = try? await getCurrentUser() else {
            print("❌ No current user found")
            return []
        }
        
        // For now, we'll need to get this from APIService
        // This is a placeholder - you'll need to inject APIService here
        print("⚠️ TODO: Get followed organizations from APIService")
        
        // For demonstration, we'll return empty array
        // In the real implementation, this would:
        // 1. Get user's followed organizations
        // 2. Query each organization's alerts subcollection
        // 3. Combine and sort all alerts
        // 4. Return the combined list
        
        print("✅ Found \(allAlerts.count) alerts from followed organizations")
        return allAlerts
    }
    
    // MARK: - Fix Existing Alerts
    func fixExistingAlertTimestamps() async throws {
        print("🔧 Fixing existing alert timestamps...")
        
        let db = Firestore.firestore()
        
        // Get all organizations
        let orgsSnapshot = try await db.collection("organizations").getDocuments()
        
        for orgDoc in orgsSnapshot.documents {
            let orgId = orgDoc.documentID
            print("🔧 Checking organization: \(orgId)")
            
            // Get all alerts for this organization
            let alertsRef = db.collection("organizations")
                .document(orgId)
                .collection("alerts")
            
            let alertsSnapshot = try await alertsRef.getDocuments()
            
            for alertDoc in alertsSnapshot.documents {
                let data = alertDoc.data()
                
                // Check if this alert has a scheduledAlertId (meaning it came from a scheduled alert)
                if let scheduledAlertId = data["scheduledAlertId"] as? String {
                    print("🔧 Found scheduled alert: \(alertDoc.documentID) -> \(scheduledAlertId)")
                    
                    // Get the original scheduled alert to get the correct scheduled date
                    let scheduledAlertRef = db.collection("organizations")
                        .document(orgId)
                        .collection("scheduledAlerts")
                        .document(scheduledAlertId)
                    
                    do {
                        let scheduledAlertDoc = try await scheduledAlertRef.getDocument()
                        if let scheduledData = scheduledAlertDoc.data(),
                           let scheduledDate = scheduledData["scheduledDate"] as? Timestamp {
                            
                            // Update the alert with the correct postedAt timestamp
                            try await alertDoc.reference.updateData([
                                "postedAt": scheduledDate
                            ])
                            
                            print("✅ Fixed timestamp for alert \(alertDoc.documentID)")
                        }
                    } catch {
                        print("❌ Error fixing alert \(alertDoc.documentID): \(error)")
                    }
                }
            }
        }
        
        print("✅ Finished fixing alert timestamps")
    }
    
    // MARK: - Alert Parsing
    private func parseOrganizationAlert(data: [String: Any], id: String) throws -> OrganizationAlert {
        let title = data["title"] as? String ?? "Unknown"
        let description = data["description"] as? String ?? ""
        let organizationId = data["organizationId"] as? String ?? ""
        let organizationName = data["organizationName"] as? String ?? "Unknown"
        let groupId = data["groupId"] as? String
        let groupName = data["groupName"] as? String
        let typeString = data["type"] as? String ?? "other"
        let severityString = data["severity"] as? String ?? "low"
        let locationData = data["location"] as? [String: Any] ?? [:]
        let postedBy = data["postedBy"] as? String ?? "Unknown"
        let postedByUserId = data["postedByUserId"] as? String ?? ""
        let isActive = data["isActive"] as? Bool ?? true
        let postedAt = (data["postedAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Debug logging for timestamp parsing
        print("🕐 Parsing alert '\(title)' timestamps:")
        if let postedAtTimestamp = data["postedAt"] as? Timestamp {
            print("   📅 postedAt from Firestore: \(postedAtTimestamp.dateValue())")
        } else {
            print("   ⚠️ postedAt not found or not a Timestamp")
        }
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            print("   📅 createdAt from Firestore: \(createdAtTimestamp.dateValue())")
        } else {
            print("   ⚠️ createdAt not found or not a Timestamp")
        }
        print("   📅 Final postedAt used: \(postedAt)")
        print("   📅 Current time: \(Date())")
        print("   📅 Time difference: \(Date().timeIntervalSince(postedAt)) seconds")
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        let location = Location(
            latitude: locationData["latitude"] as? Double ?? 0.0,
            longitude: locationData["longitude"] as? Double ?? 0.0,
            address: locationData["address"] as? String ?? "",
            city: locationData["city"] as? String ?? "",
            state: locationData["state"] as? String ?? "",
            zipCode: locationData["zipCode"] as? String ?? ""
        )
        
        let type = IncidentType(rawValue: typeString) ?? .other
        let severity = IncidentSeverity(rawValue: severityString) ?? .low
        let imageURLs = data["imageURLs"] as? [String] ?? []
        let scheduledAlertId = data["scheduledAlertId"] as? String
        
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
            imageURLs: imageURLs,
            scheduledAlertId: scheduledAlertId
        )
    }
    
}
