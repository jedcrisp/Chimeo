import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct OrganizationUpdateTestView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
    @State private var selectedOrganization: Organization?
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var testResults: [String] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Organization Selection
                    organizationSelectionSection
                    
                    // Test Buttons
                    if selectedOrganization != nil {
                        testButtonsSection
                    }
                    
                    // Test Results
                    if !testResults.isEmpty {
                        testResultsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Org Update Tests")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadOrganizations()
            }
            .alert("Test Result", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var organizationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Organization")
                .font(.headline)
            
            if isLoading {
                ProgressView("Loading organizations...")
            } else {
                Picker("Organization", selection: $selectedOrganization) {
                    Text("Select an organization").tag(nil as Organization?)
                    ForEach(organizations, id: \.id) { org in
                        Text(org.name).tag(org as Organization?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var testButtonsSection: some View {
        VStack(spacing: 15) {
            Text("Test Organization Updates")
                .font(.headline)
            
            // Test Group Creation
            Button(action: { testGroupCreation() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Test Group Creation")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            
            // Test Group Update
            Button(action: { testGroupUpdate() }) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                    Text("Test Group Update")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .cornerRadius(10)
            }
            
            // Test Group Deletion
            Button(action: { testGroupDeletion() }) {
                HStack {
                    Image(systemName: "trash.circle.fill")
                    Text("Test Group Deletion")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
            
            // Test Admin Addition
            Button(action: { testAdminAddition() }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Test Admin Addition")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.purple)
                .cornerRadius(10)
            }
            
            // Test Profile Update
            Button(action: { testProfileUpdate() }) {
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text("Test Profile Update")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var testResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Test Results")
                .font(.headline)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.caption)
                            .padding(5)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Test Methods
    private func loadOrganizations() {
        isLoading = true
        testResults.append("🔄 Loading organizations...")
        
        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("organizations").getDocuments()
                
                var orgs: [Organization] = []
                for document in snapshot.documents {
                    let data = document.data()
                    let org = Organization(
                        id: document.documentID,
                        name: data["name"] as? String ?? "Unknown",
                        type: data["type"] as? String ?? "business",
                        description: data["description"] as? String ?? "",
                        location: Location(
                            latitude: (data["location"] as? [String: Any])?["latitude"] as? Double ?? 0.0,
                            longitude: (data["location"] as? [String: Any])?["longitude"] as? Double ?? 0.0,
                            address: (data["location"] as? [String: Any])?["address"] as? String ?? data["address"] as? String ?? "",
                            city: (data["location"] as? [String: Any])?["city"] as? String ?? data["city"] as? String ?? "",
                            state: (data["location"] as? [String: Any])?["state"] as? String ?? data["state"] as? String ?? "",
                            zipCode: (data["location"] as? [String: Any])?["zipCode"] as? String ?? data["zipCode"] as? String ?? ""
                        ),
                        verified: data["verified"] as? Bool ?? false,
                        followerCount: data["followerCount"] as? Int ?? 0,
                        logoURL: data["logoURL"] as? String,
                        website: data["website"] as? String,
                        phone: data["phone"] as? String,
                        email: data["email"] as? String,
                        groups: nil,
                        adminIds: data["adminIds"] as? [String: Bool],
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
                        groupsArePrivate: data["groupsArePrivate"] as? Bool ?? false,
                        allowPublicGroupJoin: data["allowPublicGroupJoin"] as? Bool ?? true
                    )
                    orgs.append(org)
                }
                
                await MainActor.run {
                    self.organizations = orgs
                    self.isLoading = false
                    self.testResults.append("✅ Loaded \(orgs.count) organizations")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.testResults.append("❌ Error loading organizations: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func testGroupCreation() {
        guard let org = selectedOrganization else { return }
        
        testResults.append("🧪 Testing group creation for \(org.name)...")
        
        Task {
            do {
                let groupService = OrganizationGroupService()
                let testGroup = OrganizationGroup(
                    id: "test-group-\(UUID().uuidString.prefix(8))",
                    name: "Test Group \(Date().timeIntervalSince1970)",
                    description: "This is a test group created for notification testing",
                    organizationId: org.id,
                    isActive: true,
                    memberCount: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                let createdGroup = try await groupService.createOrganizationGroup(group: testGroup, organizationId: org.id)
                
                await MainActor.run {
                    self.testResults.append("✅ Group created successfully: \(createdGroup.name)")
                    self.alertMessage = "Group '\(createdGroup.name)' created successfully! Check for notifications."
                    self.showingAlert = true
                }
            } catch {
                await MainActor.run {
                    self.testResults.append("❌ Group creation failed: \(error.localizedDescription)")
                    self.alertMessage = "Group creation failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func testGroupUpdate() {
        guard let org = selectedOrganization else { return }
        
        testResults.append("🧪 Testing group update for \(org.name)...")
        
        Task {
            do {
                // First, get existing groups
                let groupService = OrganizationGroupService()
                let groups = try await groupService.getOrganizationGroups(organizationId: org.id)
                
                if let firstGroup = groups.first {
                    let updatedGroup = OrganizationGroup(
                        id: firstGroup.id,
                        name: firstGroup.name,
                        description: "Updated description - \(Date().timeIntervalSince1970)",
                        organizationId: firstGroup.organizationId,
                        isActive: firstGroup.isActive,
                        memberCount: firstGroup.memberCount,
                        createdAt: firstGroup.createdAt,
                        updatedAt: Date()
                    )
                    
                    try await groupService.updateOrganizationGroup(updatedGroup)
                    
                    await MainActor.run {
                        self.testResults.append("✅ Group updated successfully: \(updatedGroup.name)")
                        self.alertMessage = "Group '\(updatedGroup.name)' updated successfully! Check for notifications."
                        self.showingAlert = true
                    }
                } else {
                    await MainActor.run {
                        self.testResults.append("⚠️ No groups found to update")
                        self.alertMessage = "No groups found to update. Create a group first."
                        self.showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.testResults.append("❌ Group update failed: \(error.localizedDescription)")
                    self.alertMessage = "Group update failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func testGroupDeletion() {
        guard let org = selectedOrganization else { return }
        
        testResults.append("🧪 Testing group deletion for \(org.name)...")
        
        Task {
            do {
                // First, get existing groups
                let groupService = OrganizationGroupService()
                let groups = try await groupService.getOrganizationGroups(organizationId: org.id)
                
                if let firstGroup = groups.first {
                    try await groupService.deleteOrganizationGroup(firstGroup.name, organizationId: org.id)
                    
                    await MainActor.run {
                        self.testResults.append("✅ Group deleted successfully: \(firstGroup.name)")
                        self.alertMessage = "Group '\(firstGroup.name)' deleted successfully! Check for notifications."
                        self.showingAlert = true
                    }
                } else {
                    await MainActor.run {
                        self.testResults.append("⚠️ No groups found to delete")
                        self.alertMessage = "No groups found to delete. Create a group first."
                        self.showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.testResults.append("❌ Group deletion failed: \(error.localizedDescription)")
                    self.alertMessage = "Group deletion failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func testAdminAddition() {
        guard let org = selectedOrganization else { return }
        
        testResults.append("🧪 Testing admin addition for \(org.name)...")
        
        Task {
            do {
                let apiService = APIService()
                
                // Find a test user to add as admin (use current user for testing)
                if let currentUser = authManager.currentUser {
                    try await apiService.addOrganizationAdmin(currentUser.id, to: org.id)
                    
                    await MainActor.run {
                        self.testResults.append("✅ Admin added successfully: \(currentUser.email ?? "unknown")")
                        self.alertMessage = "Admin added successfully! Check for notifications."
                        self.showingAlert = true
                    }
                } else {
                    await MainActor.run {
                        self.testResults.append("❌ No current user found")
                        self.alertMessage = "No current user found for admin addition test."
                        self.showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.testResults.append("❌ Admin addition failed: \(error.localizedDescription)")
                    self.alertMessage = "Admin addition failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func testProfileUpdate() {
        guard let org = selectedOrganization else { return }
        
        testResults.append("🧪 Testing profile update for \(org.name)...")
        
        Task {
            do {
                let db = Firestore.firestore()
                let orgRef = db.collection("organizations").document(org.id)
                
                // Update a simple field to trigger profile update notification
                try await orgRef.updateData([
                    "description": "Updated description - \(Date().timeIntervalSince1970)",
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                
                // Send manual notification for profile update
                let notificationService = OrganizationUpdateNotificationService()
                let updateData = OrganizationUpdateData(
                    organizationId: org.id,
                    organizationName: org.name,
                    updateType: OrganizationUpdateType.profileUpdated,
                    updatedBy: authManager.currentUser?.id ?? "unknown",
                    updatedByEmail: authManager.currentUser?.email ?? "unknown@example.com",
                    updateDetails: [
                        "description": "Updated description - \(Date().timeIntervalSince1970)"
                    ],
                    timestamp: Date()
                )
                
                await notificationService.sendOrganizationUpdateNotification(updateData)
                
                await MainActor.run {
                    self.testResults.append("✅ Profile updated successfully")
                    self.alertMessage = "Profile updated successfully! Check for notifications."
                    self.showingAlert = true
                }
            } catch {
                await MainActor.run {
                    self.testResults.append("❌ Profile update failed: \(error.localizedDescription)")
                    self.alertMessage = "Profile update failed: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
}

#Preview {
    OrganizationUpdateTestView()
        .environmentObject(SimpleAuthManager())
}
