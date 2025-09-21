import SwiftUI

struct MyAlertsView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @ObservedObject private var followStatusManager = FollowStatusManager.shared
    @State private var followedOrganizations: [Organization] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingAddOrganization = false
    @State private var expandedOrganizations: Set<String> = []
    @State private var groupPreferences: [String: Bool] = [:]
    @State private var isLoadingGroups = false
    @State private var showingGroupsError = false
    @State private var groupsErrorMessage = ""
    @State private var searchText = ""
    @State private var organizationGroups: [String: [OrganizationGroup]] = [:]
    
    private var filteredOrganizations: [Organization] {
        var filtered = followedOrganizations
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { org in
                org.name.localizedCaseInsensitiveContains(searchText) ||
                org.description?.localizedCaseInsensitiveContains(searchText) == true ||
                org.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    

    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Notification Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification Preferences")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Toggle groups on/off to control which alerts you receive as push notifications. Groups are disabled by default for your privacy.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Organizations List
                    if isLoading {
                        loadingView
                    } else if followedOrganizations.isEmpty {
                        emptyStateView
                    } else {
                        organizationsList
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("My Alerts")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadFollowedOrganizations()
            }
            .onAppear {
                Task {
                    await loadFollowedOrganizations()
                }
            }
            .onReceive(followStatusManager.$followStatusChanges) { _ in
                // Refresh followed organizations when follow status changes
                Task {
                    await loadFollowedOrganizations()
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView("Loading your organizations...")
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Organizations Followed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You're not following any organizations yet. Follow organizations to receive their alerts and updates.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Organizations List
    private var organizationsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(filteredOrganizations) { organization in
                OrganizationCard(
                    organization: organization,
                    groups: organizationGroups[organization.id] ?? [],
                    groupPreferences: $groupPreferences,
                    isExpanded: expandedOrganizations.contains(organization.id),
                    onToggleExpanded: {
                        if expandedOrganizations.contains(organization.id) {
                            expandedOrganizations.remove(organization.id)
                        } else {
                            expandedOrganizations.insert(organization.id)
                        }
                    },
                    apiService: apiService
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func loadFollowedOrganizations() async {
        isLoading = true
        do {
            let followed = try await apiService.fetchFollowedOrganizations()
            await MainActor.run {
                self.followedOrganizations = followed
                // Groups are hidden by default - user must click to expand
            }
            await loadOrganizationGroups(for: followed)
            await MainActor.run { self.isLoading = false }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func loadOrganizationGroups(for organizations: [Organization]) async {
        for organization in organizations {
            do {
                // Fetch real groups from API
                let sampleGroups = try await apiService.getOrganizationGroups(organizationId: organization.id)
                
                await MainActor.run {
                    self.organizationGroups[organization.id] = sampleGroups
                    
                    // Initialize preferences for new groups
                    for group in sampleGroups {
                        if self.groupPreferences[group.id] == nil {
                            self.groupPreferences[group.id] = false // Default to disabled - user must opt-in
                        }
                    }
                }
                
                // Load persisted preferences per organization and merge
                let savedPrefs = try await apiService.getGroupPreferences(for: organization.id)
                await MainActor.run {
                    for (groupId, enabled) in savedPrefs {
                        self.groupPreferences[groupId] = enabled
                    }
                }
            } catch {
                print("Failed to load groups for organization: \(organization.name)")
            }
        }
    }
    
    private func createSampleGroups(for organization: Organization) -> [OrganizationGroup] {
        // Create sample groups based on organization type
        let groupNames: [String]
        let descriptions: [String]
        
        switch organization.type.lowercased() {
        case "school":
            groupNames = ["Emergency Alerts", "Sports & Events", "Academic Updates"]
            descriptions = ["Urgent safety and emergency information", "Sports schedules and event updates", "Academic calendar and updates"]
        case "church":
            groupNames = ["Youth Ministry", "Community Events", "Prayer Requests"]
            descriptions = ["Youth group activities and events", "Community outreach and events", "Prayer request updates"]
        case "business":
            groupNames = ["Promotions & Deals", "Events & Workshops", "Customer Service"]
            descriptions = ["Special offers and promotions", "Upcoming events and workshops", "Customer service announcements"]
        case "emergency":
            groupNames = ["Emergency Alerts", "Public Safety", "Weather Updates", "Community Notices"]
            descriptions = ["Critical emergency information", "Public safety announcements", "Weather-related alerts", "General community notices"]
        default:
            groupNames = ["Updates", "Events", "News"]
            descriptions = ["Important announcements", "Upcoming events", "Latest news and updates"]
        }
        
        return zip(groupNames, descriptions).enumerated().map { index, tuple in
            let (name, description) = tuple
            return OrganizationGroup(
                name: name,
                description: description,
                organizationId: organization.id,
                memberCount: Int.random(in: 50...500)
            )
        }
    }
}

// MARK: - Organization Card
struct OrganizationCard: View {
    let organization: Organization
    let groups: [OrganizationGroup]
    @Binding var groupPreferences: [String: Bool]
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let apiService: APIService
    @State private var showingProfile = false
    
    private var organizationInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(organization.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if organization.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(organization.type.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    private var groupsSection: some View {
        VStack(spacing: 0) {
            // Separator
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray5))
                .padding(.horizontal, 20)
            
            // Groups Header (Clickable)
            Button(action: onToggleExpanded) {
                HStack {
                    Text("Alert Groups")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(groups.count) groups")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Dropdown Arrow
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            .buttonStyle(.plain)
            
            // Groups List (Collapsible)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(groups) { group in
                        GroupToggleRow(
                            group: group,
                            isEnabled: groupPreferences[group.id] ?? true,
                            onToggle: { isEnabled in
                                groupPreferences[group.id] = isEnabled
                                Task { 
                                    try? await apiService.updateGroupPreference(
                                        organizationId: organization.id, 
                                        groupId: group.id, 
                                        isEnabled: isEnabled
                                    ) 
                                }
                            }
                        )
                        
                        if group.id != groups.last?.id {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(.systemGray6))
                                .padding(.leading, 20)
                                .padding(.trailing, 20)
                        }
                    }
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
        }
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Organization Header
            Button(action: { showingProfile = true }) {
                HStack(spacing: 16) {
                    // Organization Icon
                    OrganizationLogoView(organization: organization, size: 48, showBorder: false)
                    
                    // Organization Info
                    organizationInfoSection
                    
                    Spacer()
                    
                    // Profile Button
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            
            // Groups Section
            if !groups.isEmpty {
                groupsSection
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                OrganizationProfileView(organization: organization)
            }
        }
    }
    
    private var organizationIcon: String {
        switch organization.type.lowercased() {
        case "church": return "building.2.fill"
        case "pto": return "graduationcap.fill"
        case "school": return "building.columns.fill"
        case "business": return "building.2.fill"
        case "government": return "building.columns.fill"
        case "nonprofit": return "heart.fill"
        case "emergency": return "cross.fill"
        case "physical_therapy": return "cross.fill"
        default: return "building.2.fill"
        }
    }
    
    private var organizationColor: Color {
        switch organization.type.lowercased() {
        case "church": return .purple
        case "pto": return .green
        case "school": return .blue
        case "business": return .orange
        case "government": return .red
        case "nonprofit": return .pink
        case "emergency": return .red
        case "physical_therapy": return .teal
        default: return .gray
        }
    }
}



// MARK: - Add Organization View
struct AddOrganizationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedType: String? = nil
    @State private var followedOrganizations: Set<String> = []
    
    private var availableOrganizations: [Organization] {
        organizations.filter { !followedOrganizations.contains($0.id) }
    }
    
    private var filteredOrganizations: [Organization] {
        var filtered = availableOrganizations
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { org in
                org.name.localizedCaseInsensitiveContains(searchText) ||
                org.description?.localizedCaseInsensitiveContains(searchText) == true ||
                org.type.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by type
        if let selectedType = selectedType {
            filtered = filtered.filter { $0.type.lowercased() == selectedType.lowercased() }
        }
        
        return filtered
    }
    
    private var organizationTypes: [String] {
        Array(Set(availableOrganizations.map { $0.type })).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search organizations...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Type Filter
                    if !organizationTypes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(
                                    title: "All",
                                    isSelected: selectedType == nil,
                                    action: { selectedType = nil }
                                )
                                
                                ForEach(organizationTypes, id: \.self) { type in
                                    FilterChip(
                                        title: type.capitalized,
                                        isSelected: selectedType == type,
                                        action: { selectedType = type }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Organizations List
                if isLoading {
                    Spacer()
                    ProgressView("Loading organizations...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if filteredOrganizations.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text(searchText.isEmpty ? "No organizations available" : "No matching organizations")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if !searchText.isEmpty {
                            Text("Try adjusting your search terms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List(filteredOrganizations) { organization in
                        AddOrganizationRow(
                            organization: organization,
                            isFollowing: followedOrganizations.contains(organization.id)
                        ) { organizationId in
                            Task {
                                do {
                                    let isCurrentlyFollowing = followedOrganizations.contains(organizationId)
                                    if isCurrentlyFollowing {
                                        try await serviceCoordinator.unfollowOrganization(organizationId)
                                    } else {
                                        try await serviceCoordinator.followOrganization(organizationId)
                                    }
                                } catch {
                                    print("❌ Error toggling follow status: \(error)")
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Follow Organizations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }

        }
    }
    

}

// MARK: - Add Organization Row
struct AddOrganizationRow: View {
    let organization: Organization
    let isFollowing: Bool
    let onToggle: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Organization Icon
            Image(systemName: organizationIcon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(organizationColor)
                .clipShape(Circle())
            
            // Organization Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(organization.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if organization.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
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
            
            // Follow Button
            Button(action: { onToggle(organization.id) }) {
                HStack {
                    Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                    Text(isFollowing ? "Unfollow" : "Follow")
                }
                .font(.subheadline)
                .foregroundColor(isFollowing ? .red : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isFollowing ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    private var organizationIcon: String {
        switch organization.type.lowercased() {
        case "church": return "building.2.fill"
        case "pto": return "graduationcap.fill"
        case "school": return "building.columns.fill"
        case "business": return "building.2.fill"
        case "government": return "building.columns.fill"
        case "nonprofit": return "heart.fill"
        case "emergency": return "cross.fill"
        default: return "building.2.fill"
        }
    }
    
    private var organizationColor: Color {
        switch organization.type.lowercased() {
        case "church": return .purple
        case "pto": return .green
        case "school": return .blue
        case "business": return .orange
        case "government": return .red
        case "nonprofit": return .pink
        case "emergency": return .red
        default: return .gray
        }
    }
}



#Preview {
    MyAlertsView()
        .environmentObject(APIService())
}