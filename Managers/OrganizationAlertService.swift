import Foundation
import FirebaseFirestore
import FirebaseStorage

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
            "postedAt": FieldValue.serverTimestamp(),
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "expiresAt": Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        ]
        
        // Add to organization's alerts subcollection
        let alertRef = Firestore.firestore().collection("organizations")
            .document(alert.organizationId)
            .collection("alerts")
            .document()
        
        try await alertRef.setData(alertData)
        
        print("✅ Organization alert posted successfully")
        print("   📍 Location: organizations/\(alert.organizationId)/alerts/\(alertRef.documentID)")
        
        // Update organization alert count
        try await Firestore.firestore().collection("organizations").document(alert.organizationId).updateData([
            "alertCount": FieldValue.increment(Int64(1))
        ])
        
        // Send notifications to followers
        await sendNotificationsToFollowers(for: alert)
    }
    
    // MARK: - Send Notifications to Followers
    private func sendNotificationsToFollowers(for alert: OrganizationAlert) async {
        print("🚨🚨🚨 ABOUT TO SEND NOTIFICATIONS TO FOLLOWERS 🚨🚨🚨")
        print("📱 Alert: \(alert.title)")
        print("   Organization: \(alert.organizationName)")
        print("   Group: \(alert.groupName ?? "None")")
        print("   🚫 Alert creator ID: \(alert.postedByUserId)")
        
        do {
            // Get current user to exclude them from notifications
            let currentUser = try await getCurrentUser()
            print("   🚫 Current user ID: \(currentUser.id)")
            print("   🚫 Excluding alert creator from notifications: \(currentUser.id == alert.postedByUserId)")
            
            // Get organization followers
            let orgDoc = try await Firestore.firestore().collection("organizations").document(alert.organizationId).getDocument()
            
            guard let orgData = orgDoc.data(),
                  let followerIds = orgData["followers"] as? [String: Bool] else {
                print("❌ No followers found for organization: \(alert.organizationId)")
                return
            }
            
            let activeFollowers = followerIds.compactMap { $0.value ? $0.key : nil }
            print("📋 Found \(activeFollowers.count) active followers")
            
            // Filter out the alert creator
            let followersExcludingCreator = activeFollowers.filter { $0 != alert.postedByUserId }
            print("🚫 Excluded alert creator - \(followersExcludingCreator.count) followers remaining")
            
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
            
            // Send notifications to eligible followers using FCM
            print("📱 SENDING NOTIFICATIONS TO \(eligibleFollowers.count) ELIGIBLE FOLLOWERS:")
            for followerId in eligibleFollowers {
                print("   📱 Sending to follower: \(followerId)")
                await notificationService.sendNotificationToUser(userId: followerId, alert: alert)
            }
            
            print("✅ FCM notifications sent to \(eligibleFollowers.count) eligible followers")
            print("🚨🚨🚨 NOTIFICATION FUNCTION COMPLETED 🚨🚨🚨")
        
        } catch {
            print("❌ Error sending notifications to followers: \(error)")
            print("🚨🚨🚨 NOTIFICATION FUNCTION FAILED 🚨🚨��")
        }
    }

// MARK: - Helper Functions
private func getCurrentUser() async throws -> User {
    // Get current user from UserDefaults (stored by AuthenticationService)
    guard let data = UserDefaults.standard.data(forKey: "currentUser"),
          let user = try? JSONDecoder().decode(User.self, from: data) else {
        print("❌ No current user found in UserDefaults")
        throw NSError(domain: "UserNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "Current user not found"])
    }
    
    print("✅ Current user found: \(user.name ?? "Unknown") (ID: \(user.id))")
    return user
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
            imageURLs: []
        )
    }
    
}
