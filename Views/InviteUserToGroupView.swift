import SwiftUI
import FirebaseFirestore

struct InviteUserToGroupView: View {
    let organization: Organization
    @EnvironmentObject var authManager: SimpleAuthManager
    @StateObject private var invitationService = GroupInvitationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedGroup: OrganizationGroup?
    @State private var userEmail = ""
    @State private var userName = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select Group") {
                    if let groups = organization.groups, !groups.isEmpty {
                        Picker("Group", selection: $selectedGroup) {
                            Text("Select a group").tag(nil as OrganizationGroup?)
                            ForEach(groups) { group in
                                Text(group.name).tag(group as OrganizationGroup?)
                            }
                        }
                    } else {
                        Text("No groups available")
                            .foregroundColor(.secondary)
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
                _ = try await invitationService.sendGroupInvitation(
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
            .limit(1)
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
