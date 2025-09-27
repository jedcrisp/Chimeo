import Foundation
import FirebaseFirestore
import FirebaseAuth

class OrganizationUpdateNotificationService: ObservableObject {
    private let db = Firestore.firestore()
    private let notificationService = iOSNotificationService()
    
    // MARK: - Send Organization Update Notifications
    func sendOrganizationUpdateNotification(_ updateData: OrganizationUpdateData) async {
        print("📢 Sending organization update notification for: \(updateData.organizationName)")
        print("   Update type: \(updateData.updateType.displayName)")
        print("   Updated by: \(updateData.updatedByEmail)")
        
        do {
            // Get organization followers
            let followers = try await getOrganizationFollowers(organizationId: updateData.organizationId)
            print("📢 Found \(followers.count) followers to notify")
            
            // Send notifications to each follower
            for follower in followers {
                await sendUpdateNotificationToFollower(follower, updateData: updateData)
            }
            
            // Send email to platform admin
            await sendUpdateNotificationToAdmin(updateData: updateData)
            
            print("✅ Organization update notifications sent successfully")
            
        } catch {
            print("❌ Error sending organization update notifications: \(error)")
        }
    }
    
    // MARK: - Get Organization Followers
    private func getOrganizationFollowers(organizationId: String) async throws -> [User] {
        print("🔍 Getting followers for organization: \(organizationId)")
        
        // Try to get followers from the organization document first
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        
        if orgDoc.exists, let orgData = orgDoc.data() {
            let followerCount = orgData["followerCount"] as? Int ?? 0
            print("   📊 Organization follower count: \(followerCount)")
            
            // Get followers from the followers subcollection
            let followersRef = db.collection("organizations")
                .document(organizationId)
                .collection("followers")
            
            let followersSnapshot = try await followersRef.getDocuments()
            print("   📋 Found \(followersSnapshot.documents.count) follower documents")
            
            var followers: [User] = []
            
            for followerDoc in followersSnapshot.documents {
                let followerData = followerDoc.data()
                let userId = followerDoc.documentID
                
                // Get user details
                if let userDoc = try? await db.collection("users").document(userId).getDocument(),
                   userDoc.exists,
                   let userData = userDoc.data() {
                    
                    let user = User(
                        id: userId,
                        email: userData["email"] as? String,
                        name: userData["name"] as? String,
                        phone: userData["phone"] as? String,
                        profilePhotoURL: userData["profilePhotoURL"] as? String,
                        homeLocation: nil,
                        workLocation: nil,
                        schoolLocation: nil,
                        alertRadius: userData["alertRadius"] as? Double ?? 10.0,
                        preferences: UserPreferences(
                            incidentTypes: userData["incidentTypes"] as? [IncidentType] ?? [],
                            criticalAlertsOnly: userData["criticalAlertsOnly"] as? Bool ?? false,
                            pushNotifications: userData["pushNotifications"] as? Bool ?? true,
                            quietHoursEnabled: userData["quietHoursEnabled"] as? Bool ?? false,
                            quietHoursStart: (userData["quietHoursStart"] as? Timestamp)?.dateValue(),
                            quietHoursEnd: (userData["quietHoursEnd"] as? Timestamp)?.dateValue()
                        ),
                        createdAt: (userData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        isAdmin: userData["isAdmin"] as? Bool ?? false,
                        displayName: userData["displayName"] as? String,
                        isOrganizationAdmin: userData["isOrganizationAdmin"] as? Bool,
                        organizations: userData["organizations"] as? [String],
                        updatedAt: (userData["updatedAt"] as? Timestamp)?.dateValue(),
                        needsPasswordSetup: userData["needsPasswordSetup"] as? Bool,
                        needsPasswordChange: userData["needsPasswordChange"] as? Bool,
                        firebaseAuthId: userData["firebaseAuthId"] as? String
                    )
                    
                    followers.append(user)
                }
            }
            
            print("   ✅ Successfully retrieved \(followers.count) followers with user data")
            return followers
        } else {
            print("   ❌ Organization document not found")
            return []
        }
    }
    
    // MARK: - Send Update Notification to Follower
    private func sendUpdateNotificationToFollower(_ follower: User, updateData: OrganizationUpdateData) async {
        print("📱 Sending update notification to follower: \(follower.email ?? "unknown")")
        
        // Get FCM token from Firestore
        let fcmToken = await getFCMTokenForUser(follower.id)
        
        // Send push notification
        if let token = fcmToken, !token.isEmpty {
            await sendPushNotificationToFollower(follower, fcmToken: token, updateData: updateData)
        } else {
            print("   ⚠️ No FCM token for follower: \(follower.email ?? "unknown")")
        }
        
        // Send email notification
        if let email = follower.email, !email.isEmpty {
            await sendEmailNotificationToFollower(email, updateData: updateData)
        } else {
            print("   ⚠️ No email for follower: \(follower.id)")
        }
    }
    
    // MARK: - Get FCM Token for User
    private func getFCMTokenForUser(_ userId: String) async -> String? {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if userDoc.exists, let userData = userDoc.data() {
                return userData["fcmToken"] as? String
            }
        } catch {
            print("❌ Error getting FCM token for user \(userId): \(error)")
        }
        return nil
    }
    
