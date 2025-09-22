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
            "memberCount": 0,
            "isPrivate": group.isPrivate,
            "allowPublicJoin": group.allowPublicJoin
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
        let isPrivate = data["isPrivate"] as? Bool ?? false
        let allowPublicJoin = data["allowPublicJoin"] as? Bool ?? true
        
        return OrganizationGroup(
            id: id,
            name: name,
            description: description,
            organizationId: organizationId,
            isActive: isActive,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPrivate: isPrivate,
            allowPublicJoin: allowPublicJoin
        )
    }
    
    // MARK: - Group Invitation Management
    func sendGroupInvitation(
        organizationId: String,
        organizationName: String,
        groupId: String,
        groupName: String,
        invitedUserId: String,
        invitedUserEmail: String? = nil,
        invitedUserName: String? = nil,
        message: String? = nil,
        invitedByUserId: String,
        invitedByName: String
    ) async throws -> String {
        let invitation = GroupInvitation(
            organizationId: organizationId,
            organizationName: organizationName,
            groupId: groupId,
            groupName: groupName,
            invitedUserId: invitedUserId,
            invitedUserEmail: invitedUserEmail,
            invitedUserName: invitedUserName,
            invitedByUserId: invitedByUserId,
            invitedByName: invitedByName,
            message: message
        )
        
        let db = Firestore.firestore()
        let docRef = try await db.collection("groupInvitations").addDocument(data: invitation.toFirestoreData())
        return docRef.documentID
    }
    
    func getUserInvitations(userId: String) async throws -> [GroupInvitation] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("groupInvitations")
            .whereField("invitedUserId", isEqualTo: userId)
            .getDocuments()
        
        let invitations = snapshot.documents.compactMap { document in
            try? document.data(as: GroupInvitation.self)
        }
        
        // Sort manually to avoid needing a composite index
        return invitations.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getOrganizationInvitations(organizationId: String) async throws -> [GroupInvitation] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("groupInvitations")
            .whereField("organizationId", isEqualTo: organizationId)
            .getDocuments()
        
        let invitations = snapshot.documents.compactMap { document in
            try? document.data(as: GroupInvitation.self)
        }
        
        // Sort manually to avoid needing a composite index
        return invitations.sorted { $0.createdAt > $1.createdAt }
    }
    
    func respondToInvitation(invitationId: String, status: InvitationStatus) async throws {
        let db = Firestore.firestore()
        
        print("📝 Responding to invitation: \(invitationId) with status: \(status.rawValue)")
        
        // First, check if the document exists
        let docRef = db.collection("groupInvitations").document(invitationId)
        let docSnapshot = try await docRef.getDocument()
        
        if !docSnapshot.exists {
            print("❌ Invitation document does not exist: \(invitationId)")
            throw NSError(domain: "InvitationError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invitation not found or has been deleted"])
        }
        
        let updateData: [String: Any] = [
            "status": status.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ]
        
        try await docRef.updateData(updateData)
        print("✅ Successfully updated invitation status")
        
        // If accepted, add user to the group
        if status == .accepted {
            try await addUserToGroup(invitationId: invitationId)
        }
    }
    
    func cancelInvitation(invitationId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("groupInvitations")
            .document(invitationId)
            .updateData([
                "status": InvitationStatus.cancelled.rawValue,
                "respondedAt": FieldValue.serverTimestamp()
            ])
    }
    
    private func addUserToGroup(invitationId: String) async throws {
        let db = Firestore.firestore()
        // Get the invitation details
        let invitationDoc = try await db.collection("groupInvitations")
            .document(invitationId)
            .getDocument()
        
        guard let invitation = try? invitationDoc.data(as: GroupInvitation.self) else {
            throw NSError(domain: "OrganizationGroupService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invitation not found"])
        }
        
        // Add user to the group's members subcollection
        let memberData: [String: Any] = [
            "userId": invitation.invitedUserId,
            "userName": invitation.invitedUserName ?? "",
            "userEmail": invitation.invitedUserEmail ?? "",
            "joinedAt": FieldValue.serverTimestamp(),
            "isActive": true
        ]
        
        try await db.collection("organizations")
            .document(invitation.organizationId)
            .collection("groups")
            .document(invitation.groupId)
            .collection("members")
            .document(invitation.invitedUserId)
            .setData(memberData)
        
        // Update group member count
        try await updateGroupMemberCount(organizationId: invitation.organizationId, groupId: invitation.groupId)
    }
    
    private func updateGroupMemberCount(organizationId: String, groupId: String) async throws {
        let db = Firestore.firestore()
        let membersSnapshot = try await db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupId)
            .collection("members")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        let memberCount = membersSnapshot.documents.count
        
        try await db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupId)
            .updateData([
                "memberCount": memberCount,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }
    
    func removeUserFromGroup(organizationId: String, groupId: String, userId: String) async throws {
        let db = Firestore.firestore()
        // Mark user as inactive in the group
        try await db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupId)
            .collection("members")
            .document(userId)
            .updateData([
                "isActive": false,
                "leftAt": FieldValue.serverTimestamp()
            ])
        
        // Update group member count
        try await updateGroupMemberCount(organizationId: organizationId, groupId: groupId)
    }
    
    func isUserGroupMember(organizationId: String, groupId: String, userId: String) async throws -> Bool {
        let db = Firestore.firestore()
        let memberDoc = try await db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupId)
            .collection("members")
            .document(userId)
            .getDocument()
        
        guard let data = memberDoc.data(),
              let isActive = data["isActive"] as? Bool else {
            return false
        }
        
        return isActive
    }
    
    func getGroupMembers(organizationId: String, groupId: String) async throws -> [[String: Any]] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(groupId)
            .collection("members")
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
}

// MARK: - GroupInvitation Extension
extension GroupInvitation {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "organizationId": organizationId,
            "organizationName": organizationName,
            "groupId": groupId,
            "groupName": groupName,
            "invitedUserId": invitedUserId,
            "invitedByUserId": invitedByUserId,
            "invitedByName": invitedByName,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt),
            "expiresAt": Timestamp(date: expiresAt)
        ]
        
        if let invitedUserEmail = invitedUserEmail {
            data["invitedUserEmail"] = invitedUserEmail
        }
        
        if let invitedUserName = invitedUserName {
            data["invitedUserName"] = invitedUserName
        }
        
        if let message = message {
            data["message"] = message
        }
        
        if let respondedAt = respondedAt {
            data["respondedAt"] = Timestamp(date: respondedAt)
        }
        
        return data
    }
}
