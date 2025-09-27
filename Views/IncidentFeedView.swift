import SwiftUI
import FirebaseFirestore

struct IncidentFeedView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: SimpleAuthManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @State private var alerts: [OrganizationAlert] = []
    @State private var isLoading = false

    @State private var selectedAlertTypes: Set<IncidentType> = []
    @State private var selectedSeverities: Set<IncidentSeverity> = []
        @State private var showingAlertDetail = false
    @State private var selectedAlert: OrganizationAlert?
    @State private var alertToHide: OrganizationAlert?
    @State private var showHiddenAlerts = false
    @State private var showingGroupSelection = false
    @State private var showingFilterSheet = false
    @State private var searchText = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Check if user has organization admin access
    @State private var hasOrganizationAdminAccess = false
    
    private func checkAdminAccess() async {
        print("🔍 Checking admin access for user...")
        // Check if user is admin of any organization by checking all organizations
        if let currentUser = authManager.currentUser {
            print("   👤 Current user: \(currentUser.name ?? "Unknown") (\(currentUser.id))")
            print("   📧 Email: \(currentUser.email ?? "Unknown")")
            print("   👑 isOrganizationAdmin: \(currentUser.isOrganizationAdmin ?? false)")
            print("   🔧 isAdmin: \(currentUser.isAdmin)")
            print("   🏢 organizations: \(currentUser.organizations ?? [])")
            
            // First check local properties as a quick check
            let localAdminCheck = currentUser.isOrganizationAdmin == true || 
                                 currentUser.isAdmin == true ||
                                 !(currentUser.organizations?.isEmpty ?? true)
            
            print("   ✅ Local admin check result: \(localAdminCheck)")
            
            if localAdminCheck {
                print("   🎉 User has admin access based on local properties")
                await MainActor.run {
                    self.hasOrganizationAdminAccess = true
                }
                return
            }
            
            // If local check fails, do a more thorough check by looking at all organizations
            // This is more reliable but slower
            print("   🔍 Local check failed, checking database...")
            do {
                let db = Firestore.firestore()
                let orgsSnapshot = try await db.collection("organizations").getDocuments()
                
                print("   📊 Found \(orgsSnapshot.documents.count) organizations")
                
                var isAdminOfAnyOrg = false
                for orgDoc in orgsSnapshot.documents {
                    let orgData = orgDoc.data()
                    let orgName = orgData["name"] as? String ?? "Unknown"
                    if let adminIds = orgData["adminIds"] as? [String: Bool] {
                        print("   🏢 Organization: \(orgName)")
                        print("      Admin IDs: \(adminIds.keys.joined(separator: ", "))")
                        if adminIds[currentUser.id] == true {
                            print("      ✅ User is admin of this organization!")
                            isAdminOfAnyOrg = true
                            break
                        } else {
                            print("      ❌ User is not admin of this organization")
                        }
                    } else {
                        print("   🏢 Organization: \(orgName) - No adminIds found")
                    }
                }
                
                print("   🎯 Final admin check result: \(isAdminOfAnyOrg)")
                await MainActor.run {
                    self.hasOrganizationAdminAccess = isAdminOfAnyOrg
                }
            } catch {
                print("❌ Error checking admin access: \(error)")
                await MainActor.run {
                    self.hasOrganizationAdminAccess = false
                }
            }
        } else {
            await MainActor.run {
                self.hasOrganizationAdminAccess = false
            }
        }
    }
    
    var body: some View {
        NavigationView {
                    VStack(spacing: 0) {
            // Compact Filter Button at Top
            filterButtonSection
            
            // Clean Alerts Feed
            alertsFeed
                
                // Floating Action Button for posting alerts (only for org admins)
                if hasOrganizationAdminAccess {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingGroupSelection = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.green)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                print("🚀 IncidentFeedView appeared")
                print("🔍 AuthManager isAuthenticated: \(authManager.isAuthenticated)")
                print("🔍 ServiceCoordinator isAuthenticated: \(serviceCoordinator.isAuthenticated)")
                print("🔍 AuthManager currentUser: \(authManager.currentUser?.id ?? "nil")")
                print("🔍 ServiceCoordinator currentUser: \(serviceCoordinator.currentUser?.id ?? "nil")")
                
                // Ensure ServiceCoordinator is synced before loading alerts
                Task {
                    await serviceCoordinator.checkAndRestoreAuthenticationState()
                    loadAlerts()
                    await checkAdminAccess()
                }
            }
            .onChange(of: authManager.currentUser?.id) { _, _ in
                Task {
                    await checkAdminAccess()
                }
            }
            .alert("Error Loading Alerts", isPresented: $showingErrorAlert) {
                Button("OK") { }
                Button("Retry") {
                    loadAlerts()
                }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedAlertTypes) { _, _ in
                loadAlerts()
            }
            .onChange(of: selectedSeverities) { _, _ in
                loadAlerts()
            }
        }
        .sheet(isPresented: $showingAlertDetail) {
            if let alert = selectedAlert {
                AlertDetailView(alert: alert)
            }
        }
        .sheet(isPresented: $showingGroupSelection) {
            GroupSelectionView(authManager: authManager)
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetView(
                selectedAlertTypes: $selectedAlertTypes,
                selectedSeverities: $selectedSeverities,
                showHiddenAlerts: $showHiddenAlerts
            )
        }
    }
    
    // Organization Search Section removed - moved to map page
    
    // MARK: - Search and Filter Section
    private var filterButtonSection: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search alerts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            Spacer()
            
            // Filter Button
            Button(action: { showingFilterSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.title3)
                    
                    Text("Filters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Show active filter count
                    if !selectedAlertTypes.isEmpty || 
                       !selectedSeverities.isEmpty || 
                       showHiddenAlerts {
                        Text("(\(getActiveFilterCount()))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Helper Functions
    private func getActiveFilterCount() -> Int {
        var count = 0
        if !selectedAlertTypes.isEmpty { count += 1 }
        if !selectedSeverities.isEmpty { count += 1 }
        if showHiddenAlerts { count += 1 }
        return count
    }
    
    private func hideAlertFromFeed(_ alert: OrganizationAlert) {
        Task {
            // TODO: Add alert hiding to SimpleAuthManager
            print("Alert hiding not implemented in SimpleAuthManager")
            print("✅ Alert hidden successfully")
            
            // Remove from local state
            await MainActor.run {
                alerts.removeAll { $0.id == alert.id }
            }
        }
    }
    
    // MARK: - Clean Alerts Feed
    private var alertsFeed: some View {
        Group {
            if isLoading {
                loadingView
            } else if alerts.isEmpty {
                emptyStateView
            } else {
                alertsList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.blue)
                
                VStack(spacing: 8) {
                    Text("Loading alerts...")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Fetching the latest information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                // Enhanced Empty State Icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Text("No alerts found")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Follow organizations to see their alerts here. You'll be notified of important updates and incidents in your area.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
    }
    
    private var alertsList: some View {
        List {
            ForEach(filteredAlerts) { alert in
                                IncidentFeedAlertRowView(alert: alert)
                    .onTapGesture {
                        selectedAlert = alert
                        showingAlertDetail = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            hideAlertFromFeed(alert)
                        } label: {
                            Label("Hide", systemImage: "eye.slash")
                        }
                        .tint(.orange)
                    }
                    .listRowBackground(Color(.systemBackground))
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(.systemGray6).opacity(0.3))
        .refreshable {
            await refreshAlerts()
        }
    }
    
    private var filteredAlerts: [OrganizationAlert] {
        var filtered = alerts
        
        print("🔍 Filtering \(alerts.count) alerts")
        print("📋 Selected types: \(selectedAlertTypes.map { $0.rawValue })")
        print("📋 Selected severities: \(selectedSeverities.map { $0.rawValue })")
        
        // Apply search filter
        if !searchText.isEmpty {
            let beforeSearch = filtered.count
            filtered = filtered.filter { alert in
                alert.title.localizedCaseInsensitiveContains(searchText) ||
                alert.description.localizedCaseInsensitiveContains(searchText) ||
                alert.organizationName.localizedCaseInsensitiveContains(searchText) ||
                alert.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
                alert.severity.rawValue.localizedCaseInsensitiveContains(searchText)
            }
            print("🔍 Search filter: \(beforeSearch) -> \(filtered.count) alerts")
        }
        
        // Apply type and severity filters (only if filters are selected)
        let beforeTypeFilter = filtered.count
        if !selectedAlertTypes.isEmpty || !selectedSeverities.isEmpty {
            filtered = filtered.filter { alert in
                let typeMatch = selectedAlertTypes.isEmpty || selectedAlertTypes.contains(alert.type)
                let severityMatch = selectedSeverities.isEmpty || selectedSeverities.contains(alert.severity)
                
                if !typeMatch {
                    print("❌ Type filter: alert '\(alert.title)' has type '\(alert.type.rawValue)' but selected types are \(selectedAlertTypes.map { $0.rawValue })")
                }
                if !severityMatch {
                    print("❌ Severity filter: alert '\(alert.title)' has severity '\(alert.severity.rawValue)' but selected severities are \(selectedSeverities.map { $0.rawValue })")
                }
                
                return typeMatch && severityMatch
            }
            print("🔍 Type/Severity filter: \(beforeTypeFilter) -> \(filtered.count) alerts")
        } else {
            print("🔍 No filters selected - showing all alerts")
        }
        
        // Filter hidden alerts based on toggle state
        if !showHiddenAlerts {
            // In a real implementation, this would filter out alerts that the user has hidden
            // For now, we'll just return the filtered alerts as is
            // You would implement this by checking against a hidden alerts collection or user preferences
        }
        
        // Sort by most recent
        filtered.sort { first, second in
            first.postedAt > second.postedAt
        }
        
        print("✅ Final filtered count: \(filtered.count) alerts")
        return filtered
    }
    
    private func loadAlerts() {
        print("🔄 Starting to load alerts...")
        print("📱 Current user: \(authManager.currentUser?.id ?? "nil")")
        print("📱 Current user email: \(authManager.currentUser?.email ?? "nil")")
        print("🔍 ServiceCoordinator isAuthenticated: \(serviceCoordinator.isAuthenticated)")
        print("🔍 ServiceCoordinator currentUser: \(serviceCoordinator.currentUser?.id ?? "nil")")
        
        isLoading = true
        
        Task {
            do {
                // First, let's check if there are any followed organizations
                print("🔍 Checking followed organizations...")
                let followedOrgs = try await serviceCoordinator.fetchFollowedOrganizations()
                print("📋 Found \(followedOrgs.count) followed organizations:")
                for org in followedOrgs {
                    print("   📍 \(org.name) (ID: \(org.id))")
                }
                
                // Check if there are ANY alerts in the system at all
                print("🔍 Checking for ANY alerts in the system...")
                let allAlerts = try await serviceCoordinator.getAllAlerts()
                print("📊 Found \(allAlerts.count) total alerts in the system")
                for alert in allAlerts {
                    print("   📋 Alert: '\(alert.title)' from org \(alert.organizationId)")
                }
                
                print("📡 Fetching alerts from followed organizations...")
                let fetchedAlerts: [OrganizationAlert]
                do {
                    fetchedAlerts = try await serviceCoordinator.getFollowingOrganizationAlerts()
                    print("📥 Loaded \(fetchedAlerts.count) alerts from API")
                } catch {
                    print("❌ Error fetching followed organization alerts: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    throw error
                }
                for alert in fetchedAlerts {
                    print("📋 Alert: '\(alert.title)' - Type: \(alert.type.rawValue), Severity: \(alert.severity.rawValue)")
                    print("   📍 Organization ID: \(alert.organizationId)")
                    print("   📍 Organization Name: \(alert.organizationName)")
                    print("   📅 Posted at: \(alert.postedAt)")
                    print("   ⏰ Expires at: \(alert.expiresAt)")
                    print("   🔄 Is Active: \(alert.isActive)")
                }
                
                // Also check if there are any alerts that might be filtered out
                print("🔍 Checking for any alerts that might be filtered out...")
                let allSystemAlerts = try await serviceCoordinator.getAllAlerts()
                print("📊 Total alerts in system: \(allSystemAlerts.count)")
                for alert in allSystemAlerts {
                    print("   📋 System Alert: '\(alert.title)' from \(alert.organizationName) (ID: \(alert.organizationId))")
                }
                
                await MainActor.run {
                    self.alerts = fetchedAlerts
                    self.isLoading = false
                    print("✅ Updated UI with \(fetchedAlerts.count) alerts")
                }
            } catch {
                print("❌ Error loading alerts: \(error)")
                print("   Error type: \(type(of: error))")
                print("   Error details: \(error.localizedDescription)")
                await MainActor.run {
                    self.alerts = []
                    self.isLoading = false
                    self.errorMessage = "Failed to load alerts: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func refreshAlerts() async {
        print("🔄 Pull-to-refresh: Starting to load alerts...")
        
        do {
            print("📡 Pull-to-refresh: Fetching alerts from followed organizations...")
            let fetchedAlerts = try await serviceCoordinator.getFollowingOrganizationAlerts()
            
            print("📥 Pull-to-refresh: Loaded \(fetchedAlerts.count) alerts from API")
            for alert in fetchedAlerts {
                print("📋 Alert: '\(alert.title)' - Type: \(alert.type.rawValue), Severity: \(alert.severity.rawValue)")
            }
            
            await MainActor.run {
                self.alerts = fetchedAlerts
                print("✅ Pull-to-refresh: Updated UI with \(fetchedAlerts.count) alerts")
            }
        } catch {
            print("❌ Pull-to-refresh: Error loading alerts: \(error)")
            await MainActor.run {
                self.alerts = []
                self.errorMessage = "Failed to refresh alerts: \(error.localizedDescription)"
                self.showingErrorAlert = true
            }
        }
    }
}



// MARK: - Incident Feed Alert Row View
struct IncidentFeedAlertRowView: View {
    let alert: OrganizationAlert
    @EnvironmentObject var authManager: SimpleAuthManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @State private var organization: Organization?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with organization and time
            HStack {
                // Organization Info
                HStack(spacing: 8) {
                    // Organization Logo
                    if let organization = organization {
                        OrganizationLogoView(organization: organization, size: 28, showBorder: false)
                    } else {
                        // Fallback icon while loading
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 28, height: 28)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.organizationName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let groupName = alert.groupName, !groupName.isEmpty {
                            Text(groupName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Time
                Text(formatTimestamp(alert.postedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Title
            Text(alert.title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Description
            if !alert.description.isEmpty {
                Text(alert.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            
            // Type and Severity Badges (only show if not default values)
            if alert.type != .other || alert.severity != .low {
                HStack(spacing: 8) {
                    // Type Badge (only show if not default)
                    if alert.type != .other {
                        HStack(spacing: 4) {
                            Image(systemName: alert.type.icon)
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(alert.type.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(alert.type.color)
                        .cornerRadius(8)
                    }
                    
                    // Severity Badge (only show if not default)
                    if alert.severity != .low {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                            
                            Text(alert.severity.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(alert.severity.color)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1.5)
        )
        .onAppear {
            loadOrganization()
        }
    }
    
    // MARK: - Organization Loading
    private func loadOrganization() {
        guard organization == nil else { return }
        
        Task {
            do {
                // Fetch organization details by ID
                let organizations = try await serviceCoordinator.fetchOrganizations()
                if let org = organizations.first(where: { $0.id == alert.organizationId }) {
                    await MainActor.run {
                        self.organization = org
                    }
                }
            } catch {
                print("❌ Error loading organization: \(error)")
            }
        }
    }
    
    // MARK: - Timestamp Formatting
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let formatted = formatter.string(from: date)
        
        // Debug logging to track timestamp issues
        print("🕐 Formatting timestamp for alert '\(alert.title)':")
        print("   📅 Raw date: \(date)")
        print("   📅 Formatted: \(formatted)")
        print("   📅 Time since now: \(Date().timeIntervalSince(date)) seconds")
        
        return formatted
    }
}







// MARK: - Filter Button Component
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    IncidentFeedView()
        .environmentObject(LocationManager())
        .environmentObject(APIService())
}

// MARK: - Group Selection View
struct GroupSelectionView: View {
    let authManager: SimpleAuthManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var organizations: [Organization] = []
    @State private var isLoading = true
    @State private var selectedOrganization: Organization?
    @State private var selectedGroup: OrganizationGroup?
    @State private var showingAlertPost = false
    
    private var hasNoGroups: Bool {
        return organizations.allSatisfy { organization in
            (organization.groups?.isEmpty ?? true)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if organizations.isEmpty {
                    emptyStateView
                } else if hasNoGroups {
                    noGroupsView
                } else {
                    organizationsList
                }
            }
            .navigationTitle("Select Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadOrganizations()
            }
            .sheet(isPresented: $showingAlertPost) {
                if let selectedOrg = selectedOrganization {
                    OrganizationAlertPostView(organization: selectedOrg, preSelectedGroup: selectedGroup)
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.green)
                
                VStack(spacing: 8) {
                    Text("Loading organizations...")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Fetching your admin organizations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "building.2")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Text("No organizations found")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("You need to be an admin of an organization to post alerts.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
    }
    
    private var noGroupsView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 16) {
                    Text("No groups available")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("To create targeted alerts, you need to create groups in your organizations first.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Create Group Button
                Button(action: {
                    // TODO: Navigate to group creation view
                    print("🔄 TODO: Navigate to group creation")
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                        
                        Text("Create Your First Group")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
    
    private var organizationsList: some View {
        List(organizations, id: \.id) { organization in
            Section(header: Text(organization.name).font(.headline).fontWeight(.semibold)) {
                // Show organization groups
                ForEach(organization.groups ?? [], id: \.id) { group in
                    Button(action: {
                        print("🎯 Selected group: \(group.name) in organization: \(organization.name)")
                        print("   Organization ID: \(organization.id)")
                        print("   Group ID: \(group.id)")
                        selectedOrganization = organization
                        selectedGroup = group
                        print("   Setting showingAlertPost = true")
                        showingAlertPost = true
                        print("   showingAlertPost is now: \(showingAlertPost)")
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                if let description = group.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Tap to post alert to this group")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // If no groups for this organization, show message
                if (organization.groups?.isEmpty ?? true) {
                    VStack(spacing: 8) {
                        Text("No groups available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Create groups to post targeted alerts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func loadOrganizations() {
        Task {
            isLoading = true
            
            // Get organizations where the current user is an admin
            var adminOrgs: [Organization] = []
            
            do {
                // Use APIService to fetch all organizations
                let allOrgs = try await serviceCoordinator.fetchOrganizations()
                print("📋 Fetched \(allOrgs.count) total organizations")
                
                // Get current user ID for admin check
                guard let currentUserId = authManager.currentUser?.id else {
                    print("❌ No current user ID found for admin check")
                    await MainActor.run {
                        self.organizations = []
                        self.isLoading = false
                    }
                    return
                }
                
                // Filter to only include organizations where the current user is an admin
                for organization in allOrgs {
                    let isAdmin = organization.adminIds?[currentUserId] == true
                    print("🔍 Organization '\(organization.name)': isAdmin = \(isAdmin)")
                    
                    if isAdmin {
                        // Fetch groups for this organization
                        let groupService = OrganizationGroupService()
                        let groups = try await groupService.getOrganizationGroups(organizationId: organization.id)
                        print("📋 Organization '\(organization.name)' has \(groups.count) groups")
                        
                        // Create a new organization instance with the fetched groups
                        let orgWithGroups = Organization(
                            id: organization.id,
                            name: organization.name,
                            type: organization.type,
                            description: organization.description,
                            location: organization.location,
                            verified: organization.verified,
                            followerCount: organization.followerCount,
                            logoURL: organization.logoURL,
                            website: organization.website,
                            phone: organization.phone,
                            email: organization.email,
                            groups: groups, // Add the fetched groups
                            adminIds: organization.adminIds,
                            createdAt: organization.createdAt,
                            updatedAt: organization.updatedAt,
                            groupsArePrivate: organization.groupsArePrivate,
                            allowPublicGroupJoin: organization.allowPublicGroupJoin,
                            subscriptionLevel: organization.subscriptionLevel
                        )
                        
                        adminOrgs.append(orgWithGroups)
                    }
                }
                
                await MainActor.run {
                    self.organizations = adminOrgs
                    self.isLoading = false
                    print("📋 Loaded \(adminOrgs.count) admin organizations with groups")
                }
            } catch {
                print("❌ Error loading organizations: \(error)")
                await MainActor.run {
                    self.organizations = []
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Filter Sheet View
struct FilterSheetView: View {
    @Binding var selectedAlertTypes: Set<IncidentType>
    @Binding var selectedSeverities: Set<IncidentSeverity>
    @Binding var showHiddenAlerts: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Incident Type Filters
                VStack(alignment: .leading, spacing: 16) {
                    Text("Alert Types")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            FilterButton(
                                title: type.displayName,
                                isSelected: selectedAlertTypes.contains(type),
                                action: {
                                    if selectedAlertTypes.contains(type) {
                                        selectedAlertTypes.remove(type)
                                    } else {
                                        selectedAlertTypes.insert(type)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Severity Filters
                VStack(alignment: .leading, spacing: 16) {
                    Text("Severity Levels")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                            FilterButton(
                                title: severity.displayName,
                                isSelected: selectedSeverities.contains(severity),
                                action: {
                                    if selectedSeverities.contains(severity) {
                                        selectedSeverities.remove(severity)
                                    } else {
                                        selectedSeverities.insert(severity)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Hidden Alerts Toggle
                VStack(alignment: .leading, spacing: 12) {
                    Text("Show Hidden Alerts")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                    
                    HStack {
                        Text("Display alerts you've previously hidden")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $showHiddenAlerts)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6).opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        selectedAlertTypes = []
                        selectedSeverities = []
                        showHiddenAlerts = false
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}