    // MARK: - Send Push Notification to Follower
    private func sendPushNotificationToFollower(_ follower: User, fcmToken: String, updateData: OrganizationUpdateData) async {
        
        let title = "\(updateData.organizationName) Update"
        let body = getUpdateNotificationBody(updateData: updateData)
        
        let data: [String: String] = [
            "type": "organization_update",
            "organizationId": updateData.organizationId,
            "updateType": updateData.updateType.rawValue,
            "updatedBy": updateData.updatedByEmail
        ]
        
        do {
            try await notificationService.sendFCMPushNotification(
                to: fcmToken,
                title: title,
                body: body,
                data: data
            )
            print("   ✅ Push notification sent to \(follower.email ?? "unknown")")
        } catch {
            print("   ❌ Failed to send push notification to \(follower.email ?? "unknown"): \(error)")
        }
    }
    
    // MARK: - Send Email Notification to Follower
    private func sendEmailNotificationToFollower(_ email: String, updateData: OrganizationUpdateData) async {
        let subject = "\(updateData.organizationName) - \(updateData.updateType.displayName)"
        let text = getUpdateEmailText(updateData: updateData)
        let html = getUpdateEmailHTML(updateData: updateData)
        
        do {
            try await notificationService.sendEmailViaVercelAPI(
                to: email,
                subject: subject,
                text: text,
                html: html,
                from: "alerts@chimeo.app"
            )
            print("   ✅ Email notification sent to \(email)")
        } catch {
            print("   ❌ Failed to send email notification to \(email): \(error)")
        }
    }
    
    // MARK: - Send Update Notification to Admin
    private func sendUpdateNotificationToAdmin(updateData: OrganizationUpdateData) async {
        let subject = "Organization Update: \(updateData.organizationName)"
        let text = getAdminUpdateEmailText(updateData: updateData)
        let html = getAdminUpdateEmailHTML(updateData: updateData)
        
        do {
            try await notificationService.sendEmailViaVercelAPI(
                to: "jed@chimeo.app",
                subject: subject,
                text: text,
                html: html,
                from: "alerts@chimeo.app"
            )
            print("   ✅ Admin notification sent")
        } catch {
            print("   ❌ Failed to send admin notification: \(error)")
        }
    }
    
