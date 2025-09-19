import SwiftUI

struct FollowedOrganizationsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var followedOrganizations: [Organization] = []
    @State private var isLoading = false
    @State private var searchText = ""
    
    private var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return followedOrganizations
        } else {
            return followedOrganizations.filter { org in
                org.name.localizedCaseInsensitiveContains(searchText) ||
                org.description?.localizedCaseInsensitiveContains(searchText) == true ||
                org.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search organizations...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading organizations...")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if followedOrganizations.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "heart")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("No Followed Organizations")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You haven't followed any organizations yet. Follow organizations to receive their updates and announcements.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Discover Organizations") {
                        // Navigate to discover organizations
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                List(filteredOrganizations) { organization in
                    FollowedOrganizationRowView(organization: organization)
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Followed Organizations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFollowedOrganizations()
        }
    }
    
    private func loadFollowedOrganizations() {
        isLoading = true
        
        Task {
            do {
                let organizations = try await apiService.fetchOrganizations()
                await MainActor.run {
                    // For now, show all organizations as "followed"
                    // In production, you'd filter by actual followed status
                    self.followedOrganizations = organizations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to load organizations: \(error)")
                }
            }
        }
    }
}

// MARK: - Followed Organization Row View
struct FollowedOrganizationRowView: View {
    let organization: Organization
    @StateObject private var followStatusManager = FollowStatusManager.shared
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @State private var isLoading = false
    @State private var localFollowStatus: Bool? // Local state for immediate UI updates
    
    private var isFollowing: Bool {
        // Use local state if available, otherwise fall back to FollowStatusManager
        if let localStatus = localFollowStatus {
            return localStatus
        }
        return followStatusManager.getFollowStatus(for: organization.id) ?? false
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Organization Icon
            Image(systemName: "building.2.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // Organization Info
            VStack(alignment: .leading, spacing: 4) {
                Text(organization.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(organization.type.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = organization.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Follow/Unfollow Button
            Button(action: toggleFollow) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isFollowing ? "heart.fill" : "heart")
                            .font(.caption)
                    }
                    
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isFollowing ? .white : .red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFollowing ? Color.red : Color.red.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.vertical, 8)
        .onAppear {
            // Load the current follow status when the view appears
            loadFollowStatus()
        }
    }
    
    private func loadFollowStatus() {
        Task {
            do {
                let following = try await serviceCoordinator.isFollowingOrganization(organization.id)
                await MainActor.run {
                    // Update both local state and FollowStatusManager
                    localFollowStatus = following
                    followStatusManager.updateFollowStatus(organizationId: organization.id, isFollowing: following)
                }
            } catch {
                print("❌ Error loading follow status: \(error)")
            }
        }
    }
    
    private func toggleFollow() {
        // Immediately update local state for instant UI feedback
        let newFollowStatus = !isFollowing
        localFollowStatus = newFollowStatus
        
        isLoading = true
        
        Task {
            do {
                if isFollowing {
                    try await serviceCoordinator.unfollowOrganization(organization.id)
                    followStatusManager.updateFollowStatus(organizationId: organization.id, isFollowing: false)
                } else {
                    try await serviceCoordinator.followOrganization(organization.id)
                    followStatusManager.updateFollowStatus(organizationId: organization.id, isFollowing: true)
                }
            } catch {
                // Revert local state on error
                await MainActor.run {
                    localFollowStatus = !newFollowStatus // Revert to previous state
                }
                print("❌ Error in toggleFollow: \(error)")
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationView {
        FollowedOrganizationsView()
            .environmentObject(APIService())
    }
}
