import SwiftUI

struct OrganizationGroupManagementView: View {
    let organization: Organization
    @EnvironmentObject var apiService: APIService
    @State private var groups: [OrganizationGroup] = []
    @State private var isLoading = false
    @State private var showingCreateGroup = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var showingEditGroup = false
    @State private var editingGroup: OrganizationGroup?
    @State private var editGroupName = ""
    @State private var editGroupDescription = ""
    
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
                        
                        Text("Create your first group to organize your alerts")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingCreateGroup = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create First Group")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section(header: Text("Organization Groups")) {
                            ForEach(groups) { group in
                                GroupRowView(group: group) {
                                    editGroup(group)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteGroup(group)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: OrganizationGroupSettingsView(organization: organization)) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateGroup = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                loadGroups()
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView(organization: organization) { newGroup in
                    groups.append(newGroup)
                }
            }
            .sheet(isPresented: $showingEditGroup) {
                if let editingGroup = editingGroup {
                    EditGroupView(
                        group: editingGroup,
                        organization: organization,
                        onSave: { updatedGroup in
                            if let index = groups.firstIndex(where: { $0.id == updatedGroup.id }) {
                                groups[index] = updatedGroup
                            }
                        }
                    )
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    errorMessage = nil
                    showingErrorAlert = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func loadGroups() {
        print("🔧 OrganizationGroupManagementView: Loading groups for organization: \(organization.id)")
        isLoading = true
        
        Task {
            do {
                print("🔧 OrganizationGroupManagementView: Starting API call...")
                let fetchedGroups = try await apiService.getOrganizationGroups(organizationId: organization.id)
                print("🔧 OrganizationGroupManagementView: API call completed, got \(fetchedGroups.count) groups")
                
                await MainActor.run {
                    self.groups = fetchedGroups
                    self.isLoading = false
                    print("🔧 OrganizationGroupManagementView: Groups updated in UI")
                }
            } catch {
                print("❌ Error loading groups: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                    self.showingErrorAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func editGroup(_ group: OrganizationGroup) {
        editingGroup = group
        editGroupName = group.name
        editGroupDescription = group.description ?? ""
        showingEditGroup = true
    }
    
    private func deleteGroup(_ group: OrganizationGroup) {
        Task {
            do {
                try await apiService.deleteOrganizationGroup(group.name, organizationId: organization.id)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        groups.removeAll { $0.id == group.id }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete group: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct GroupRowView: View {
    let group: OrganizationGroup
    let onEdit: () -> Void
    
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
                        Text("0") // Default to 0 since memberCount might not be available
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    if group.isPrivate {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                            Text("Private")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.caption)
                            Text("Public")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                    
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
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditGroupView: View {
    let group: OrganizationGroup
    let organization: Organization
    let onSave: (OrganizationGroup) -> Void
    
    @EnvironmentObject var apiService: APIService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var groupName: String
    @State private var groupDescription: String
    @State private var isPrivate: Bool
    @State private var allowPublicJoin: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    init(group: OrganizationGroup, organization: Organization, onSave: @escaping (OrganizationGroup) -> Void) {
        self.group = group
        self.organization = organization
        self.onSave = onSave
        self._groupName = State(initialValue: group.name)
        self._groupDescription = State(initialValue: group.description ?? "")
        self._isPrivate = State(initialValue: group.isPrivate)
        self._allowPublicJoin = State(initialValue: group.allowPublicJoin)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Privacy Settings")) {
                    Toggle("Make Group Private", isOn: $isPrivate)
                        .onChange(of: isPrivate) { _, newValue in
                            if !newValue {
                                allowPublicJoin = true
                            }
                        }
                    
                    if isPrivate {
                        Toggle("Allow Public Join", isOn: $allowPublicJoin)
                        
                        Text("When a group is private, members must be manually invited by organization admins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGroup()
                    }
                    .disabled(isLoading || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    errorMessage = nil
                    showingErrorAlert = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func saveGroup() {
        isLoading = true
        
        Task {
            do {
                let updatedGroup = OrganizationGroup(
                    id: group.id,
                    name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: groupDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : groupDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    organizationId: organization.id,
                    isActive: group.isActive,
                    createdAt: group.createdAt,
                    updatedAt: Date(),
                    isPrivate: isPrivate,
                    allowPublicJoin: allowPublicJoin
                )
                
                try await apiService.updateOrganizationGroup(updatedGroup)
                
                await MainActor.run {
                    onSave(updatedGroup)
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update group: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isLoading = false
                }
            }
        }
    }
}

struct CreateGroupView: View {
    let organization: Organization
    let onGroupCreated: (OrganizationGroup) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var allowPublicJoin = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Privacy Settings")) {
                    Toggle("Make Group Private", isOn: $isPrivate)
                        .onChange(of: isPrivate) { _, newValue in
                            if !newValue {
                                allowPublicJoin = true
                            }
                        }
                    
                    if isPrivate {
                        Toggle("Allow Public Join", isOn: $allowPublicJoin)
                        
                        Text("When a group is private, members must be manually invited by organization admins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("Groups help organize your alerts and allow users to choose which types of notifications they want to receive.")) {
                    Button(action: createGroup) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Creating Group...")
                            }
                        } else {
                            Text("Create Group")
                        }
                    }
                    .disabled(groupName.isEmpty || isLoading)
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    errorMessage = nil
                    showingErrorAlert = false
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func createGroup() {
        guard !groupName.isEmpty else { return }
        
        isLoading = true
        
        let newGroup = OrganizationGroup(
            name: groupName,
            description: groupDescription.isEmpty ? nil : groupDescription,
            organizationId: organization.id,
            isPrivate: isPrivate,
            allowPublicJoin: allowPublicJoin
        )
        
        Task {
            do {
                let createdGroup = try await apiService.createOrganizationGroup(
                    group: newGroup,
                    organizationId: organization.id
                )
                
                await MainActor.run {
                    onGroupCreated(createdGroup)
                    dismiss()
                }
            } catch {
                print("❌ Error creating group: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to create group: \(error.localizedDescription)"
                    showingErrorAlert = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    OrganizationGroupManagementView(organization: Organization(
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