    // MARK: - Get Update Notification Body
    private func getUpdateNotificationBody(updateData: OrganizationUpdateData) -> String {
        switch updateData.updateType {
        case .profileUpdated:
            return "\(updateData.organizationName) updated their profile information"
        case .groupCreated:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                return "\(updateData.organizationName) created a new group: \(groupName)"
            }
            return "\(updateData.organizationName) created a new group"
        case .groupUpdated:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                return "\(updateData.organizationName) updated the group: \(groupName)"
            }
            return "\(updateData.organizationName) updated a group"
        case .groupDeleted:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                return "\(updateData.organizationName) deleted the group: \(groupName)"
            }
            return "\(updateData.organizationName) deleted a group"
        case .adminAdded:
            if let adminEmail = updateData.updateDetails["adminEmail"] as? String {
                return "\(updateData.organizationName) added \(adminEmail) as an admin"
            }
            return "\(updateData.organizationName) added a new admin"
        case .adminRemoved:
            if let adminEmail = updateData.updateDetails["adminEmail"] as? String {
                return "\(updateData.organizationName) removed \(adminEmail) as an admin"
            }
            return "\(updateData.organizationName) removed an admin"
        case .settingsUpdated:
            return "\(updateData.organizationName) updated their settings"
        case .subscriptionUpdated:
            return "\(updateData.organizationName) updated their subscription"
        }
    }
    
    // MARK: - Get Update Email Text
    private func getUpdateEmailText(updateData: OrganizationUpdateData) -> String {
        let organizationName = updateData.organizationName
        let updateType = updateData.updateType.displayName
        let updatedBy = updateData.updatedByEmail
        let timestamp = DateFormatter.localizedString(from: updateData.timestamp, dateStyle: .medium, timeStyle: .short)
        
        var details = ""
        switch updateData.updateType {
        case .profileUpdated:
            details = "The organization profile has been updated with new information."
        case .groupCreated:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                details = "A new group '\(groupName)' has been created."
            } else {
                details = "A new group has been created."
            }
        case .groupUpdated:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                details = "The group '\(groupName)' has been updated."
            } else {
                details = "A group has been updated."
            }
        case .groupDeleted:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                details = "The group '\(groupName)' has been deleted."
            } else {
                details = "A group has been deleted."
            }
        case .adminAdded:
            if let adminEmail = updateData.updateDetails["adminEmail"] as? String {
                details = "\(adminEmail) has been added as an administrator."
            } else {
                details = "A new administrator has been added."
            }
        case .adminRemoved:
            if let adminEmail = updateData.updateDetails["adminEmail"] as? String {
                details = "\(adminEmail) has been removed as an administrator."
            } else {
                details = "An administrator has been removed."
            }
        case .settingsUpdated:
            details = "The organization settings have been updated."
        case .subscriptionUpdated:
            details = "The organization subscription has been updated."
        }
        
        return """
        Hello,
        
        \(organizationName) has made an update to their organization.
        
        Update Details:
        • Type: \(updateType)
        • Updated by: \(updatedBy)
        • Time: \(timestamp)
        • Details: \(details)
        
        You can view the latest information in the Chimeo app.
        
        Best regards,
        The Chimeo Team
        """
    }
    
    // MARK: - Get Update Email HTML
    private func getUpdateEmailHTML(updateData: OrganizationUpdateData) -> String {
        let organizationName = updateData.organizationName
        let updateType = updateData.updateType.displayName
        let updatedBy = updateData.updatedByEmail
        let timestamp = DateFormatter.localizedString(from: updateData.timestamp, dateStyle: .medium, timeStyle: .short)
        
        var details = ""
        switch updateData.updateType {
        case .profileUpdated:
            details = "The organization profile has been updated with new information."
        case .groupCreated:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                details = "A new group '<strong>\(groupName)</strong>' has been created."
            } else {
                details = "A new group has been created."
            }
        case .groupUpdated:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                details = "The group '<strong>\(groupName)</strong>' has been updated."
            } else {
                details = "A group has been updated."
            }
        case .groupDeleted:
            if let groupName = updateData.updateDetails["groupName"] as? String {
                details = "The group '<strong>\(groupName)</strong>' has been deleted."
            } else {
                details = "A group has been deleted."
            }
        case .adminAdded:
            if let adminEmail = updateData.updateDetails["adminEmail"] as? String {
                details = "<strong>\(adminEmail)</strong> has been added as an administrator."
            } else {
                details = "A new administrator has been added."
            }
        case .adminRemoved:
            if let adminEmail = updateData.updateDetails["adminEmail"] as? String {
                details = "<strong>\(adminEmail)</strong> has been removed as an administrator."
            } else {
                details = "An administrator has been removed."
            }
        case .settingsUpdated:
            details = "The organization settings have been updated."
        case .subscriptionUpdated:
            details = "The organization subscription has been updated."
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Organization Update - \(organizationName)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center; }
                .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                .update-card { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .update-type { color: #667eea; font-weight: bold; font-size: 18px; margin-bottom: 10px; }
                .update-details { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
                .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                .button { display: inline-block; background: #667eea; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>🏢 Organization Update</h1>
                <p>\(organizationName)</p>
            </div>
            
            <div class="content">
                <div class="update-card">
                    <div class="update-type">\(updateType)</div>
                    <p>Hello,</p>
                    <p><strong>\(organizationName)</strong> has made an update to their organization.</p>
                    
                    <div class="update-details">
                        <p><strong>Update Details:</strong></p>
                        <ul>
                            <li><strong>Type:</strong> \(updateType)</li>
                            <li><strong>Updated by:</strong> \(updatedBy)</li>
                            <li><strong>Time:</strong> \(timestamp)</li>
                            <li><strong>Details:</strong> \(details)</li>
                        </ul>
                    </div>
                    
                    <p>You can view the latest information in the Chimeo app.</p>
                    
                    <a href="https://www.chimeo.app" class="button">Open Chimeo App</a>
                </div>
            </div>
            
            <div class="footer">
                <p>Best regards,<br>The Chimeo Team</p>
                <p>This is an automated notification. Please do not reply to this email.</p>
            </div>
        </body>
        </html>
        """
    }
    
    // MARK: - Get Admin Update Email Text
    private func getAdminUpdateEmailText(updateData: OrganizationUpdateData) -> String {
        let organizationName = updateData.organizationName
        let updateType = updateData.updateType.displayName
        let updatedBy = updateData.updatedByEmail
        let timestamp = DateFormatter.localizedString(from: updateData.timestamp, dateStyle: .medium, timeStyle: .short)
        
        return """
        Organization Update Notification
        
        Organization: \(organizationName)
        Update Type: \(updateType)
        Updated By: \(updatedBy)
        Time: \(timestamp)
        
        This is an automated notification that an organization has been updated.
        You can review the changes in the admin panel.
        
        Admin Panel: https://www.chimeo.app/org-requests
        """
    }
    
    // MARK: - Get Admin Update Email HTML
    private func getAdminUpdateEmailHTML(updateData: OrganizationUpdateData) -> String {
        let organizationName = updateData.organizationName
        let updateType = updateData.updateType.displayName
        let updatedBy = updateData.updatedByEmail
        let timestamp = DateFormatter.localizedString(from: updateData.timestamp, dateStyle: .medium, timeStyle: .short)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Organization Update - Admin Notification</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center; }
                .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
                .update-card { background: white; padding: 20px; border-radius: 8px; margin: 20px 0; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .update-type { color: #ff6b6b; font-weight: bold; font-size: 18px; margin-bottom: 10px; }
                .update-details { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
                .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                .button { display: inline-block; background: #ff6b6b; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>🔔 Admin Notification</h1>
                <p>Organization Update</p>
            </div>
            
            <div class="content">
                <div class="update-card">
                    <div class="update-type">\(updateType)</div>
                    <p><strong>Organization:</strong> \(organizationName)</p>
                    <p><strong>Updated By:</strong> \(updatedBy)</p>
                    <p><strong>Time:</strong> \(timestamp)</p>
                    
                    <p>This is an automated notification that an organization has been updated.</p>
                    <p>You can review the changes in the admin panel.</p>
                    
                    <a href="https://www.chimeo.app/org-requests" class="button">Open Admin Panel</a>
                </div>
            </div>
            
            <div class="footer">
                <p>Chimeo Admin System</p>
            </div>
        </body>
        </html>
        """
    }
}
