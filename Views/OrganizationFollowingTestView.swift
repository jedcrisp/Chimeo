import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct OrganizationFollowingTestView: View {
    @State private var testResults = ""
    @State private var isLoading = false
    @State private var organizations: [Organization] = []
    @State private var selectedOrganization: Organization?
    @State private var isFollowing = false
    @State private var followerCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("👥 Organization Following Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if isLoading {
                    ProgressView("Testing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Organization Selection
                            if !organizations.isEmpty {
                                GroupBox("Select Organization") {
                                    Picker("Organization", selection: $selectedOrganization) {
                                        Text("Select an organization").tag(nil as Organization?)
                                        ForEach(organizations) { org in
                                            Text(org.name).tag(org as Organization?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            
                            // Organization Status
                            if let org = selectedOrganization {
                                GroupBox("Organization Status") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Name: \(org.name)")
                                        Text("ID: \(org.id)")
                                        Text("Follower Count: \(followerCount)")
                                        Text("Following: \(isFollowing ? "Yes" : "No")")
                                            .foregroundColor(isFollowing ? .green : .red)
                                    }
                                }
                            }
                            
                            // Test Actions
                            GroupBox("Test Actions") {
                                VStack(spacing: 12) {
                                    Button("Check Following Status") {
                                        Task {
                                            await checkFollowingStatus()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(selectedOrganization == nil)
                                    
                                    Button("Follow Organization") {
                                        Task {
                                            await followOrganization()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(selectedOrganization == nil || isFollowing)
                                    
                                    Button("Unfollow Organization") {
                                        Task {
                                            await unfollowOrganization()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(selectedOrganization == nil || !isFollowing)
                                    
                                    Button("Test Push Notification") {
                                        Task {
                                            await testPushNotification()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(selectedOrganization == nil)
                                }
                            }
                            
                            // Test Results
                            GroupBox("Test Results") {
                                ScrollView {
                                    Text(testResults)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 300)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Following Test")
            .onAppear {
                loadOrganizations()
            }
            .onChange(of: selectedOrganization) { _, org in
                if let org = org {
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
                
                let orgs = snapshot.documents.compactMap { doc -> Organization? in
                    let data = doc.data()
                    let name = data["name"] as? String ?? "Unknown"
                    let type = data["type"] as? String ?? "business"
                    let description = data["description"] as? String ?? ""
                    let verified = data["verified"] as? Bool ?? false
                    let followerCount = data["followerCount"] as? Int ?? 0
                    let logoURL = data["logoURL"] as? String
                    let website = data["website"] as? String
                    let phone = data["phone"] as? String
                    let email = data["email"] as? String
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Create location from flat address fields
                    let address = data["address"] as? String
                    let city = data["city"] as? String
                    let state = data["state"] as? String
                    let zipCode = data["zipCode"] as? String
                    
                    let location = Location(
                        latitude: 33.1032, // Default coordinates
                        longitude: -96.6705,
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
                        adminIds: nil,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        address: address,
                        city: city,
                        state: state,
                        zipCode: zipCode
                    )
                }
                
                await MainActor.run {
                    self.organizations = orgs
                }
            } catch {
                print("Error loading organizations: \(error)")
            }
        }
    }
    
    private func checkFollowingStatus() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        testResults = "🔍 Checking Following Status\n"
        testResults += "==========================\n\n"
        
        do {
            let db = Firestore.firestore()
            
            // Check if user is following this organization
            let userOrgRef = db.collection("users")
                .document(currentUser.uid)
                .collection("followedOrganizations")
                .document(org.id)
            
            let userOrgDoc = try await userOrgRef.getDocument()
            
            if userOrgDoc.exists {
                let data = userOrgDoc.data() ?? [:]
                let isFollowingOrg = data["isFollowing"] as? Bool ?? false
                
                testResults += "✅ User following document found\n"
                testResults += "   Following: \(isFollowingOrg)\n"
                testResults += "   Followed at: \(data["followedAt"] as? Timestamp)\n\n"
                
                await MainActor.run {
                    self.isFollowing = isFollowingOrg
                }
            } else {
                testResults += "❌ User following document not found\n\n"
                await MainActor.run {
                    self.isFollowing = false
                }
            }
            
            // Check organization's followers subcollection
            let orgFollowersRef = db.collection("organizations")
                .document(org.id)
                .collection("followers")
                .document(currentUser.uid)
            
            let orgFollowersDoc = try await orgFollowersRef.getDocument()
            
            if orgFollowersDoc.exists {
                testResults += "✅ Organization followers document found\n"
                testResults += "   User ID: \(orgFollowersDoc.documentID)\n"
                testResults += "   Followed at: \(orgFollowersDoc.data()?["followedAt"] as? Timestamp)\n\n"
            } else {
                testResults += "❌ Organization followers document not found\n\n"
            }
            
            // Check organization's follower count
            let orgDoc = try await db.collection("organizations").document(org.id).getDocument()
            if let orgData = orgDoc.data() {
                let followerCount = orgData["followerCount"] as? Int ?? 0
                testResults += "📊 Organization follower count: \(followerCount)\n\n"
                
                await MainActor.run {
                    self.followerCount = followerCount
                }
            }
            
            // Check user's followedOrganizations array
            let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
            if let userData = userDoc.data() {
                let followedOrgs = userData["followedOrganizations"] as? [String] ?? []
                testResults += "👤 User's followed organizations array:\n"
                for orgId in followedOrgs {
                    testResults += "   - \(orgId)\n"
                }
                testResults += "\n"
            }
            
        } catch {
            testResults += "❌ Error checking following status: \(error)\n\n"
        }
        
        isLoading = false
    }
    
    private func followOrganization() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        testResults = "👥 Following Organization\n"
        testResults += "========================\n\n"
        
        do {
            let db = Firestore.firestore()
            let batch = db.batch()
            
            // Add to user's followed organizations array
            let userRef = db.collection("users").document(currentUser.uid)
            batch.updateData([
                "followedOrganizations": FieldValue.arrayUnion([org.id]),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: userRef)
            
            // Create user's organization following document
            let userOrgRef = db.collection("users").document(currentUser.uid)
                .collection("followedOrganizations").document(org.id)
            batch.setData([
                "organizationId": org.id,
                "isFollowing": true,
                "followedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: userOrgRef, merge: true)
            
            // Add to organization's followers subcollection
            let orgFollowersRef = db.collection("organizations").document(org.id)
                .collection("followers").document(currentUser.uid)
            batch.setData([
                "userId": currentUser.uid,
                "followedAt": FieldValue.serverTimestamp(),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: orgFollowersRef)
            
            // Update organization's follower count
            let orgRef = db.collection("organizations").document(org.id)
            let orgDoc = try await orgRef.getDocument()
            
            if let orgData = orgDoc.data(), let currentCount = orgData["followerCount"] as? Int {
                let newCount = currentCount + 1
                batch.updateData([
                    "followerCount": newCount,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: orgRef)
                testResults += "📊 Updated follower count from \(currentCount) to \(newCount)\n"
            } else {
                batch.updateData([
                    "followerCount": 1,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: orgRef)
                testResults += "📊 Set initial follower count to 1\n"
            }
            
            try await batch.commit()
            
            testResults += "✅ Successfully followed organization: \(org.name)\n"
            testResults += "   User ID: \(currentUser.uid)\n"
            testResults += "   Organization ID: \(org.id)\n\n"
            
            // Refresh status
            await checkFollowingStatus()
            
        } catch {
            testResults += "❌ Error following organization: \(error)\n\n"
        }
        
        isLoading = false
    }
    
    private func unfollowOrganization() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        testResults = "👥 Unfollowing Organization\n"
        testResults += "==========================\n\n"
        
        do {
            let db = Firestore.firestore()
            let batch = db.batch()
            
            // Remove from user's followed organizations array
            let userRef = db.collection("users").document(currentUser.uid)
            batch.updateData([
                "followedOrganizations": FieldValue.arrayRemove([org.id]),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: userRef)
            
            // Remove user's organization following document
            let userOrgRef = db.collection("users").document(currentUser.uid)
                .collection("followedOrganizations").document(org.id)
            batch.deleteDocument(userOrgRef)
            
            // Remove from organization's followers subcollection
            let orgFollowersRef = db.collection("organizations").document(org.id)
                .collection("followers").document(currentUser.uid)
            batch.deleteDocument(orgFollowersRef)
            
            // Update organization's follower count
            let orgRef = db.collection("organizations").document(org.id)
            let orgDoc = try await orgRef.getDocument()
            
            if let orgData = orgDoc.data(), let currentCount = orgData["followerCount"] as? Int {
                let newCount = max(0, currentCount - 1)
                batch.updateData([
                    "followerCount": newCount,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: orgRef)
                testResults += "📊 Updated follower count from \(currentCount) to \(newCount)\n"
            }
            
            try await batch.commit()
            
            testResults += "✅ Successfully unfollowed organization: \(org.name)\n\n"
            
            // Refresh status
            await checkFollowingStatus()
            
        } catch {
            testResults += "❌ Error unfollowing organization: \(error)\n\n"
        }
        
        isLoading = false
    }
    
    private func testPushNotification() async {
        guard let org = selectedOrganization,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        testResults = "🚨 Testing Push Notification\n"
        testResults += "===========================\n\n"
        
        do {
            // First, ensure the user is following the organization
            if !isFollowing {
                testResults += "⚠️ User not following organization, following first...\n"
                await followOrganization()
                testResults += "✅ Now following organization\n\n"
            }
            
            // Check FCM token status
            testResults += "🔍 Checking FCM token status...\n"
            let fcmToken = UserDefaults.standard.string(forKey: "fcm_token")
            if let token = fcmToken, !token.isEmpty {
                testResults += "✅ FCM token found: \(String(token.prefix(20)))...\n"
            } else {
                testResults += "❌ No FCM token found - notifications may not work\n"
                testResults += "   Make sure you've granted notification permissions\n\n"
            }
            
            let db = Firestore.firestore()
            
            // Create a test alert
            let testAlert: [String: Any] = [
                "title": "🧪 Test Push Notification",
                "description": "This is a test alert to verify push notifications are working",
                "organizationId": org.id,
                "organizationName": org.name,
                "type": "test",
                "severity": "medium",
                "postedBy": currentUser.displayName ?? "Test User",
                "postedByUserId": currentUser.uid,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            let alertRef = try await db.collection("organizations")
                .document(org.id)
                .collection("alerts")
                .addDocument(data: testAlert)
            
            testResults += "✅ Test alert created with ID: \(alertRef.documentID)\n"
            testResults += "   This should trigger Firebase function to send notifications\n"
            testResults += "   Check Firebase Functions logs for delivery status\n\n"
            
            // Also create a test notification document for debugging
            let testNotificationData: [String: Any] = [
                "title": "🧪 Test Push Notification",
                "body": "This is a test notification to verify push notifications are working",
                "userId": currentUser.uid,
                "fcmToken": fcmToken ?? "none",
                "timestamp": FieldValue.serverTimestamp(),
                "type": "test",
                "data": [
                    "test": "true",
                    "timestamp": Date().timeIntervalSince1970
                ]
            ]
            
            try await db.collection("testNotifications").addDocument(data: testNotificationData)
            testResults += "✅ Test notification document created in Firestore\n"
            testResults += "   Check the 'testNotifications' collection in Firestore\n\n"
            
        } catch {
            testResults += "❌ Error creating test alert: \(error)\n\n"
        }
        
        isLoading = false
    }
}

#Preview {
    OrganizationFollowingTestView()
}
