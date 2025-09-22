import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NotificationDebugView: View {
    @StateObject private var notificationManager = NotificationManager()
    @State private var debugInfo = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🔍 Notification Debug")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // FCM Token Status
                        GroupBox("FCM Token Status") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Token: \(notificationManager.fcmToken?.prefix(20) ?? "None")...")
                                Text("Authorized: \(notificationManager.isAuthorized ? "Yes" : "No")")
                                Text("Status: \(notificationManager.authorizationStatus.rawValue)")
                            }
                        }
                        
                        // Debug Actions
                        GroupBox("Debug Actions") {
                            VStack(spacing: 12) {
                                Button("Test Local Notification") {
                                    notificationManager.testLocalNotification()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Debug FCM Status") {
                                    notificationManager.debugFCMTokenStatus()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Test Notification System") {
                                    notificationManager.testNotificationSystem()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Check Following Status") {
                                    Task {
                                        await notificationManager.checkFollowingStatus()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        // Debug Info
                        GroupBox("Debug Information") {
                            ScrollView {
                                Text(debugInfo)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 200)
                        }
                        
                        // Refresh Button
                        Button("Refresh Debug Info") {
                            refreshDebugInfo()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                    }
                    .padding()
                }
            }
            .navigationTitle("Debug")
            .onAppear {
                refreshDebugInfo()
            }
        }
    }
    
    private func refreshDebugInfo() {
        isLoading = true
        
        Task {
            var info = "🔍 NOTIFICATION DEBUG INFO\n"
            info += "========================\n\n"
            
            // FCM Token Info
            info += "📱 FCM TOKEN:\n"
            info += "  Current: \(notificationManager.fcmToken ?? "None")\n"
            info += "  Stored: \(UserDefaults.standard.string(forKey: "fcm_token") ?? "None")\n"
            info += "  Pending: \(UserDefaults.standard.string(forKey: "pending_fcm_token") ?? "None")\n\n"
            
            // Authorization Info
            info += "🔔 AUTHORIZATION:\n"
            info += "  Authorized: \(notificationManager.isAuthorized)\n"
            info += "  Status: \(notificationManager.authorizationStatus.rawValue)\n\n"
            
            // User Info
            if let user = Auth.auth().currentUser {
                info += "👤 USER:\n"
                info += "  ID: \(user.uid)\n"
                info += "  Email: \(user.email ?? "None")\n\n"
                
                // Check Firestore user document
                do {
                    let db = Firestore.firestore()
                    let userDoc = try await db.collection("users").document(user.uid).getDocument()
                    
                    if userDoc.exists {
                        let userData = userDoc.data() ?? [:]
                        let fcmToken = userData["fcmToken"] as? String
                        let platform = userData["platform"] as? String ?? "unknown"
                        let tokenStatus = userData["tokenStatus"] as? String ?? "unknown"
                        
                        info += "📊 FIRESTORE USER DATA:\n"
                        info += "  FCM Token: \(fcmToken != nil ? "Present" : "Missing")\n"
                        info += "  Platform: \(platform)\n"
                        info += "  Token Status: \(tokenStatus)\n\n"
                        
                        // Check followed organizations
                        let followedOrgsSnapshot = try await db.collection("users")
                            .document(user.uid)
                            .collection("followedOrganizations")
                            .getDocuments()
                        
                        info += "👥 FOLLOWED ORGANIZATIONS:\n"
                        info += "  Count: \(followedOrgsSnapshot.documents.count)\n"
                        
                        for doc in followedOrgsSnapshot.documents {
                            let data = doc.data()
                            let orgId = doc.documentID
                            let isFollowing = data["isFollowing"] as? Bool ?? false
                            let alertsEnabled = data["alertsEnabled"] as? Bool ?? true
                            
                            info += "  - \(orgId): Following=\(isFollowing), Alerts=\(alertsEnabled)\n"
                            
                            if let groupPreferences = data["groupPreferences"] as? [String: Bool] {
                                info += "    Groups: \(groupPreferences)\n"
                            }
                        }
                        info += "\n"
                        
                    } else {
                        info += "❌ User document not found in Firestore\n\n"
                    }
                } catch {
                    info += "❌ Error checking Firestore: \(error)\n\n"
                }
            } else {
                info += "❌ No authenticated user\n\n"
            }
            
            // Notification Settings
            info += "⚙️ NOTIFICATION SETTINGS:\n"
            info += "  Push Enabled: \(UserDefaults.standard.bool(forKey: "pushNotificationsEnabled"))\n"
            info += "  Critical Alerts: \(UserDefaults.standard.bool(forKey: "criticalAlertsEnabled"))\n"
            info += "  Unread Count: \(notificationManager.unreadNotificationCount)\n\n"
            
            // Recent Notifications
            let deliveredNotifications = await notificationManager.getDeliveredNotifications()
            info += "📬 RECENT NOTIFICATIONS:\n"
            info += "  Delivered: \(deliveredNotifications.count)\n"
            
            for (index, notification) in deliveredNotifications.prefix(5).enumerated() {
                let content = notification.request.content
                info += "  \(index + 1). \(content.title): \(content.body)\n"
            }
            
            await MainActor.run {
                self.debugInfo = info
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NotificationDebugView()
}
