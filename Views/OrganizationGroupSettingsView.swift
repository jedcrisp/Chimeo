import SwiftUI
import FirebaseFirestore

struct OrganizationGroupSettingsView: View {
    let organization: Organization
    @EnvironmentObject var authManager: SimpleAuthManager
    @StateObject private var invitationService = GroupInvitationService()
    @State private var groupsArePrivate: Bool
    @State private var allowPublicGroupJoin: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingInviteUser = false
    
    init(organization: Organization) {
        self.organization = organization
        self._groupsArePrivate = State(initialValue: organization.groupsArePrivate)
        self._allowPublicGroupJoin = State(initialValue: organization.allowPublicGroupJoin)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Privacy Settings") {
                    Toggle("Make Groups Private", isOn: $groupsArePrivate)
                        .onChange(of: groupsArePrivate) { _, newValue in
                            updateGroupPrivacySettings()
                        }
                    
                    if groupsArePrivate {
                        Toggle("Allow Public Group Join", isOn: $allowPublicGroupJoin)
                            .onChange(of: allowPublicGroupJoin) { _, newValue in
                                updateGroupPrivacySettings()
                            }
                        
                        Text("When groups are private, members must be manually invited by organization admins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if groupsArePrivate {
                    Section("Group Management") {
                        Button("Invite User to Group") {
                            showingInviteUser = true
                        }
                        .foregroundColor(.blue)
                        
                        NavigationLink("Manage Group Invitations") {
                            OrganizationInvitationManagementView(organization: organization)
                        }
                    }
                }
                
                Section("Current Settings") {
                    HStack {
                        Text("Groups are private")
                        Spacer()
                        Text(groupsArePrivate ? "Yes" : "No")
                            .foregroundColor(groupsArePrivate ? .green : .orange)
                    }
                    
                    if groupsArePrivate {
                        HStack {
                            Text("Allow public join")
                            Spacer()
                            Text(allowPublicGroupJoin ? "Yes" : "No")
                                .foregroundColor(allowPublicGroupJoin ? .green : .orange)
                        }
                    }
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingInviteUser) {
                InviteUserToGroupView(organization: organization)
            }
        }
    }
    
    private func updateGroupPrivacySettings() {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("organizations")
                    .document(organization.id)
                    .updateData([
                        "groupsArePrivate": groupsArePrivate,
                        "allowPublicGroupJoin": allowPublicGroupJoin,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                
                await MainActor.run {
                    self.isLoading = false
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
}

struct OrganizationInvitationManagementView: View {
    let organization: Organization
    @EnvironmentObject var authManager: SimpleAuthManager
    @StateObject private var invitationService = GroupInvitationService()
    @State private var invitations: [GroupInvitation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading invitations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if invitations.isEmpty {
                emptyStateView
            } else {
                invitationListView
            }
        }
        .navigationTitle("Group Invitations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadInvitations()
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Group Invitations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No group invitations have been sent for this organization yet.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var invitationListView: some View {
        List {
            ForEach(invitations) { invitation in
                AdminInvitationRowView(
                    invitation: invitation,
                    onCancel: { cancelInvitation(invitation) }
                )
            }
        }
        .refreshable {
            loadInvitations()
        }
    }
    
    private func loadInvitations() {
        isLoading = true
        
        Task {
            do {
                let fetchedInvitations = try await invitationService.getOrganizationInvitations(organizationId: organization.id)
                await MainActor.run {
                    self.invitations = fetchedInvitations
                    self.isLoading = false
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
    
    private func cancelInvitation(_ invitation: GroupInvitation) {
        Task {
            do {
                try await invitationService.cancelInvitation(invitationId: invitation.id)
                await MainActor.run {
                    // Remove the invitation from the list
                    invitations.removeAll { $0.id == invitation.id }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }
}

struct AdminInvitationRowView: View {
    let invitation: GroupInvitation
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.groupName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Invited: \(invitation.invitedUserName ?? invitation.invitedUserEmail ?? "Unknown")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 4) {
                    Image(systemName: invitation.status.icon)
                        .foregroundColor(invitation.status.color)
                    Text(invitation.status.displayName)
                        .font(.caption)
                        .foregroundColor(invitation.status.color)
                }
            }
            
            // Message
            if let message = invitation.message, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
            }
            
            // Expiry info
            if invitation.status == .pending {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if invitation.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Expires in \(invitation.daysUntilExpiry) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Action buttons
            if invitation.status == .pending {
                Button("Cancel Invitation") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OrganizationGroupSettingsView(organization: Organization(
        id: "test-org",
        name: "Test Organization",
        type: "business",
        location: Location(latitude: 0, longitude: 0),
        groupsArePrivate: true,
        allowPublicGroupJoin: false
    ))
    .environmentObject(SimpleAuthManager())
}
