import SwiftUI

struct OrganizationGroupManagementView: View {
    let organization: Organization
    @EnvironmentObject var apiService: APIService
    @State private var groups: [OrganizationGroup] = []
    @State private var isLoading = false
    @State private var showingCreateGroup = false
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
                                    // Edit group action
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
    
    private func loadGroups() {
        isLoading = true
        
        Task {
            do {
                let fetchedGroups = try await apiService.getOrganizationGroups(organizationId: organization.id)
                await MainActor.run {
                    self.groups = fetchedGroups
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading groups: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load groups: \(error.localizedDescription)"
                    self.isLoading = false
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
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete group: \(error.localizedDescription)"
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
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateGroupView: View {
    let organization: Organization
    let onGroupCreated: (OrganizationGroup) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
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
    
    private func createGroup() {
        guard !groupName.isEmpty else { return }
        
        isLoading = true
        
        let newGroup = OrganizationGroup(
            name: groupName,
            description: groupDescription.isEmpty ? nil : groupDescription,
            organizationId: organization.id,
            memberCount: 0
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
