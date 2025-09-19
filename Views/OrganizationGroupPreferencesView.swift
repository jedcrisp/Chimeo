import SwiftUI

struct OrganizationGroupPreferencesView: View {
    let organization: Organization
    @EnvironmentObject var apiService: APIService
    @State private var groups: [OrganizationGroup] = []
    @State private var userPreferences: [String: Bool] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading groups...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No groups created yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("This organization hasn't created any groups yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section(header: Text("Organization Groups")) {
                            ForEach(groups) { group in
                                GroupPreferenceRow(
                                    group: group,
                                    isEnabled: userPreferences[group.id] ?? false,
                                    onToggle: { isEnabled in
                                        toggleGroupPreference(groupId: group.id, isEnabled: isEnabled)
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteGroup(group)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        
                        Section(footer: Text("Toggle groups on/off to control which alerts you receive from this organization")) {
                            HStack {
                                Text("Follow All Groups")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("Enable All") {
                                    enableAllGroups()
                                }
                                .foregroundColor(.blue)
                                
                                Button("Disable All") {
                                    disableAllGroups()
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Group Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadGroupsAndPreferences()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func loadGroupsAndPreferences() {
        isLoading = true
        
        Task {
            do {
                // Load organization groups
                let fetchedGroups = try await apiService.getOrganizationGroups(organizationId: organization.id)
                
                // Load user preferences for this organization (placeholder for now)
                let preferences: [String: Bool] = [:]
                
                await MainActor.run {
                    self.groups = fetchedGroups
                    self.userPreferences = preferences
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading groups and preferences: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func toggleGroupPreference(groupId: String, isEnabled: Bool) {
        userPreferences[groupId] = isEnabled
        
        Task {
            do {
                // TODO: Implement updateUserGroupPreferences in APIService
                print("Would update group \(groupId) to \(isEnabled)")
            } catch {
                print("❌ Error updating group preference: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to update preference: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteGroup(_ group: OrganizationGroup) {
        Task {
            do {
                try await apiService.deleteOrganizationGroup(group.name, organizationId: organization.id)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        groups.removeAll { $0.id == group.id }
                        userPreferences.removeValue(forKey: group.id)
                    }
                }
            } catch {
                print("❌ Failed to delete group: \(error)")
            }
        }
    }
    
    private func enableAllGroups() {
        for group in groups {
            userPreferences[group.id] = true
        }
        
        Task {
            do {
                // TODO: Implement updateUserGroupPreferences in APIService
                print("Would update preferences: \(userPreferences)")
            } catch {
                print("❌ Error enabling all groups: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to enable all groups: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func disableAllGroups() {
        for group in groups {
            userPreferences[group.id] = false
        }
        
        Task {
            do {
                // TODO: Implement updateUserGroupPreferences in APIService
                print("Would update preferences: \(userPreferences)")
            } catch {
                print("❌ Error disabling all groups: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to disable all groups: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct GroupPreferenceRow: View {
    let group: OrganizationGroup
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(group.memberCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(group.createdAt, style: .date)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OrganizationGroupPreferencesView(organization: Organization(
        name: "Sample Organization",
        type: "business",
        description: "A sample organization for preview",
        location: Location(
            latitude: 0.0,
            longitude: 0.0,
            address: "123 Main St",
            city: "Sample City",
            state: "TX",
            zipCode: "12345"
        )
    ))
    .environmentObject(APIService())
}
