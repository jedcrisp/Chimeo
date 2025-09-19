import SwiftUI

struct AdminOrganizationManagementView: View {
    @EnvironmentObject var apiService: APIService
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedFilter: OrganizationFilter = .all
    @State private var showingOrganizationDetail = false
    @State private var selectedOrganization: Organization?
    
    enum OrganizationFilter: String, CaseIterable {
        case all = "all"
        case verified = "verified"
        case unverified = "unverified"
        case active = "active"
        case inactive = "inactive"
        
        var displayName: String {
            switch self {
            case .all: return "All"
            case .verified: return "Verified"
            case .unverified: return "Unverified"
            case .active: return "Active"
            case .inactive: return "Inactive"
            }
        }
    }
    
    var filteredOrganizations: [Organization] {
        var filtered = organizations
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { org in
                org.name.localizedCaseInsensitiveContains(searchText) ||
                org.type.localizedCaseInsensitiveContains(searchText) ||
                (org.location.city?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .verified:
            filtered = filtered.filter { $0.verified }
        case .unverified:
            filtered = filtered.filter { !$0.verified }
        case .active:
            filtered = filtered.filter { $0.followerCount > 0 }
        case .inactive:
            filtered = filtered.filter { $0.followerCount == 0 }
        case .all:
            break
        }
        
        return filtered
    }
    
    var body: some View {
        VStack {
            // Search and Filter Bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search organizations...", text: $searchText)
                }
                .textFieldStyle(.roundedBorder)
                
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(OrganizationFilter.allCases, id: \.self) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            if isLoading {
                ProgressView("Loading organizations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredOrganizations.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "building.2")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No organizations found")
                        .font(.headline)
                    
                    if !searchText.isEmpty || selectedFilter != .all {
                        Text("Try adjusting your search or filters.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No organizations have been added to the platform yet.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredOrganizations) { organization in
                    OrganizationManagementRow(organization: organization) {
                        selectedOrganization = organization
                        showingOrganizationDetail = true
                    }
                }
            }
        }
        .navigationTitle("Manage Organizations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: syncAllFollowerCounts) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.orange)
                    }
                    .help("Sync all organization follower counts")
                    
                    Button(action: loadOrganizations) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh organizations")
                }
            }
        }
        .onAppear {
            loadOrganizations()
        }
        .sheet(isPresented: $showingOrganizationDetail) {
            if let organization = selectedOrganization {
                OrganizationManagementDetailView(organization: organization)
            }
        }
    }
    
    private func loadOrganizations() {
        isLoading = true
        
        Task {
            do {
                let orgs = try await apiService.fetchOrganizations()
                await MainActor.run {
                    self.organizations = orgs
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error loading organizations: \(error)")
                }
            }
        }
    }
    
    private func syncAllFollowerCounts() {
        print("🔄 Syncing all organization follower counts...")
        
        Task {
            do {
                try await apiService.syncAllOrganizationFollowerCounts()
                
                // Refresh the organizations list after sync
                await loadOrganizations()
                
                print("✅ Successfully synced all organization follower counts")
            } catch {
                print("❌ Failed to sync organization follower counts: \(error)")
            }
        }
    }
}

// MARK: - Organization Management Row
struct OrganizationManagementRow: View {
    let organization: Organization
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(organization.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if organization.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(organization.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let city = organization.location.city, let state = organization.location.state {
                        Text("\(city), \(state)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(organization.followerCount) followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let website = organization.website, !website.isEmpty {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Organization Management Detail View
struct OrganizationManagementDetailView: View {
    let organization: Organization
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(organization.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if organization.verified {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text("Verified")
                                        .foregroundColor(.green)
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        Text(organization.type)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Description
                    if let description = organization.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Contact Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let email = organization.email {
                                Text("Email: \(email)")
                            }
                            if let phone = organization.phone {
                                Text("Phone: \(phone)")
                            }
                            if let website = organization.website {
                                Link("Website: \(website)", destination: URL(string: website) ?? URL(string: "https://example.com")!)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        if let address = organization.location.address {
                            Text(address)
                        }
                        if let city = organization.location.city, let state = organization.location.state {
                            Text("\(city), \(state)")
                        }
                        if let zipCode = organization.location.zipCode {
                            Text(zipCode)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    
                    // Statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Statistics")
                            .font(.headline)
                        
                        HStack {
                            VStack {
                                Text("\(organization.followerCount)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text(organization.verified ? "Yes" : "No")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Verified")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            // Toggle verification status
                        }) {
                            HStack {
                                Image(systemName: organization.verified ? "xmark.circle" : "checkmark.circle")
                                Text(organization.verified ? "Remove Verification" : "Verify Organization")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(organization.verified ? .red : .green)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Organization")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Organization Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Organization", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteOrganization()
                }
            } message: {
                Text("Are you sure you want to delete '\(organization.name)'? This action cannot be undone.")
            }
        }
    }
    
    private func deleteOrganization() {
        isDeleting = true
        
        Task {
            do {
                _ = try await apiService.deleteOrganization(organization.id)
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    print("Error deleting organization: \(error)")
                }
            }
        }
    }
}

#Preview {
    AdminOrganizationManagementView()
        .environmentObject(APIService())
} 