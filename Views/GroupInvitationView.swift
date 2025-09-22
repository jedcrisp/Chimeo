import SwiftUI
import FirebaseFirestore

struct GroupInvitationView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
    @StateObject private var groupService = OrganizationGroupService()
    @State private var invitations: [GroupInvitation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
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
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Group Invitations")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You don't have any pending group invitations at the moment.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var invitationListView: some View {
        List {
            ForEach(invitations) { invitation in
                InvitationRowView(
                    invitation: invitation,
                    onAccept: { respondToInvitation(invitation, status: .accepted) },
                    onDecline: { respondToInvitation(invitation, status: .declined) }
                )
            }
        }
        .refreshable {
            loadInvitations()
        }
    }
    
    private func loadInvitations() {
        guard let userId = authManager.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                let fetchedInvitations = try await groupService.getUserInvitations(userId: userId)
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
    
    private func respondToInvitation(_ invitation: GroupInvitation, status: InvitationStatus) {
        Task {
            do {
                try await groupService.respondToInvitation(invitationId: invitation.id, status: status)
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

struct InvitationRowView: View {
    let invitation: GroupInvitation
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.groupName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("from \(invitation.organizationName)")
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
            if invitation.status == .pending && !invitation.isExpired {
                HStack(spacing: 12) {
                    Button("Decline") {
                        onDecline()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Accept") {
                        onAccept()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    GroupInvitationView()
        .environmentObject(SimpleAuthManager())
}
