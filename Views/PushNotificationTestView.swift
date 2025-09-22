import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PushNotificationTestView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var organizations: [Organization] = []
    @State private var selectedOrganization: Organization?
    @State private var testResults = ""
    @State private var isLoading = false
    @State private var fcmToken = ""
    @State private var isFollowing = false
    @State private var followingCount = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                Text("Push Notification Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Test the complete push notification flow")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // FCM Token Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("FCM Token Status")
                        .font(.headline)
                    
                    if !fcmToken.isEmpty {
                        Text("✅ Token: \(String(fcmToken.prefix(20)))...")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("❌ No FCM token found")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Organization Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Organization")
                        .font(.headline)
                    
                    Picker("Organization", selection: $selectedOrganization) {
                        Text("Select an organization").tag(nil as Organization?)
                        ForEach(organizations, id: \.id) { org in
                            Text(org.name).tag(org as Organization?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Following Status
                if let org = selectedOrganization {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Following Status")
                            .font(.headline)
                        
                        Text(isFollowing ? "✅ Following \(org.name)" : "❌ Not following \(org.name)")
                            .font(.caption)
                            .foregroundColor(isFollowing ? .green : .red)
                        
                        Text("Followers: \(followingCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button("Check FCM Token") {
                        Task {
                            await checkFCMToken()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button("Force Refresh FCM") {
                        Task {
                            await forceRefreshFCMToken()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    
                    Button("Clear All FCM Data") {
                        Task {
                            await clearAllFCMData()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    
                    Button("Force Request APNs Permission") {
                        Task {
                            await forceRequestAPNsPermission()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    
                    Button("Delete & Refresh FCM Token") {
                        Task {
                            await deleteAndRefreshFCMToken()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    Button("Test New APNs Token") {
                        Task {
                            await testNewAPNsToken()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    
                    Button("Check Following Status") {
                        Task {
                            await checkFollowingStatus()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || selectedOrganization == nil)
                    
                    Button("Follow Organization") {
                        Task {
                            await followOrganization()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || selectedOrganization == nil || isFollowing)
                    
                    Button("Create Test Alert") {
                        Task {
                            await createTestAlert()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || selectedOrganization == nil)
                    
                    Button("Test Real Alert Posting") {
                        Task {
                            await testRealAlertPosting()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || selectedOrganization == nil)
                    
                    Button("Debug Follower Status") {
                        Task {
                            await debugFollowerStatus()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || selectedOrganization == nil)
                    
                    Button("Full Test Flow") {
                        Task {
                            await runFullTest()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || selectedOrganization == nil)
                }
                
                // Test Results
                if !testResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Results")
                            .font(.headline)
                        
                        ScrollView {
                            Text(testResults)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.black)
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 150)
                    }
                }
                
                }
                .padding()
            }
            .onAppear {
                loadOrganizations()
                Task {
                    await checkFCMToken()
                }
            }
            .onChange(of: selectedOrganization) { _, newOrg in
                if newOrg != nil {
                    Task {
                        await checkFollowingStatus()
                    }
                }
            }
        }
    }
    
    private func loadOrganizations() {
        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("organizations").getDocuments()
                
                await MainActor.run {
                    organizations = snapshot.documents.compactMap { doc in
                        let data = doc.data()
                        let name = data["name"] as? String ?? "Unknown"
                        let description = data["description"] as? String ?? ""
                        let type = data["type"] as? String ?? "other"
                        let verified = data["verified"] as? Bool ?? false
                        let followerCount = data["followerCount"] as? Int ?? 0
                        let logoURL = data["logoURL"] as? String
                        let website = data["website"] as? String
                        let phone = data["phone"] as? String
                        let email = data["email"] as? String
                        let adminIds = data["adminIds"] as? [String: Bool]
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                        let address = data["address"] as? String ?? ""
                        let city = data["city"] as? String ?? ""
                        let state = data["state"] as? String ?? ""
                        let zipCode = data["zipCode"] as? String ?? ""
                        
                        let location = Location(
                            latitude: data["latitude"] as? Double ?? 0.0,
                            longitude: data["longitude"] as? Double ?? 0.0,
                            address: address,
                            city: city,
                            state: state,
                            zipCode: zipCode
                        )
                        
                        return Organization(
                            id: doc.documentID,
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
                            groups: nil,
                            adminIds: adminIds,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            address: address,
                            city: city,
                            state: state,
                            zipCode: zipCode
                        )
                    }
                }
            } catch {
                print("❌ Error loading organizations: \(error)")
            }
        }
    }
    
    private func checkFCMToken() async {
        let token = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        await MainActor.run {
            fcmToken = token
            testResults += "🔍 FCM Token Check:\n"
            if !token.isEmpty {
                testResults += "✅ FCM Token found: \(String(token.prefix(20)))...\n\n"
            } else {
                testResults += "❌ No FCM token found\n"
                testResults += "   Try: Settings > Refresh FCM Token\n\n"
            }
        }
    }
    
    private func forceRefreshFCMToken() async {
        testResults += "🔄 Force Refreshing FCM Token:\n"
        
        // Clear old token
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        
        // Force re-register for push notifications
        notificationManager.registerForPushNotifications()
        
        // Wait a moment for token to be generated
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Check for new token
        let newToken = UserDefaults.standard.string(forKey: "fcm_token")
        
        await MainActor.run {
            fcmToken = newToken ?? ""
            if let token = newToken, !token.isEmpty {
                testResults += "✅ New FCM Token received: \(String(token.prefix(20)))...\n"
                testResults += "   Token length: \(token.count) characters\n\n"
            } else {
                testResults += "❌ No new FCM token received\n"
                testResults += "   This may take a few moments or require app restart\n\n"
            }
        }
    }
    
    private func clearAllFCMData() async {
        testResults += "🧹 Clearing ALL FCM Data:\n"
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        UserDefaults.standard.removeObject(forKey: "fcmToken")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
        UserDefaults.standard.removeObject(forKey: "fcmTokenReceived")
        UserDefaults.standard.removeObject(forKey: "lastTokenUpdate")
        UserDefaults.standard.removeObject(forKey: "tokenStatus")
        
        testResults += "✅ Cleared UserDefaults FCM data\n"
        
        // Clear from Firestore
        if let currentUser = Auth.auth().currentUser {
            do {
                let db = Firestore.firestore()
                try await db.collection("users").document(currentUser.uid).updateData([
                    "fcmToken": FieldValue.delete(),
                    "lastTokenUpdate": FieldValue.delete(),
                    "platform": FieldValue.delete(),
                    "appVersion": FieldValue.delete(),
                    "tokenStatus": FieldValue.delete()
                ])
                testResults += "✅ Cleared Firestore FCM data\n"
            } catch {
                testResults += "❌ Error clearing Firestore: \(error.localizedDescription)\n"
            }
        } else {
            testResults += "⚠️ No authenticated user - skipping Firestore clear\n"
        }
        
        // Clear from NotificationManager
        notificationManager.fcmToken = nil
        
        // Clear local state
        await MainActor.run {
            fcmToken = ""
            testResults += "✅ Cleared local FCM state\n"
            testResults += "🎉 ALL FCM data cleared! Restart app for clean state.\n\n"
        }
    }
    
    private func forceRequestAPNsPermission() async {
        testResults += "🔔 Force Requesting APNs Permission:\n"
        
        let granted = await notificationManager.forceRequestAPNsPermission()
        
        await MainActor.run {
            if granted {
                testResults += "✅ APNs permission granted!\n"
                testResults += "   App registered for remote notifications\n"
                testResults += "   FCM token should be generated shortly\n\n"
            } else {
                testResults += "❌ APNs permission denied\n"
                testResults += "   Go to Settings > Notifications to enable\n"
                testResults += "   Then try again\n\n"
            }
        }
    }
    
    private func deleteAndRefreshFCMToken() async {
        testResults += "🔄 Deleting Old FCM Token & Getting New One:\n"
        
        let newToken = await notificationManager.deleteAndRefreshFCMToken()
        
        await MainActor.run {
            if let token = newToken, !token.isEmpty {
                fcmToken = token
                testResults += "✅ Old FCM token deleted successfully\n"
                testResults += "✅ New FCM token received: \(String(token.prefix(20)))...\n"
                testResults += "✅ Token registered in Firestore\n"
                testResults += "   Token length: \(token.count) characters\n\n"
            } else {
                testResults += "❌ Failed to get new FCM token\n"
                testResults += "   Make sure APNs permission is granted\n"
                testResults += "   Try 'Force Request APNs Permission' first\n\n"
            }
        }
    }
    
    private func testNewAPNsToken() async {
        testResults += "🧪 Testing Current FCM Token:\n"
        
        let currentToken = "ecN_kKLuDUOzgIrvhPE3hg:APA91bHkdC0utiszVyRyeVN_MMqUbygX5N__KG2BwwK_eZ-Cfq15ayXyXbapVFzxNdFi2-Mhtyvcm5TsqCBzVOz0kM5Z5roMfZnWH64F0rfP3RWRNdMyF6U"
        
        await MainActor.run {
            fcmToken = currentToken
            testResults += "✅ Using current FCM token: \(String(currentToken.prefix(20)))...\n"
            testResults += "   Token length: \(currentToken.count) characters\n"
        }
        
        // Register this token in Firestore
        if let currentUser = Auth.auth().currentUser {
            do {
                let db = Firestore.firestore()
                try await db.collection("users").document(currentUser.uid).updateData([
                    "fcmToken": currentToken,
                    "lastTokenUpdate": FieldValue.serverTimestamp(),
                    "platform": "ios",
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "tokenStatus": "active"
                ])
                
                await MainActor.run {
                    testResults += "✅ Token registered in Firestore\n"
                    testResults += "✅ Ready for push notifications!\n"
                    testResults += "   This token should work with your new APNs\n\n"
                }
            } catch {
                await MainActor.run {
                    testResults += "❌ Error registering token in Firestore: \(error.localizedDescription)\n\n"
                }
            }
        }
    }
    
    private func checkFollowingStatus() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        do {
            let db = Firestore.firestore()
            let followerDoc = try await db.collection("users")
                .document(currentUser.uid)
                .collection("followedOrganizations")
                .document(org.id)
                .getDocument()
            
            let isFollowingOrg = followerDoc.exists
            let followerCount = org.followerCount
            
            await MainActor.run {
                isFollowing = isFollowingOrg
                followingCount = followerCount
                testResults += "🔍 Following Status Check:\n"
                testResults += isFollowingOrg ? "✅ Following \(org.name)\n" : "❌ Not following \(org.name)\n"
                testResults += "📊 Organization has \(followerCount) followers\n\n"
            }
        } catch {
            await MainActor.run {
                testResults += "❌ Error checking following status: \(error)\n\n"
            }
        }
    }
    
    private func followOrganization() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        
        do {
            let db = Firestore.firestore()
            
            // Add to user's followed organizations
            try await db.collection("users")
                .document(currentUser.uid)
                .collection("followedOrganizations")
                .document(org.id)
                .setData([
                    "organizationId": org.id,
                    "organizationName": org.name,
                    "followedAt": FieldValue.serverTimestamp(),
                    "groupPreferences": [:] // Default: no groups enabled
                ])
            
            // Add to organization's followers
            try await db.collection("organizations")
                .document(org.id)
                .collection("followers")
                .document(currentUser.uid)
                .setData([
                    "userId": currentUser.uid,
                    "userName": currentUser.displayName ?? "Unknown User",
                    "followedAt": FieldValue.serverTimestamp(),
                    "fcmToken": fcmToken
                ])
            
            // Update organization follower count
            try await db.collection("organizations")
                .document(org.id)
                .updateData([
                    "followerCount": FieldValue.increment(Int64(1))
                ])
            
            await MainActor.run {
                isFollowing = true
                followingCount += 1
                testResults += "✅ Successfully followed \(org.name)\n"
                testResults += "   Added to user's followed organizations\n"
                testResults += "   Added to organization's followers\n"
                testResults += "   Updated follower count\n\n"
            }
        } catch {
            await MainActor.run {
                testResults += "❌ Error following organization: \(error)\n\n"
            }
        }
        
        isLoading = false
    }
    
    private func createTestAlert() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        testResults += "🚨 Creating Test Alert:\n"
        
        do {
            let db = Firestore.firestore()
            
            // First, ensure the user's FCM token is registered in Firestore
            if !fcmToken.isEmpty {
                testResults += "📱 Registering FCM token in Firestore...\n"
                try await db.collection("users").document(currentUser.uid).updateData([
                    "fcmToken": fcmToken,
                    "lastTokenUpdate": FieldValue.serverTimestamp(),
                    "platform": "ios",
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                    "tokenStatus": "active"
                ])
                testResults += "✅ FCM token registered in Firestore\n"
            } else {
                testResults += "⚠️ No FCM token available - notifications may not work\n"
            }
            
            let testAlert: [String: Any] = [
                "title": "🧪 Test Push Notification",
                "description": "This is a test alert to verify push notifications are working correctly",
                "organizationId": org.id,
                "organizationName": org.name,
                "groupId": "",
                "groupName": "",
                "type": "test",
                "severity": "medium",
                "location": [
                    "latitude": org.location.latitude,
                    "longitude": org.location.longitude,
                    "address": org.location.address,
                    "city": org.location.city,
                    "state": org.location.state,
                    "zipCode": org.location.zipCode
                ],
                "postedBy": currentUser.displayName ?? "Test User",
                "postedByUserId": currentUser.uid,
                "postedAt": FieldValue.serverTimestamp(),
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            let alertRef = try await db.collection("organizations")
                .document(org.id)
                .collection("alerts")
                .addDocument(data: testAlert)
            
            await MainActor.run {
                testResults += "✅ Test alert created successfully!\n"
                testResults += "   Alert ID: \(alertRef.documentID)\n"
                testResults += "   This should trigger Firebase function: sendAlertNotifications\n"
                testResults += "   Check Firebase Functions logs for delivery status\n\n"
            }
        } catch {
            await MainActor.run {
                testResults += "❌ Error creating test alert: \(error)\n\n"
            }
        }
        
        isLoading = false
    }
    
    private func testRealAlertPosting() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        testResults += "🚨 Testing Real Alert Posting Process:\n"
        
        do {
            // Use the same process as the real alert posting
            let alert = OrganizationAlert(
                title: "Real Alert Test - Push Notifications",
                description: "This is a real alert test using the same process as posting alerts from the app",
                organizationId: org.id,
                organizationName: org.name,
                groupId: nil,
                groupName: nil,
                type: .other,
                severity: .medium,
                location: org.location,
                postedBy: currentUser.displayName ?? "Test User",
                postedByUserId: currentUser.uid,
                postedAt: Date()
            )
            
            testResults += "📝 Created OrganizationAlert object\n"
            testResults += "   Title: \(alert.title)\n"
            testResults += "   Organization: \(alert.organizationName)\n"
            testResults += "   Posted By: \(alert.postedBy)\n"
            testResults += "   Posted By User ID: \(alert.postedByUserId)\n"
            
            // Post using ServiceCoordinator (same as real app)
            try await serviceCoordinator.postOrganizationAlert(alert)
            
            await MainActor.run {
                testResults += "✅ Real alert posted successfully!\n"
                testResults += "   This used the same process as the real app\n"
                testResults += "   Should trigger Firebase function: sendAlertNotifications\n"
                testResults += "   Note: You won't get a notification because you're the creator\n"
                testResults += "   Other followers should receive notifications\n\n"
            }
        } catch {
            await MainActor.run {
                testResults += "❌ Error posting real alert: \(error)\n\n"
            }
        }
        
        isLoading = false
    }
    
    private func debugFollowerStatus() async {
        guard let org = selectedOrganization else {
            return
        }
        
        isLoading = true
        testResults += "🔍 Debugging Follower Status:\n"
        testResults += "   Organization: \(org.name)\n"
        testResults += "   Organization ID: \(org.id)\n\n"
        
        do {
            let db = Firestore.firestore()
            
            // Check organization followers
            testResults += "📋 Checking organization followers...\n"
            let followersSnapshot = try await db.collection("organizations")
                .document(org.id)
                .collection("followers")
                .getDocuments()
            
            testResults += "   Found \(followersSnapshot.documents.count) followers\n"
            
            for (index, doc) in followersSnapshot.documents.enumerated() {
                let data = doc.data()
                let userId = doc.documentID
                let alertsEnabled = data["alertsEnabled"] as? Bool ?? true
                
                // Fetch actual user data from users collection
                let userDoc = try await db.collection("users").document(userId).getDocument()
                let userName: String
                let fcmToken: String?
                
                if userDoc.exists, let userData = userDoc.data() {
                    userName = userData["name"] as? String ?? userData["displayName"] as? String ?? "Unknown"
                    fcmToken = userData["fcmToken"] as? String
                } else {
                    userName = "Unknown (User not found)"
                    fcmToken = nil
                }
                
                testResults += "   Follower \(index + 1):\n"
                testResults += "     User ID: \(userId)\n"
                testResults += "     User Name: \(userName)\n"
                testResults += "     FCM Token: \(fcmToken != nil ? "Present (\(String(fcmToken!.prefix(20)))...)" : "Missing")\n"
                testResults += "     Alerts Enabled: \(alertsEnabled)\n\n"
            }
            
            // Check if current user is following
            if let currentUser = Auth.auth().currentUser {
                testResults += "👤 Checking current user following status...\n"
                let userFollowingDoc = try await db.collection("users")
                    .document(currentUser.uid)
                    .collection("followedOrganizations")
                    .document(org.id)
                    .getDocument()
                
                if userFollowingDoc.exists {
                    let data = userFollowingDoc.data() ?? [:]
                    let groupPreferences = data["groupPreferences"] as? [String: Bool] ?? [:]
                    
                    testResults += "   ✅ Current user is following this organization\n"
                    testResults += "   Group Preferences: \(groupPreferences)\n"
                } else {
                    testResults += "   ❌ Current user is NOT following this organization\n"
                }
            }
            
        } catch {
            testResults += "❌ Error debugging follower status: \(error)\n"
        }
        
        isLoading = false
    }
    
    private func runFullTest() async {
        testResults = "🧪 Running Full Push Notification Test\n"
        testResults += "=====================================\n\n"
        
        // Step 1: Check FCM Token
        await checkFCMToken()
        
        // Step 2: Check Following Status
        await checkFollowingStatus()
        
        // Step 3: Follow if not following
        if !isFollowing {
            testResults += "⚠️ Not following organization, following now...\n"
            await followOrganization()
        }
        
        // Step 4: Register missing FCM tokens
        testResults += "📱 Registering missing FCM tokens...\n"
        await registerMissingFCMTokens()
        
        // Step 5: Create test alert
        testResults += "🚨 Creating test alert to trigger notifications...\n"
        await createTestAlert()
        
        testResults += "🎉 Full test completed!\n"
        testResults += "   Check your device for push notifications\n"
        testResults += "   Check Firebase Functions logs for delivery status\n"
    }
    
    private func registerMissingFCMTokens() async {
        guard let org = selectedOrganization else {
            testResults += "   ❌ No organization selected\n"
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // Get current user's FCM token
            let currentFCMToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
            if currentFCMToken.isEmpty {
                testResults += "   ⚠️ No FCM token available for current user\n"
                return
            }
            
            // Get organization followers
            let followersSnapshot = try await db.collection("organizations")
                .document(org.id)
                .collection("followers")
                .getDocuments()
            
            testResults += "   Found \(followersSnapshot.documents.count) followers to check\n"
            
            var tokensRegistered = 0
            var tokensAlreadyPresent = 0
            var errors = 0
            
            for doc in followersSnapshot.documents {
                let userId = doc.documentID
                
                // Check if user has FCM token
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if userDoc.exists, let userData = userDoc.data() {
                    let existingToken = userData["fcmToken"] as? String ?? ""
                    
                    if existingToken.isEmpty {
                        // Register FCM token for this user
                        try await db.collection("users").document(userId).updateData([
                            "fcmToken": currentFCMToken,
                            "lastTokenUpdate": FieldValue.serverTimestamp(),
                            "platform": "ios",
                            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                            "tokenStatus": "active"
                        ])
                        tokensRegistered += 1
                        testResults += "   ✅ Registered FCM token for user: \(userId)\n"
                    } else {
                        tokensAlreadyPresent += 1
                        testResults += "   ℹ️ User \(userId) already has FCM token\n"
                    }
                } else {
                    errors += 1
                    testResults += "   ❌ User document not found: \(userId)\n"
                }
            }
            
            testResults += "   📊 Summary: \(tokensRegistered) registered, \(tokensAlreadyPresent) already present, \(errors) errors\n"
            
        } catch {
            testResults += "   ❌ Error registering FCM tokens: \(error)\n"
        }
    }
}

#Preview {
    PushNotificationTestView()
        .environmentObject(APIService())
        .environmentObject(ServiceCoordinator(simpleAuthManager: SimpleAuthManager()))
        .environmentObject(NotificationManager())
}
