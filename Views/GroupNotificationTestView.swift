import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupNotificationTestView: View {
    @State private var testResults = ""
    @State private var isLoading = false
    @State private var selectedOrganization: Organization?
    @State private var organizations: [Organization] = []
    @State private var groups: [OrganizationGroup] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🧪 Group Notification Test")
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
                            
                            // Groups for Selected Organization
                            if let org = selectedOrganization, !groups.isEmpty {
                                GroupBox("Groups in \(org.name)") {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(groups) { group in
                                            HStack {
                                                Text(group.name)
                                                Spacer()
                                                Text("\(group.memberCount) members")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Test Actions
                            GroupBox("Test Actions") {
                                VStack(spacing: 12) {
                                    Button("Run Full Test") {
                                        Task {
                                            await runFullTest()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(selectedOrganization == nil)
                                    
                                    Button("Test Group Alert") {
                                        Task {
                                            await testGroupAlert()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(selectedOrganization == nil || groups.isEmpty)
                                    
                                    Button("Test All Members Alert") {
                                        Task {
                                            await testAllMembersAlert()
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
            .navigationTitle("Group Test")
            .onAppear {
                loadOrganizations()
            }
            .onChange(of: selectedOrganization) { _, org in
                if let org = org {
                    loadGroups(for: org)
                } else {
                    groups = []
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
    
    private func loadGroups(for organization: Organization) {
        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("organizations")
                    .document(organization.id)
                    .collection("groups")
                    .getDocuments()
                
                let groups = snapshot.documents.compactMap { doc -> OrganizationGroup? in
                    let data = doc.data()
                    return OrganizationGroup(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Unknown",
                        description: data["description"] as? String,
                        organizationId: organization.id,
                        isActive: data["isActive"] as? Bool ?? true,
                        memberCount: data["memberCount"] as? Int ?? 0,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                
                await MainActor.run {
                    self.groups = groups
                }
            } catch {
                print("Error loading groups: \(error)")
            }
        }
    }
    
    private func runFullTest() async {
        isLoading = true
        testResults = "🧪 RUNNING FULL GROUP NOTIFICATION TEST\n"
        testResults += "=====================================\n\n"
        
        // 1. Check authentication
        guard let currentUser = Auth.auth().currentUser else {
            testResults += "❌ No authenticated user\n"
            isLoading = false
            return
        }
        
        testResults += "✅ User authenticated: \(currentUser.uid)\n\n"
        
        // 2. Check FCM token
        await checkFCMToken(userId: currentUser.uid)
        
        // 3. Check following status
        await checkFollowingStatus(userId: currentUser.uid)
        
        // 4. Check group preferences
        await checkGroupPreferences(userId: currentUser.uid)
        
        // 5. Test alert creation
        if let org = selectedOrganization {
            await testAlertCreation(organization: org)
        }
        
        testResults += "\n✅ FULL TEST COMPLETED\n"
        isLoading = false
    }
    
    private func checkFCMToken(userId: String) async {
        testResults += "📱 Checking FCM Token...\n"
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data() ?? [:]
                let fcmToken = userData["fcmToken"] as? String
                let platform = userData["platform"] as? String ?? "unknown"
                let tokenStatus = userData["tokenStatus"] as? String ?? "unknown"
                
                testResults += "  FCM Token: \(fcmToken != nil ? "✅ Present" : "❌ Missing")\n"
                testResults += "  Platform: \(platform)\n"
                testResults += "  Status: \(tokenStatus)\n"
                
                if let token = fcmToken {
                    testResults += "  Token Length: \(token.count) characters\n"
                }
            } else {
                testResults += "  ❌ User document not found\n"
            }
        } catch {
            testResults += "  ❌ Error: \(error)\n"
        }
        
        testResults += "\n"
    }
    
    private func checkFollowingStatus(userId: String) async {
        testResults += "👥 Checking Following Status...\n"
        
        do {
            let db = Firestore.firestore()
            let followedOrgsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("followedOrganizations")
                .getDocuments()
            
            testResults += "  Following \(followedOrgsSnapshot.documents.count) organizations:\n"
            
            for doc in followedOrgsSnapshot.documents {
                let data = doc.data()
                let orgId = doc.documentID
                let isFollowing = data["isFollowing"] as? Bool ?? false
                let alertsEnabled = data["alertsEnabled"] as? Bool ?? true
                
                testResults += "    - \(orgId): Following=\(isFollowing), Alerts=\(alertsEnabled)\n"
            }
        } catch {
            testResults += "  ❌ Error: \(error)\n"
        }
        
        testResults += "\n"
    }
    
    private func checkGroupPreferences(userId: String) async {
        testResults += "⚙️ Checking Group Preferences...\n"
        
        do {
            let db = Firestore.firestore()
            let followedOrgsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("followedOrganizations")
                .getDocuments()
            
            for doc in followedOrgsSnapshot.documents {
                let orgId = doc.documentID
                let data = doc.data()
                
                testResults += "  Organization \(orgId):\n"
                
                if let groupPreferences = data["groupPreferences"] as? [String: Bool] {
                    testResults += "    Group Preferences: \(groupPreferences)\n"
                } else {
                    testResults += "    No group preferences set (defaults to enabled)\n"
                }
            }
        } catch {
            testResults += "  ❌ Error: \(error)\n"
        }
        
        testResults += "\n"
    }
    
    private func testAlertCreation(organization: Organization) async {
        testResults += "🚨 Testing Alert Creation...\n"
        
        guard let currentUser = Auth.auth().currentUser else {
            testResults += "  ❌ No authenticated user\n"
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            if let firstGroup = groups.first {
                testResults += "  Creating test alert for group: \(firstGroup.name)\n"
                
                let testAlert: [String: Any] = [
                    "title": "🧪 Test Group Alert",
                    "description": "This is a test alert to verify group notifications are working",
                    "organizationId": organization.id,
                    "organizationName": organization.name,
                    "groupId": firstGroup.id,
                    "groupName": firstGroup.name,
                    "type": "test",
                    "severity": "medium",
                    "postedBy": currentUser.displayName ?? "Test User",
                    "postedByUserId": currentUser.uid,
                    "isActive": true,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                let alertRef = try await db.collection("organizations")
                    .document(organization.id)
                    .collection("alerts")
                    .addDocument(data: testAlert)
                
                testResults += "  ✅ Test alert created with ID: \(alertRef.documentID)\n"
                testResults += "  This should trigger Firebase function to send notifications\n"
                
            } else {
                testResults += "  No groups found, creating 'All members' alert\n"
                
                let testAlert: [String: Any] = [
                    "title": "🧪 Test All Members Alert",
                    "description": "This is a test alert for all members",
                    "organizationId": organization.id,
                    "organizationName": organization.name,
                    "type": "test",
                    "severity": "medium",
                    "postedBy": currentUser.displayName ?? "Test User",
                    "postedByUserId": currentUser.uid,
                    "isActive": true,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                let alertRef = try await db.collection("organizations")
                    .document(organization.id)
                    .collection("alerts")
                    .addDocument(data: testAlert)
                
                testResults += "  ✅ Test alert created with ID: \(alertRef.documentID)\n"
            }
            
        } catch {
            testResults += "  ❌ Error creating test alert: \(error)\n"
        }
        
        testResults += "\n"
    }
    
    private func testGroupAlert() async {
        guard let org = selectedOrganization, let group = groups.first else { return }
        
        isLoading = true
        testResults = "🧪 Testing Group Alert for \(group.name)\n"
        testResults += "=====================================\n\n"
        
        await testAlertCreation(organization: org)
        isLoading = false
    }
    
    private func testAllMembersAlert() async {
        guard let org = selectedOrganization else { return }
        
        isLoading = true
        testResults = "🧪 Testing All Members Alert\n"
        testResults += "============================\n\n"
        
        await testAlertCreation(organization: org)
        isLoading = false
    }
}

#Preview {
    GroupNotificationTestView()
}
