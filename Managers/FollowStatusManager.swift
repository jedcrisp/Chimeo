import Foundation
import SwiftUI
import Combine

// MARK: - Follow Status Manager
// Centralized manager for tracking and broadcasting follow/unfollow status changes
class FollowStatusManager: ObservableObject {
    static let shared = FollowStatusManager()
    
    // Published properties that all views can observe
    @Published var followStatusChanges: [String: Bool] = [:] // organizationId: isFollowing
    
    // Combine cancellables for cleanup
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Update follow status for an organization and broadcast the change
    func updateFollowStatus(organizationId: String, isFollowing: Bool) {
        DispatchQueue.main.async {
            self.followStatusChanges[organizationId] = isFollowing
            print("🔄 FollowStatusManager: Updated \(organizationId) to \(isFollowing)")
        }
    }
    
    /// Get current follow status for an organization
    func getFollowStatus(for organizationId: String) -> Bool? {
        return followStatusChanges[organizationId]
    }
    
    /// Clear follow status for an organization (e.g., when user logs out)
    func clearFollowStatus(for organizationId: String) {
        DispatchQueue.main.async {
            self.followStatusChanges.removeValue(forKey: organizationId)
        }
    }
    
    /// Clear all follow statuses (e.g., when user logs out)
    func clearAllFollowStatuses() {
        DispatchQueue.main.async {
            self.followStatusChanges.removeAll()
        }
    }
    
    /// Batch update multiple follow statuses
    func batchUpdateFollowStatuses(_ updates: [String: Bool]) {
        DispatchQueue.main.async {
            for (orgId, isFollowing) in updates {
                self.followStatusChanges[orgId] = isFollowing
            }
            print("🔄 FollowStatusManager: Batch updated \(updates.count) organizations")
        }
    }
}

// MARK: - Follow Status Observer
// Protocol that views can conform to for automatic follow status updates
protocol FollowStatusObserver: ObservableObject {
    var followStatusManager: FollowStatusManager { get }
    func updateFollowStatus(for organizationId: String, isFollowing: Bool)
}

extension FollowStatusObserver {
    var followStatusManager: FollowStatusManager {
        FollowStatusManager.shared
    }
    
    func updateFollowStatus(for organizationId: String, isFollowing: Bool) {
        followStatusManager.updateFollowStatus(organizationId: organizationId, isFollowing: isFollowing)
    }
    
    func observeFollowStatus(for organizationId: String) -> AnyPublisher<Bool?, Never> {
        return followStatusManager.$followStatusChanges
            .map { $0[organizationId] }
            .eraseToAnyPublisher()
    }
}
