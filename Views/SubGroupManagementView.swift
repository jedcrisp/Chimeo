//
//  SubGroupManagementView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct SubGroupManagementView: View {
    let organization: Organization
    let parentGroup: OrganizationGroup
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var subGroups: [SubGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateSubGroup = false
    @State private var newSubGroupName = ""
    @State private var newSubGroupDescription = ""
    @State private var newSubGroupIsPrivate = false
    @State private var newSubGroupAllowPublicJoin = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading sub-groups...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if subGroups.isEmpty {
                    EmptySubGroupsView(
                        organization: organization,
                        parentGroup: parentGroup,
                        onCreateSubGroup: {
                            showingCreateSubGroup = true
                        }
                    )
                } else {
                    List {
                        ForEach(subGroups) { subGroup in
                            SubGroupRow(subGroup: subGroup)
                        }
                        .onDelete(perform: deleteSubGroup)
                    }
                }
            }
            .navigationTitle("Sub-Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateSubGroup = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(!canCreateSubGroup)
                }
            }
            .sheet(isPresented: $showingCreateSubGroup) {
                CreateSubGroupView(
                    organization: organization,
                    parentGroup: parentGroup,
                    onSubGroupCreated: { subGroup in
                        subGroups.append(subGroup)
                    }
                )
            }
            .onAppear {
                loadSubGroups()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var canCreateSubGroup: Bool {
        organization.subscriptionFeatures.maxSubGroups > 0
    }
    
    private func loadSubGroups() {
        Task {
            isLoading = true
            do {
                subGroups = try await subscriptionService.getSubGroups(
                    organizationId: organization.id,
                    parentGroupId: parentGroup.id
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func deleteSubGroup(at offsets: IndexSet) {
        // TODO: Implement sub-group deletion
    }
}

struct EmptySubGroupsView: View {
    let organization: Organization
    let parentGroup: OrganizationGroup
    let onCreateSubGroup: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Sub-Groups Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create sub-groups to organize members within \(parentGroup.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if organization.subscriptionFeatures.maxSubGroups > 0 {
                Button(action: onCreateSubGroup) {
                    Text("Create Sub-Group")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            } else {
                VStack(spacing: 8) {
                    Text("Sub-Groups Not Available")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    Text("Upgrade to Pro or Enterprise to create sub-groups")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("View Plans") {
                        // TODO: Navigate to subscription plans
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }
}

struct SubGroupRow: View {
    let subGroup: SubGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subGroup.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = subGroup.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(subGroup.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        if subGroup.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if !subGroup.allowPublicJoin {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            HStack {
                Text("Created \(subGroup.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if subGroup.isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateSubGroupView: View {
    let organization: Organization
    let parentGroup: OrganizationGroup
    let onSubGroupCreated: (SubGroup) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var name = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var allowPublicJoin = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sub-Group Details") {
                    TextField("Name", text: $name)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Privacy Settings") {
                    Toggle("Private Group", isOn: $isPrivate)
                    
                    Toggle("Allow Public Join", isOn: $allowPublicJoin)
                        .disabled(isPrivate)
                }
                
                Section {
                    Button(action: createSubGroup) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isCreating ? "Creating..." : "Create Sub-Group")
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
            .navigationTitle("Create Sub-Group")
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
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func createSubGroup() {
        Task {
            isCreating = true
            do {
                let subGroup = SubGroup(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    parentGroupId: parentGroup.id,
                    organizationId: organization.id,
                    isPrivate: isPrivate,
                    allowPublicJoin: allowPublicJoin
                )
                
                let createdSubGroup = try await subscriptionService.createSubGroup(
                    subGroup: subGroup,
                    organizationId: organization.id,
                    parentGroupId: parentGroup.id
                )
                
                await MainActor.run {
                    onSubGroupCreated(createdSubGroup)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    SubGroupManagementView(
        organization: Organization(
            name: "Test Organization",
            type: "Emergency Services",
            location: Location(latitude: 0, longitude: 0),
            subscriptionLevel: .pro
        ),
        parentGroup: OrganizationGroup(
            name: "Emergency Response",
            organizationId: "test-org-id"
        )
    )
}
