import Foundation

// MARK: - Organization Update Types
enum OrganizationUpdateType: String, CaseIterable {
    case profileUpdated = "profile_updated"
    case groupCreated = "group_created"
    case groupUpdated = "group_updated"
    case groupDeleted = "group_deleted"
    case adminAdded = "admin_added"
    case adminRemoved = "admin_removed"
    case settingsUpdated = "settings_updated"
    case subscriptionUpdated = "subscription_updated"
    
    var displayName: String {
        switch self {
        case .profileUpdated: return "Profile Updated"
        case .groupCreated: return "New Group Created"
        case .groupUpdated: return "Group Updated"
        case .groupDeleted: return "Group Deleted"
        case .adminAdded: return "Admin Added"
        case .adminRemoved: return "Admin Removed"
        case .settingsUpdated: return "Settings Updated"
        case .subscriptionUpdated: return "Subscription Updated"
        }
    }
}

// MARK: - Organization Update Data
struct OrganizationUpdateData {
    let organizationId: String
    let organizationName: String
    let updateType: OrganizationUpdateType
    let updatedBy: String
    let updatedByEmail: String
    let updateDetails: [String: Any]
    let timestamp: Date
}
