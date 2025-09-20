import Foundation
import FirebaseFirestore

// MARK: - Organization Group Service
class OrganizationGroupService: ObservableObject {
    
    // MARK: - Group Management
    func createOrganizationGroup(group: OrganizationGroup, organizationId: String) async throws -> OrganizationGroup {
        print("🏢 Creating organization group: \(group.name)")
        print("   🔍 Organization ID being used: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // First, verify the organization exists and get the correct document ID
        print("   🔍 Verifying organization exists...")
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        
        if !orgDoc.exists {
            print("   ❌ Organization document not found with ID: \(organizationId)")
            print("   🔍 Trying to find organization by name...")
            
            // Try to find by name as fallback
            let orgNameQuery = try await db.collection("organizations")
                .whereField("name", isEqualTo: organizationId.replacingOccurrences(of: "_", with: " "))
                .getDocuments()
            
            if let foundOrgDoc = orgNameQuery.documents.first {
                let actualOrgId = foundOrgDoc.documentID
                print("   ✅ Found organization by name: \(actualOrgId)")
                print("   🔄 Using actual organization ID: \(actualOrgId)")
                // Update the organizationId to use the correct one
                let updatedGroup = OrganizationGroup(
                    id: group.id,
                    name: group.name,
                    description: group.description,
                    organizationId: actualOrgId,
                    isActive: group.isActive,
                    memberCount: group.memberCount,
                    createdAt: group.createdAt,
                    updatedAt: group.updatedAt
                )
                // Recursively call with the correct organization ID
                return try await createOrganizationGroup(group: updatedGroup, organizationId: actualOrgId)
            } else {
                print("   ❌ Organization not found by name either")
                throw NSError(domain: "GroupCreationError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization not found"])
            }
        } else {
            let orgData = orgDoc.data() ?? [:]
            let orgName = orgData["name"] as? String ?? "Unknown"
            print("   ✅ Organization found: \(orgName) (ID: \(organizationId))")
        }
        
        // Create the group data
        let groupData: [String: Any] = [
            "name": group.name,
            "description": group.description ?? "",
            "organizationId": organizationId,
            "isActive": group.isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "memberCount": 0
        ]
        
        print("   📝 Creating group in subcollection: organizations/\(organizationId)/groups/\(group.name)")
        
        // Add to the organization's groups subcollection using group name as document ID
        let groupRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(group.name)
        try await groupRef.setData(groupData)
        
        // Get the created document to return the complete group
        let createdDoc = try await groupRef.getDocument()
        let createdData = createdDoc.data() ?? [:]
        
        let createdGroup = OrganizationGroup(
            id: group.name, // Use group name as ID
            name: group.name,
            description: group.description,
            organizationId: organizationId,
            isActive: group.isActive,
            memberCount: 0,
            createdAt: (createdData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (createdData["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
        
        print("✅ Successfully created organization group: \(createdGroup.name) (ID: \(createdGroup.id))")
        print("   📍 Location: organizations/\(organizationId)/groups/\(group.name)")
        return createdGroup
    }
    
    func updateOrganizationGroup(_ group: OrganizationGroup) async throws {
        print("🏢 Updating organization group: \(group.name)")
        print("   Group ID: \(group.id)")
        
        let db = Firestore.firestore()
        
        // Check if the group name has changed
        let originalName = group.id // The ID contains the original name
        let newName = group.name
        
        if originalName != newName {
            print("   🔄 Group name changed from '\(originalName)' to '\(newName)'")
            
            // Get the original document data
            let originalRef = db.collection("organizations")
                .document(group.organizationId)
                .collection("groups")
                .document(originalName)
            
            let originalDoc = try await originalRef.getDocument()
            guard originalDoc.exists else {
                throw NSError(domain: "GroupUpdateError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Original group not found"])
            }
            
            let originalData = originalDoc.data() ?? [:]
            
            // Create new document with updated data
            let newGroupData: [String: Any] = [
                "name": newName,
                "description": group.description ?? "",
                "organizationId": group.organizationId,
                "isActive": group.isActive,
                "createdAt": originalData["createdAt"] ?? FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "memberCount": originalData["memberCount"] ?? 0
            ]
            
            let newRef = db.collection("organizations")
                .document(group.organizationId)
                .collection("groups")
                .document(newName)
            
            // Create the new document
            try await newRef.setData(newGroupData)
            
            // Delete the old document
            try await originalRef.delete()
            
            print("✅ Successfully updated organization group: \(newName) (moved from \(originalName))")
        } else {
            // Name hasn't changed, just update the existing document
            let groupRef = db.collection("organizations")
                .document(group.organizationId)
                .collection("groups")
                .document(originalName)
            
            let updateData: [String: Any] = [
                "name": group.name,
                "description": group.description ?? "",
                "isActive": group.isActive,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await groupRef.updateData(updateData)
            print("✅ Successfully updated organization group: \(group.name)")
        }
    }
    
    func deleteOrganizationGroup(_ groupName: String, organizationId: String) async throws {
        print("🏢 Deleting organization group: \(groupName) from organization: \(organizationId)")
        
        let db = Firestore.firestore()
        let groupRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupName) // Use group name as document ID (this should work for existing groups)
        
        try await groupRef.delete()
        print("✅ Successfully deleted organization group: \(groupName)")
    }
    
    // MARK: - Group Fetching
    func getOrganizationGroups(organizationId: String) async throws -> [OrganizationGroup] {
        print("🔍 Fetching groups for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        let groupsRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
        
        let snapshot = try await groupsRef.getDocuments()
        
        var groups: [OrganizationGroup] = []
        
        for document in snapshot.documents {
            do {
                let data = document.data()
                let group = try parseOrganizationGroup(data: data, id: document.documentID)
                groups.append(group)
            } catch {
                print("⚠️ Warning: Could not parse group document \(document.documentID): \(error)")
            }
        }
        
        print("✅ Found \(groups.count) groups for organization \(organizationId)")
        return groups
    }
    
    // MARK: - Group Parsing
    private func parseOrganizationGroup(data: [String: Any], id: String) throws -> OrganizationGroup {
        let name = data["name"] as? String ?? "Unknown"
        let description = data["description"] as? String
        let organizationId = data["organizationId"] as? String ?? ""
        let isActive = data["isActive"] as? Bool ?? true
        let memberCount = data["memberCount"] as? Int ?? 0
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return OrganizationGroup(
            id: id,
            name: name,
            description: description,
            organizationId: organizationId,
            isActive: isActive,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
