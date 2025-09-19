import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Follow Status Manager
// Using the dedicated FollowStatusManager from its own file

// MARK: - Service Coordinator
// Central coordinator for all service operations
class ServiceCoordinator: ObservableObject {
    
    // MARK: - Service Instances
    let userService: UserManagementService
    let authService: AuthenticationService
    let organizationService: OrganizationService
    let groupService: OrganizationGroupService
    let alertService: OrganizationAlertService
    let fileService: FileUploadService
    let incidentService: IncidentService
    let userProfileService: UserProfileService
    let notificationService: iOSNotificationService
    let followingService: OrganizationFollowingService
    let developmentService: DevelopmentService
    
    // MARK: - Published Properties (for backward compatibility)
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var incidents: [Incident] = []
    @Published var organizations: [Organization] = []
    @Published var pendingRequests: [OrganizationRequest] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize services
        self.userService = UserManagementService()
        self.authService = AuthenticationService(userService: userService)
        self.organizationService = OrganizationService(userService: userService)
        self.groupService = OrganizationGroupService()
        self.notificationService = iOSNotificationService()
        self.alertService = OrganizationAlertService(notificationService: notificationService)
        self.fileService = FileUploadService()
        self.incidentService = IncidentService()
        self.userProfileService = UserProfileService()
        self.followingService = OrganizationFollowingService()
        self.developmentService = DevelopmentService()
        
        print("🔍 ServiceCoordinator initialized")
        print("   AuthService: \(authService)")
        
        // Bind auth service properties to coordinator
        authService.$isAuthenticated
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        authService.$currentUser
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
        
        // Bind organization service properties to coordinator
        organizationService.$organizations
            .assign(to: \.organizations, on: self)
            .store(in: &cancellables)
        
        organizationService.$pendingRequests
            .assign(to: \.pendingRequests, on: self)
            .store(in: &cancellables)
        
        print("✅ ServiceCoordinator setup complete")
        
