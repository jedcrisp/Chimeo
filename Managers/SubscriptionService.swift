//
//  SubscriptionService.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Subscription Service
class SubscriptionService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Subscription Management
    
    func updateOrganizationSubscription(organizationId: String, subscriptionLevel: SubscriptionLevel) async throws {
        print("💳 Updating organization subscription: \(organizationId) to \(subscriptionLevel.displayName)")
        
        let orgRef = db.collection("organizations").document(organizationId)
        
        let updateData: [String: Any] = [
            "subscriptionLevel": subscriptionLevel.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await orgRef.updateData(updateData)
        
        print("✅ Organization subscription updated successfully")
    }
    
    func getOrganizationSubscription(organizationId: String) async throws -> OrganizationSubscription? {
        print("💳 Getting organization subscription: \(organizationId)")
        
        let subscriptionRef = db.collection("organizations")
            .document(organizationId)
            .collection("subscription")
            .document("current")
        
        let doc = try await subscriptionRef.getDocument()
        
        if doc.exists, let data = doc.data() {
            let subscription = try parseOrganizationSubscriptionFromFirestore(document: doc, data: data)
            print("✅ Found subscription: \(subscription.subscriptionLevel.displayName)")
            return subscription
        } else {
            print("ℹ️ No subscription found, defaulting to free")
            return nil
        }
    }
    
    func createOrganizationSubscription(organizationId: String, subscriptionLevel: SubscriptionLevel, planId: String) async throws -> OrganizationSubscription {
        print("💳 Creating organization subscription: \(organizationId) to \(subscriptionLevel.displayName)")
        
        let subscription = OrganizationSubscription(
            organizationId: organizationId,
            subscriptionLevel: subscriptionLevel,
            planId: planId
        )
        
        let subscriptionRef = db.collection("organizations")
            .document(organizationId)
            .collection("subscription")
            .document("current")
        
        let subscriptionData: [String: Any] = [
            "id": subscription.id,
            "organizationId": organizationId,
            "subscriptionLevel": subscriptionLevel.rawValue,
            "planId": planId,
            "startDate": subscription.startDate,
            "endDate": subscription.endDate as Any,
            "isActive": subscription.isActive,
            "autoRenew": subscription.autoRenew,
            "createdAt": subscription.createdAt,
            "updatedAt": subscription.updatedAt
        ]
        
        try await subscriptionRef.setData(subscriptionData)
        
        // Also update the organization document
        try await updateOrganizationSubscription(organizationId: organizationId, subscriptionLevel: subscriptionLevel)
        
        print("✅ Organization subscription created successfully")
        return subscription
    }
    
    // MARK: - Sub-Group Management
    
    func createSubGroup(subGroup: SubGroup, organizationId: String, parentGroupId: String) async throws -> SubGroup {
        print("👥 Creating sub-group: \(subGroup.name) under parent group: \(parentGroupId)")
        
        // Check subscription limits
        let canCreate = try await canCreateSubGroup(organizationId: organizationId, parentGroupId: parentGroupId)
        guard canCreate else {
            throw SubscriptionError.subGroupLimitExceeded
        }
        
        let subGroupData: [String: Any] = [
            "id": subGroup.id,
            "name": subGroup.name,
            "description": subGroup.description ?? "",
            "parentGroupId": parentGroupId,
            "organizationId": organizationId,
            "isActive": subGroup.isActive,
            "isPrivate": subGroup.isPrivate,
            "allowPublicJoin": subGroup.allowPublicJoin,
            "memberCount": subGroup.memberCount,
            "createdAt": subGroup.createdAt,
            "updatedAt": subGroup.updatedAt
        ]
        
        // Create in sub-collection: organizations/{orgId}/groups/{groupId}/subGroups/{subGroupId}
        let subGroupRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(parentGroupId)
            .collection("subGroups")
            .document(subGroup.id)
        
        try await subGroupRef.setData(subGroupData)
        
        print("✅ Sub-group created successfully")
        return subGroup
    }
    
    func getSubGroups(organizationId: String, parentGroupId: String) async throws -> [SubGroup] {
        print("👥 Getting sub-groups for organization: \(organizationId), parent group: \(parentGroupId)")
        
        let subGroupsRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
            .document(parentGroupId)
            .collection("subGroups")
        
        let snapshot = try await subGroupsRef.getDocuments()
        print("📊 Found \(snapshot.documents.count) sub-groups")
        
        var subGroups: [SubGroup] = []
        
        for document in snapshot.documents {
            do {
                let data = document.data()
                let subGroup = try parseSubGroupFromFirestore(document: document, data: data)
                subGroups.append(subGroup)
                print("✅ Successfully parsed sub-group: \(subGroup.name)")
            } catch {
                print("⚠️ Error parsing sub-group \(document.documentID): \(error)")
                continue
            }
        }
        
        return subGroups
    }
    
    func canCreateSubGroup(organizationId: String, parentGroupId: String) async throws -> Bool {
        print("🔍 Checking if can create sub-group for organization: \(organizationId)")
        
        // Get organization subscription level
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        
        guard orgDoc.exists, let data = orgDoc.data() else {
            print("❌ Organization not found")
            return false
        }
        
        let subscriptionLevelRaw = data["subscriptionLevel"] as? String ?? "free"
        let subscriptionLevel = SubscriptionLevel(rawValue: subscriptionLevelRaw) ?? .free
        let features = SubscriptionFeatures.features(for: subscriptionLevel)
        
        // Check if sub-groups are allowed
        guard features.maxSubGroups > 0 else {
            print("❌ Sub-groups not allowed for \(subscriptionLevel.displayName) subscription")
            return false
        }
        
        // Check current sub-group count
        let currentSubGroups = try await getSubGroups(organizationId: organizationId, parentGroupId: parentGroupId)
        let currentCount = currentSubGroups.count
        
        // Check if under limit (unlimited = -1)
        let canCreate = features.maxSubGroups == -1 || currentCount < features.maxSubGroups
        
        print("📊 Sub-group limit check:")
        print("   Subscription: \(subscriptionLevel.displayName)")
        print("   Max sub-groups: \(features.maxSubGroups == -1 ? "Unlimited" : String(features.maxSubGroups))")
        print("   Current count: \(currentCount)")
        print("   Can create: \(canCreate)")
        
        return canCreate
    }
    
    func canCreateGroup(organizationId: String) async throws -> Bool {
        print("🔍 Checking if can create group for organization: \(organizationId)")
        
        // Get organization subscription level
        let orgDoc = try await db.collection("organizations").document(organizationId).getDocument()
        
        guard orgDoc.exists, let data = orgDoc.data() else {
            print("❌ Organization not found")
            return false
        }
        
        let subscriptionLevelRaw = data["subscriptionLevel"] as? String ?? "free"
        let subscriptionLevel = SubscriptionLevel(rawValue: subscriptionLevelRaw) ?? .free
        let features = SubscriptionFeatures.features(for: subscriptionLevel)
        
        // Check current group count
        let currentGroups = try await getOrganizationGroups(organizationId: organizationId)
        let currentCount = currentGroups.count
        
        // Check if under limit (unlimited = -1)
        let canCreate = features.maxGroups == -1 || currentCount < features.maxGroups
        
        print("📊 Group limit check:")
        print("   Subscription: \(subscriptionLevel.displayName)")
        print("   Max groups: \(features.maxGroups == -1 ? "Unlimited" : String(features.maxGroups))")
        print("   Current count: \(currentCount)")
        print("   Can create: \(canCreate)")
        
        return canCreate
    }
    
    // MARK: - Helper Methods
    
    private func getOrganizationGroups(organizationId: String) async throws -> [OrganizationGroup] {
        let groupsRef = db.collection("organizations")
            .document(organizationId)
            .collection("groups")
        
        let snapshot = try await groupsRef.getDocuments()
        var groups: [OrganizationGroup] = []
        
        for document in snapshot.documents {
            let data = document.data()
            let group = try parseOrganizationGroupFromFirestore(document: document, data: data)
            groups.append(group)
        }
        
        return groups
    }
    
    private func parseOrganizationSubscriptionFromFirestore(document: DocumentSnapshot, data: [String: Any]) throws -> OrganizationSubscription {
        guard let id = data["id"] as? String,
              let organizationId = data["organizationId"] as? String,
              let subscriptionLevelRaw = data["subscriptionLevel"] as? String,
              let subscriptionLevel = SubscriptionLevel(rawValue: subscriptionLevelRaw),
              let planId = data["planId"] as? String,
              let startDate = data["startDate"] as? Date,
              let isActive = data["isActive"] as? Bool,
              let autoRenew = data["autoRenew"] as? Bool,
              let createdAt = data["createdAt"] as? Date,
              let updatedAt = data["updatedAt"] as? Date else {
            throw SubscriptionError.invalidSubscriptionData
        }
        
        let endDate = data["endDate"] as? Date
        
        return OrganizationSubscription(
            id: id,
            organizationId: organizationId,
            subscriptionLevel: subscriptionLevel,
            planId: planId,
            startDate: startDate,
            endDate: endDate,
            isActive: isActive,
            autoRenew: autoRenew,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func parseSubGroupFromFirestore(document: DocumentSnapshot, data: [String: Any]) throws -> SubGroup {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let parentGroupId = data["parentGroupId"] as? String,
              let organizationId = data["organizationId"] as? String,
              let isActive = data["isActive"] as? Bool,
              let memberCount = data["memberCount"] as? Int,
              let createdAt = data["createdAt"] as? Date,
              let updatedAt = data["updatedAt"] as? Date else {
            throw SubscriptionError.invalidSubGroupData
        }
        
        let description = data["description"] as? String
        let isPrivate = data["isPrivate"] as? Bool ?? false
        let allowPublicJoin = data["allowPublicJoin"] as? Bool ?? true
        
        return SubGroup(
            id: id,
            name: name,
            description: description,
            parentGroupId: parentGroupId,
            organizationId: organizationId,
            isActive: isActive,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPrivate: isPrivate,
            allowPublicJoin: allowPublicJoin
        )
    }
    
    private func parseOrganizationGroupFromFirestore(document: DocumentSnapshot, data: [String: Any]) throws -> OrganizationGroup {
        guard let name = data["name"] as? String,
              let organizationId = data["organizationId"] as? String,
              let isActive = data["isActive"] as? Bool,
              let memberCount = data["memberCount"] as? Int,
              let createdAt = data["createdAt"] as? Date,
              let updatedAt = data["updatedAt"] as? Date else {
            throw SubscriptionError.invalidGroupData
        }
        
        let description = data["description"] as? String
        let isPrivate = data["isPrivate"] as? Bool ?? false
        let allowPublicJoin = data["allowPublicJoin"] as? Bool ?? true
        
        return OrganizationGroup(
            id: document.documentID,
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
}
