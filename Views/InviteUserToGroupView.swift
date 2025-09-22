import SwiftUI
import FirebaseFirestore

struct InviteUserToGroupView: View {
    let organization: Organization
    @EnvironmentObject var authManager: SimpleAuthManager
    @StateObject private var groupService = OrganizationGroupService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedGroup: OrganizationGroup?
    @State private var userEmail = ""
    @State private var userName = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var groups: [OrganizationGroup] = []
    @State private var isLoadingGroups = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select Group") {
                    if isLoadingGroups {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading groups...")
                                .foregroundColor(.secondary)
                        }
                    } else if groups.isEmpty {
                        Text("No groups available")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Group", selection: $selectedGroup) {
                            Text("Select a group").tag(nil as OrganizationGroup?)
                            ForEach(groups) { group in
                                Text(group.name).tag(group as OrganizationGroup?)
                            }
                        }
                    }
                }
                
                Section("User Information") {
                    TextField("User Email", text: $userEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("User Name (Optional)", text: $userName)
                        .autocapitalization(.words)
                }
                
                Section("Invitation Message") {
                    TextField("Personal message (Optional)", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("Send Invitation") {
                        sendInvitation()
                    }
                    .disabled(!canSendInvitation)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Invite User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Invitation sent successfully!")
            }
            .onAppear {
                loadGroups()
            }
        }
    }
    
    private func loadGroups() {
        isLoadingGroups = true
        
        Task {
            do {
                let fetchedGroups = try await groupService.getOrganizationGroups(organizationId: organization.id)
                await MainActor.run {
                    self.groups = fetchedGroups
                    self.isLoadingGroups = false
                    print("📋 Loaded \(fetchedGroups.count) groups for invitation")
                }
            } catch {
                print("❌ Error loading groups for invitation: \(error)")
                await MainActor.run {
                    self.isLoadingGroups = false
                    self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private var canSendInvitation: Bool {
        return selectedGroup != nil && !userEmail.isEmpty && !isLoading
    }
    
    private func sendInvitation() {
        guard let group = selectedGroup,
              let currentUserId = authManager.currentUser?.id,
              let currentUserName = authManager.currentUser?.name else {
            errorMessage = "Missing required information"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // First, we need to find the user by email to get their user ID
                let userId = try await findUserByEmail(userEmail)
                
                // Send the invitation
                _ = try await groupService.sendGroupInvitation(
                    organizationId: organization.id,
                    organizationName: organization.name,
                    groupId: group.id,
                    groupName: group.name,
                    invitedUserId: userId,
                    invitedUserEmail: userEmail,
                    invitedUserName: userName.isEmpty ? nil : userName,
                    message: message.isEmpty ? nil : message,
                    invitedByUserId: currentUserId,
                    invitedByName: currentUserName
                )
                
                await MainActor.run {
                    self.isLoading = false
                    self.showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func findUserByEmail(_ email: String) async throws -> String {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw NSError(domain: "InviteUserToGroupView", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not found with email: \(email)"])
        }
        
        return document.documentID
    }
}

#Preview {
    InviteUserToGroupView(organization: Organization(
        id: "test-org",
        name: "Test Organization",
        type: "business",
        location: Location(latitude: 0, longitude: 0),
        groups: [
            OrganizationGroup(id: "group1", name: "Group 1", organizationId: "test-org"),
            OrganizationGroup(id: "group2", name: "Group 2", organizationId: "test-org")
        ],
        groupsArePrivate: true,
        allowPublicGroupJoin: false
    ))
    .environmentObject(SimpleAuthManager())
}