        // Check and restore authentication state on initialization
        checkAndRestoreAuthenticationState()
    }
    
    // MARK: - Authentication Methods (delegate to AuthenticationService)
    func signInWithGoogle() async throws -> User {
        let user = try await authService.signInWithGoogle()
        await loadOrganizationsIntoService()
        return user
    }
    
    func signUpWithEmail(email: String, password: String, name: String) async throws -> User {
        let user = try await authService.signUpWithEmail(email: email, password: password, name: name)
        await loadOrganizationsIntoService()
        return user
    }
    
    func signInWithEmail(email: String, password: String) async throws -> User {
        let user = try await authService.signInWithEmail(email: email, password: password)
        await loadOrganizationsIntoService()
        return user
    }
    
    func updatePassword(newPassword: String) async throws {
        try await authService.updatePassword(newPassword: newPassword)
    }
    
    func signOut() {
        authService.signOut()
        // Clear other service data
        organizationService.organizations = []
        organizationService.pendingRequests = []
    }
    
    // MARK: - Authentication State Management
    func checkAndRestoreAuthenticationState() {
        print("🔍 ServiceCoordinator: Checking authentication state...")
        
        // First, check if we have a currentUser in the coordinator
        if let coordinatorUser = currentUser {
            print("✅ ServiceCoordinator already has currentUser: \(coordinatorUser.id)")
            print("   Email: \(coordinatorUser.email ?? "none")")
            print("   Name: \(coordinatorUser.name ?? "none")")
            return
        }
        
        // Check if authService has a current user
        if let authServiceUser = authService.currentUser {
            print("✅ AuthService has currentUser: \(authServiceUser.id)")
            print("   Email: \(authServiceUser.email ?? "none")")
            print("   Name: \(authServiceUser.name ?? "none")")
            
            // Update coordinator state
            DispatchQueue.main.async {
                self.currentUser = authServiceUser
                self.isAuthenticated = true
                print("✅ Authentication state restored from AuthService for user: \(authServiceUser.name ?? "Unknown")")
            }
            return
        }
        
        // Check if Firebase Auth has a current user
        if let firebaseUser = Auth.auth().currentUser {
            print("✅ Firebase Auth has current user: \(firebaseUser.uid)")
            print("   Email: \(firebaseUser.email ?? "none")")
            print("   Display Name: \(firebaseUser.displayName ?? "none")")
            
            // Create User object from Firebase user
            let restoredUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email,
                name: firebaseUser.displayName ?? "User",
                phone: firebaseUser.phoneNumber,
                homeLocation: Location(
                    latitude: 33.1032,
                    longitude: -96.6705,
                    address: "123 Main Street",
                    city: "Lucas",
                    state: "TX",
                    zipCode: "75002"
                ),
                workLocation: nil,
                schoolLocation: nil,
                alertRadius: 10.0,
                preferences: UserPreferences(
                    incidentTypes: [.weather, .road, .other],
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: Date(),
                isAdmin: false,
                displayName: firebaseUser.displayName ?? "User"
            )
            
            // Update coordinator state
            DispatchQueue.main.async {
                self.currentUser = restoredUser
                self.isAuthenticated = true
                print("✅ Authentication state restored from Firebase Auth for user: \(restoredUser.name ?? "Unknown")")
            }
            return
        }
        
        // If we get here, no user is authenticated anywhere
        print("❌ No user found in any service - user needs to sign in")
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
            print("✅ Coordinator state cleared - no authenticated user")
        }
    }
    
    // MARK: - Manual User State Management
    func setCurrentUser(_ user: User) {
        print("🔧 ServiceCoordinator: Manually setting current user")
        print("   User ID: \(user.id)")
        print("   Email: \(user.email ?? "none")")
        print("   Name: \(user.name ?? "none")")
        
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = true
            print("✅ Current user manually set successfully")
        }
    }
    
    func syncUserFromAPIService() {
        print("🔄 ServiceCoordinator: Syncing user from APIService...")
        
        // This method should be called when we know the APIService has the correct user
        // and we want to sync it to the ServiceCoordinator
        if let apiServiceUser = authService.currentUser {
            print("   Found user in APIService: \(apiServiceUser.id)")
            setCurrentUser(apiServiceUser)
        } else {
            print("   No user found in APIService")
        }
    }
    
    // MARK: - Debug Functions
    func createMissingUserDocument(userId: String, email: String, name: String) async throws {
        print("🔧 DEBUG: Creating missing user document for: \(userId)")
        print("   Email: \(email)")
        print("   Name: \(name)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // Get FCM token (or empty string if not available)
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        print("   FCM Token available: \(fcmToken.isEmpty ? "NO" : "YES")")
        print("   FCM Token value: \(fcmToken)")
        
        // Create user document with all necessary fields
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "name": name,
            "displayName": name,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isAdmin": false,
            "isOrganizationAdmin": false,
            "fcmToken": fcmToken,
            "alertsEnabled": true,
            "uid": userId,
            "lastSignIn": FieldValue.serverTimestamp(),
            "signInCount": 1
        ]
        
        try await userRef.setData(userData, merge: true)
        print("✅ Missing user document created successfully")
        
        // Verify creation
        let verifyDoc = try await userRef.getDocument()
        if (verifyDoc.exists) {
            print("✅ VERIFICATION: User document confirmed to exist")
        } else {
            print("❌ VERIFICATION FAILED: User document still doesn't exist!")
        }
    }
    
    // MARK: - User Management
    func isAdminOfOrganization(_ organizationId: String) async -> Bool {
        return await userService.isAdminOfOrganization(organizationId, currentUser: currentUser)
    }
    
    func canManageOrganization(_ organizationId: String) async -> Bool {
        return await userService.canManageOrganization(organizationId, currentUser: currentUser)
    }
    
    func hasOrganizationAdminAccess() -> Bool {
        return userService.hasOrganizationAdminAccess(currentUser: currentUser, organizations: organizations)
    }
    
    // MARK: - Organization Methods (delegate to OrganizationService)
    func loadOrganizationsIntoService() async {
        await organizationService.loadOrganizations()
    }
    
    func fetchOrganizations() async throws -> [Organization] {
        return try await organizationService.fetchOrganizations()
    }
    
    func submitOrganizationRequest(_ request: OrganizationRequest) async throws -> OrganizationRequest {
        return try await organizationService.submitOrganizationRequest(request)
    }
    
    func approveOrganizationRequest(_ requestId: String, notes: String = "") async throws -> OrganizationRequest {
        return try await organizationService.approveOrganizationRequest(requestId, notes: notes)
    }
    
    func followOrganization(_ organizationId: String) async throws {
        print("🔍 ServiceCoordinator.followOrganization called for org: \(organizationId)")
        
        // Check and restore authentication state first
        checkAndRestoreAuthenticationState()
        
        print("   Current user: \(currentUser?.id ?? "NIL")")
        print("   Current user name: \(currentUser?.name ?? "NIL")")
        
        guard let currentUser = currentUser else { 
            print("❌ No current user found in ServiceCoordinator")
            throw APIError.unauthorized
        }
        
        print("✅ Following organization \(organizationId) for user \(currentUser.id)")
        try await followingService.followOrganization(organizationId, userId: currentUser.id)
        
        // Broadcast follow status change to all views
        FollowStatusManager.shared.updateFollowStatus(organizationId: organizationId, isFollowing: true)
        print("✅ Successfully followed organization \(organizationId)")
    }
    
    func unfollowOrganization(_ organizationId: String) async throws {
        print("🔍 ServiceCoordinator.unfollowOrganization called for org: \(organizationId)")
        
        // Check and restore authentication state first
        checkAndRestoreAuthenticationState()
        
        print("   Current user: \(currentUser?.id ?? "NIL")")
        print("   Current user name: \(currentUser?.name ?? "NIL")")
        
        guard let currentUser = currentUser else { 
            print("❌ No current user found in ServiceCoordinator")
            throw APIError.unauthorized
        }
        
        print("✅ Unfollowing organization \(organizationId) for user \(currentUser.id)")
        try await followingService.unfollowOrganization(organizationId, userId: currentUser.id)
        
        // Broadcast follow status change to all views
        FollowStatusManager.shared.updateFollowStatus(organizationId: organizationId, isFollowing: false)
        print("✅ Successfully unfollowed organization \(organizationId)")
    }
    
    func isFollowingOrganization(_ organizationId: String) async throws -> Bool {
        guard let currentUser = currentUser else { return false }
        return try await followingService.isFollowingOrganization(organizationId, userId: currentUser.id)
    }
    
    func fixOrganizationFollowerCount(_ organizationId: String) async throws {
        try await followingService.fixOrganizationFollowerCount(organizationId)
    }
    
    func fixExistingOrganizationAdminIds() async throws {
        try await organizationService.fixExistingOrganizationAdminIds()
    }
    
    // MARK: - Organization Groups
    func createOrganizationGroup(group: OrganizationGroup, organizationId: String) async throws -> OrganizationGroup {
        return try await groupService.createOrganizationGroup(group: group, organizationId: organizationId)
    }
    
    func updateOrganizationGroup(_ group: OrganizationGroup) async throws {
        try await groupService.updateOrganizationGroup(group)
    }
    
    func deleteOrganizationGroup(_ groupName: String, organizationId: String) async throws {
        try await groupService.deleteOrganizationGroup(groupName, organizationId: organizationId)
    }
    
    func getOrganizationGroups(organizationId: String) async throws -> [OrganizationGroup] {
        return try await groupService.getOrganizationGroups(organizationId: organizationId)
    }
    
    // MARK: - Alert Management Methods (delegate to OrganizationAlertService)
    func postOrganizationAlert(_ alert: OrganizationAlert) async throws {
        try await alertService.postOrganizationAlert(alert)
    }
    
    func updateOrganizationAlert(_ alert: OrganizationAlert) async throws {
        try await alertService.updateOrganizationAlert(alert)
    }
    
    func deleteOrganizationAlert(_ alertId: String, organizationId: String) async throws {
        try await alertService.deleteOrganizationAlert(alertId, organizationId: organizationId)
    }
    
    func getOrganizationAlerts(organizationId: String) async throws -> [OrganizationAlert] {
        return try await alertService.getOrganizationAlerts(organizationId: organizationId)
    }
    
    func getFollowingOrganizationAlerts() async throws -> [OrganizationAlert] {
        return try await alertService.getFollowingOrganizationAlerts()
    }
    
    // MARK: - File Upload Methods (delegate to FileUploadService)
    func uploadUserProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
        return try await fileService.uploadUserProfilePhoto(image, userId: userId)
    }
    
    func uploadOrganizationLogo(_ image: UIImage, organizationId: String, organizationName: String? = nil) async throws -> String {
        let logoURL = try await fileService.uploadOrganizationLogo(image, organizationId: organizationId, organizationName: organizationName)
        
        // Force refresh the organization data to ensure UI updates
        await organizationService.forceRefreshOrganization(organizationId)
        
        return logoURL
    }
    
    func uploadAlertPhoto(_ image: UIImage, alertId: String, organizationId: String) async throws -> String {
        return try await fileService.uploadAlertPhoto(image, alertId: alertId, organizationId: organizationId)
    }
    
    func uploadIncidentPhoto(_ image: UIImage, incidentId: String, userId: String) async throws -> String {
        return try await fileService.uploadIncidentPhoto(image, incidentId: incidentId, userId: userId)
    }
    
    // MARK: - Incident Methods (delegate to IncidentService)
    func fetchIncidents(latitude: Double, longitude: Double, radius: Double, types: [IncidentType]? = nil) async throws -> [Incident] {
        return try await incidentService.fetchIncidents(latitude: latitude, longitude: longitude, radius: radius, types: types)
    }
    
    func reportIncident(_ report: IncidentReport) async throws -> IncidentReport {
        return try await incidentService.reportIncident(report)
    }
    
    func updateIncident(_ incident: Incident) async throws {
        try await incidentService.updateIncident(incident)
    }
    
    func deleteIncident(_ incidentId: String) async throws {
        try await incidentService.deleteIncident(incidentId)
    }
    
    func addressToCoordinates(address: String) async throws -> (latitude: Double, longitude: Double) {
        return try await incidentService.addressToCoordinates(address: address)
    }
    
    func generateFirestoreId(from string: String) -> String {
        return incidentService.generateFirestoreId(from: string)
    }
    
    // MARK: - User Profile Methods (delegate to UserProfileService)
    func updateUserProfile(_ user: User) async throws {
        try await userProfileService.updateUserProfile(user)
    }
    
    func updateUserPreferences(_ preferences: UserPreferences, userId: String) async throws {
        try await userProfileService.updateUserPreferences(preferences, userId: userId)
    }
    
    func updateUserLocation(_ location: Location, locationType: LocationType, userId: String) async throws {
        try await userProfileService.updateUserLocation(location, locationType: locationType, userId: userId)
    }
    
    func updateAlertRadius(_ radius: Double, userId: String) async throws {
        try await userProfileService.updateAlertRadius(radius, userId: userId)
    }
    
    func getUserStatistics(userId: String) async throws -> UserStatistics {
        return try await userProfileService.getUserStatistics(userId: userId)
    }
    
    func searchUsers(query: String) async throws -> [User] {
        return try await userProfileService.searchUsers(query: query)
    }
    
    // MARK: - Notification Methods (delegate to NotificationService)
    func sendEmailNotification(to email: String, subject: String, body: String) async throws {
        try await notificationService.sendEmailNotification(to: email, subject: subject, body: body)
    }
    
    func sendOrganizationRequestNotification(request: OrganizationRequest) async throws {
        try await notificationService.sendOrganizationRequestNotification(request: request)
    }
    
    func sendOrganizationApprovalNotification(organizationName: String, contactEmail: String, password: String) async throws {
        try await notificationService.sendOrganizationApprovalNotification(organizationName: organizationName, contactEmail: contactEmail, password: password)
    }
    
    func sendPushNotification(title: String, body: String, userId: String, data: [String: Any] = [:]) async throws {
        try await notificationService.sendPushNotification(title: title, body: body, userId: userId, data: data)
    }
    
    // MARK: - Following Methods (delegate to OrganizationFollowingService)
    func followOrganization(_ organizationId: String, userId: String) async throws {
        try await followingService.followOrganization(organizationId, userId: userId)
    }
    
    func unfollowOrganization(_ organizationId: String, userId: String) async throws {
        try await followingService.unfollowOrganization(organizationId, userId: userId)
    }
    
    func isFollowingOrganization(_ organizationId: String, userId: String) async throws -> Bool {
        return try await followingService.isFollowingOrganization(organizationId, userId: userId)
    }
    
    func getFollowedOrganizations(userId: String) async throws -> [Organization] {
        return try await followingService.getFollowedOrganizations(userId: userId)
    }
    
    func updateUserGroupPreferences(_ preferences: UserGroupPreferences) async throws {
        try await followingService.updateUserGroupPreferences(preferences)
    }
    
    // MARK: - Development Methods (delegate to DevelopmentService)
    func debugOrganizationAccess(userId: String, organizationId: String) async throws {
        try await developmentService.debugOrganizationAccess(userId: userId, organizationId: organizationId)
    }
    
    func fixOrganizationAdminAccess(userId: String, organizationId: String) async throws {
        try await developmentService.fixOrganizationAdminAccess(userId: userId, organizationId: organizationId)
    }
    
    func checkCreatorAccount(userId: String) async throws -> Bool {
        return try await developmentService.checkCreatorAccount(userId: userId)
    }
    
    // MARK: - Development Helper
    func enableGuestMode() {
        let guestUser = developmentService.enableGuestMode()
        authService.isAuthenticated = true
        authService.currentUser = guestUser
        print("Guest mode enabled with admin privileges for development")
    }
    
    // MARK: - FCM Token Management
    func ensureFollowersHaveFCMTokens(organizationId: String) async throws -> Int {
        print("🔧 Ensuring all followers have FCM tokens for organization: \(organizationId)")
        
        let db = Firestore.firestore()
        
        // Get all followers for this organization
        let followersQuery = db.collection("organizations").document(organizationId).collection("followers")
        let followersSnapshot = try await followersQuery.getDocuments()
        
        print("📋 Found \(followersSnapshot.documents.count) active followers")
        
        var updatedCount = 0
        
        for followerDoc in followersSnapshot.documents {
            let followerData = followerDoc.data()
            let userId = followerData["userId"] as? String
            
            if userId == nil {
                print("⚠️ Follower document missing userId: \(followerDoc.documentID)")
                continue
            }
            
            // Check if user document exists and has FCM token
            let userRef = db.collection("users").document(userId!)
            let userDoc = try await userRef.getDocument()
            
            if userDoc.exists {
                let userData = userDoc.data() ?? [:]
                let fcmToken = userData["fcmToken"] as? String ?? ""
                
                if fcmToken.isEmpty {
                    print("⚠️ User \(userId!) missing FCM token, attempting to update...")
                    
                    // Get FCM token from UserDefaults
                    let newFcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
                    
                    if !newFcmToken.isEmpty {
                        // Update user document with FCM token
                        try await userRef.updateData([
                            "fcmToken": newFcmToken,
                            "alertsEnabled": true,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                        
                        // Update follower document with FCM token
                        try await followerDoc.reference.updateData([
                            "fcmToken": newFcmToken,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                        
                        updatedCount += 1
                        print("✅ Updated FCM token for user \(userId!)")
                    } else {
                        print("⚠️ No FCM token available for user \(userId!)")
                    }
                } else {
                    // User has FCM token, update follower document if needed
                    if followerData["fcmToken"] as? String != fcmToken {
                        try await followerDoc.reference.updateData([
                            "fcmToken": fcmToken,
                            "updatedAt": FieldValue.serverTimestamp()
                        ])
                        updatedCount += 1
                        print("✅ Synced FCM token for user \(userId!)")
                    }
                }
            } else {
                print("⚠️ User document not found for follower \(userId!)")
            }
        }
        
        print("✅ FCM token update complete. Updated \(updatedCount) followers.")
        return updatedCount
    }
    
    // MARK: - Debug and Cleanup Methods
    func debugOrganizationLogoIssues() async {
        await organizationService.debugOrganizationLogoIssues()
    }
    
    func cleanUpInvalidLogoURLs() async {
        await organizationService.cleanUpInvalidLogoURLs()
    }
}
