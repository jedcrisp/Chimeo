import Foundation
import FirebaseFirestore
import FirebaseAuth

public class GroupInvitationService: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Send Invitation
    public func sendGroupInvitation(
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
            groupName: groupId,
            invitedUserId: invitedUserId,
            invitedUserEmail: invitedUserEmail,
            invitedUserName: invitedUserName,
            invitedByUserId: invitedByUserId,
            invitedByName: invitedByName,
            message: message
        )
        
        let docRef = try await db.collection("groupInvitations").addDocument(data: invitation.toFirestoreData())
        return docRef.documentID
    }
    
    // MARK: - Get User Invitations
    public func getUserInvitations(userId: String) async throws -> [GroupInvitation] {
        let snapshot = try await db.collection("groupInvitations")
            .whereField("invitedUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: GroupInvitation.self)
        }
    }
    
    // MARK: - Get Organization Invitations
    public func getOrganizationInvitations(organizationId: String) async throws -> [GroupInvitation] {
        let snapshot = try await db.collection("groupInvitations")
            .whereField("organizationId", isEqualTo: organizationId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: GroupInvitation.self)
        }
    }
    
    // MARK: - Respond to Invitation
    public func respondToInvitation(invitationId: String, status: InvitationStatus) async throws {
        let updateData: [String: Any] = [
            "status": status.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("groupInvitations")
            .document(invitationId)
            .updateData(updateData)
        
        // If accepted, add user to the group
        if status == .accepted {
            try await addUserToGroup(invitationId: invitationId)
        }
    }
    
    // MARK: - Cancel Invitation
    public func cancelInvitation(invitationId: String) async throws {
        try await db.collection("groupInvitations")
            .document(invitationId)
            .updateData([
                "status": InvitationStatus.cancelled.rawValue,
                "respondedAt": FieldValue.serverTimestamp()
            ])
    }
    
    // MARK: - Add User to Group
    private func addUserToGroup(invitationId: String) async throws {
        // Get the invitation details
        let invitationDoc = try await db.collection("groupInvitations")
            .document(invitationId)
            .getDocument()
        
        guard let invitation = try? invitationDoc.data(as: GroupInvitation.self) else {
            throw NSError(domain: "GroupInvitationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invitation not found"])
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
    
    // MARK: - Update Group Member Count
    private func updateGroupMemberCount(organizationId: String, groupId: String) async throws {
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
    
    // MARK: - Remove User from Group
    func removeUserFromGroup(organizationId: String, groupId: String, userId: String) async throws {
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
    
    // MARK: - Check if User is Group Member
    func isUserGroupMember(organizationId: String, groupId: String, userId: String) async throws -> Bool {
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
    
    // MARK: - Get Group Members
    func getGroupMembers(organizationId: String, groupId: String) async throws -> [[String: Any]] {
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
