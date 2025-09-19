import Foundation
import FirebaseFirestore

// MARK: - User Profile Service
class UserProfileService: ObservableObject {
    
    // MARK: - User Profile Management
    func updateUserProfile(_ user: User) async throws {
        print("👤 Updating user profile for: \(user.email ?? "Unknown")")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.id)
        
        let updateData: [String: Any] = [
            "name": user.name ?? "",
            "searchableName": user.name?.lowercased().replacingOccurrences(of: " ", with: "") ?? "",
            "customDisplayName": user.displayName ?? user.name ?? "",
            "phone": user.phone ?? "",
            "profilePhotoURL": user.profilePhotoURL ?? "",
            "alertRadius": user.alertRadius,
            "preferences": [
                "incidentTypes": user.preferences.incidentTypes.map { $0.rawValue },
                "criticalAlertsOnly": user.preferences.criticalAlertsOnly,
                "pushNotifications": user.preferences.pushNotifications,
                "quietHoursEnabled": user.preferences.quietHoursEnabled,
                "quietHoursStart": user.preferences.quietHoursStart,
                "quietHoursEnd": user.preferences.quietHoursEnd
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await userRef.updateData(updateData)
        
        print("✅ User profile updated successfully")
    }
    
    func updateUserPreferences(_ preferences: UserPreferences, userId: String) async throws {
        print("⚙️ Updating user preferences for user: \(userId)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        let preferencesData: [String: Any] = [
            "preferences": [
                "incidentTypes": preferences.incidentTypes.map { $0.rawValue },
                "criticalAlertsOnly": preferences.criticalAlertsOnly,
                "pushNotifications": preferences.pushNotifications,
                "quietHoursEnabled": preferences.quietHoursEnabled,
                "quietHoursStart": preferences.quietHoursStart,
                "quietHoursEnd": preferences.quietHoursEnd
            ],
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await userRef.updateData(preferencesData)
        
        print("✅ User preferences updated successfully")
    }
    
    func updateUserLocation(_ location: Location, locationType: LocationType, userId: String) async throws {
        print("📍 Updating user location for user: \(userId)")
        print("   Type: \(locationType)")
        print("   Address: \(location.address)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        let locationData: [String: Any] = [
            "latitude": location.latitude,
            "longitude": location.longitude,
            "address": location.address,
            "city": location.city,
            "state": location.state,
            "zipCode": location.zipCode
        ]
        
        var updateData: [String: Any] = [:]
        
        switch locationType {
        case .home:
            updateData["homeLocation"] = locationData
        case .work:
            updateData["workLocation"] = locationData
        case .school:
            updateData["schoolLocation"] = locationData
        }
        
        updateData["updatedAt"] = FieldValue.serverTimestamp()
        
        try await userRef.updateData(updateData)
        
        print("✅ User location updated successfully")
    }
    
    func updateAlertRadius(_ radius: Double, userId: String) async throws {
        print("📏 Updating alert radius for user: \(userId)")
        print("   New radius: \(radius)km")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "alertRadius": radius,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ Alert radius updated successfully")
    }
    
    // MARK: - User Statistics
    func getUserStatistics(userId: String) async throws -> UserStatistics {
        print("📊 Fetching user statistics for user: \(userId)")
        
        let db = Firestore.firestore()
        
        // Get total alerts received
        let alertsQuery = try await db.collection("incidents")
            .whereField("reporterId", isEqualTo: userId)
            .getDocuments()
        
        let totalAlertsReceived = alertsQuery.documents.count
        
        // Get alerts this week
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        let weeklyAlertsQuery = try await db.collection("incidents")
            .whereField("reporterId", isEqualTo: userId)
            .whereField("createdAt", isGreaterThan: startOfWeek)
            .getDocuments()
        
        let alertsThisWeek = weeklyAlertsQuery.documents.count
        
        // Get organizations following
        let followingQuery = try await db.collection("organizationFollowers")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let organizationsFollowing = followingQuery.documents.count
        
        // Get incident reports submitted
        let reportsQuery = try await db.collection("incidents")
            .whereField("reporterId", isEqualTo: userId)
            .getDocuments()
        
        let incidentReportsSubmitted = reportsQuery.documents.count
        
        let statistics = UserStatistics(
            totalAlertsReceived: totalAlertsReceived,
            alertsThisWeek: alertsThisWeek,
            organizationsFollowing: organizationsFollowing,
            incidentReportsSubmitted: incidentReportsSubmitted,
            lastActive: Date()
        )
        
        print("✅ User statistics fetched successfully")
        print("   📊 Total alerts: \(totalAlertsReceived)")
        print("   📅 This week: \(alertsThisWeek)")
        print("   🏢 Following: \(organizationsFollowing)")
        print("   📝 Reports: \(incidentReportsSubmitted)")
        
        return statistics
    }
    
    // MARK: - User Search
    func searchUsers(query: String) async throws -> [User] {
        print("🔍 Searching for users with query: \(query)")
        
        let db = Firestore.firestore()
        let usersRef = db.collection("users")
        
        // Search by name (case-insensitive)
        let nameQuery = try await usersRef
            .whereField("searchableName", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("searchableName", isLessThan: query.lowercased() + "z")
            .getDocuments()
        
        // Search by email (case-insensitive)
        let emailQuery = try await usersRef
            .whereField("email", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("email", isLessThan: query.lowercased() + "z")
            .getDocuments()
        
        var users: [User] = []
        var seenIds = Set<String>()
        
        // Process name results
        for document in nameQuery.documents {
            if !seenIds.contains(document.documentID) {
                if let user = try parseUserFromFirestore(docId: document.documentID, data: document.data()) {
                    users.append(user)
                    seenIds.insert(document.documentID)
                }
            }
        }
        
        // Process email results
        for document in emailQuery.documents {
            if !seenIds.contains(document.documentID) {
                if let user = try parseUserFromFirestore(docId: document.documentID, data: document.data()) {
                    users.append(user)
                    seenIds.insert(document.documentID)
                }
            }
        }
        
        print("✅ Found \(users.count) users matching query: \(query)")
        return users
    }
    
    // MARK: - User Parsing
    private func parseUserFromFirestore(docId: String, data: [String: Any]) throws -> User? {
        let email = data["email"] as? String ?? ""
        let name = data["name"] as? String ?? "Unknown"
        let phone = data["phone"] as? String
        let profilePhotoURL = data["profilePhotoURL"] as? String
        let alertRadius = data["alertRadius"] as? Double ?? 10.0
        let isAdmin = data["isAdmin"] as? Bool ?? false
        let customDisplayName = data["customDisplayName"] as? String
        let isOrganizationAdmin = data["isOrganizationAdmin"] as? Bool
        let organizations = data["organizations"] as? [String]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        let needsPasswordSetup = data["needsPasswordSetup"] as? Bool
        let needsPasswordChange = data["needsPasswordChange"] as? Bool
        let firebaseAuthId = data["firebaseAuthId"] as? String
        
        // Parse preferences
        let preferencesData = data["preferences"] as? [String: Any] ?? [:]
        let preferences = UserPreferences(
            incidentTypes: parseIncidentTypes(from: preferencesData["incidentTypes"] as? [String] ?? []),
            criticalAlertsOnly: preferencesData["criticalAlertsOnly"] as? Bool ?? false,
            pushNotifications: preferencesData["pushNotifications"] as? Bool ?? true,
            quietHoursEnabled: preferencesData["quietHoursEnabled"] as? Bool ?? false,
            quietHoursStart: preferencesData["quietHoursStart"] as? Date,
            quietHoursEnd: preferencesData["quietHoursEnd"] as? Date
        )
        
        // Parse locations
        let homeLocation = parseLocation(from: data["homeLocation"] as? [String: Any])
        let workLocation = parseLocation(from: data["workLocation"] as? [String: Any])
        let schoolLocation = parseLocation(from: data["schoolLocation"] as? [String: Any])
        
        return User(
            id: docId,
            email: email,
            name: name,
            phone: phone,
            profilePhotoURL: profilePhotoURL,
            homeLocation: homeLocation,
            workLocation: workLocation,
            schoolLocation: schoolLocation,
            alertRadius: alertRadius,
            preferences: preferences,
            createdAt: createdAt,
            isAdmin: isAdmin,
            displayName: customDisplayName ?? name,
            isOrganizationAdmin: isOrganizationAdmin,
            organizations: organizations,
            updatedAt: updatedAt,
            needsPasswordSetup: needsPasswordSetup,
            needsPasswordChange: needsPasswordChange,
            firebaseAuthId: firebaseAuthId
        )
    }
    
    private func parseLocation(from data: [String: Any]?) -> Location? {
        guard let data = data else { return nil }
        
        return Location(
            latitude: data["latitude"] as? Double ?? 0.0,
            longitude: data["longitude"] as? Double ?? 0.0,
            address: data["address"] as? String ?? "",
            city: data["city"] as? String ?? "",
            state: data["state"] as? String ?? "",
            zipCode: data["zipCode"] as? String ?? ""
        )
    }
    
    private func parseIncidentTypes(from strings: [String]) -> [IncidentType] {
        return strings.compactMap { IncidentType(rawValue: $0) }
    }
}

// MARK: - Location Type
enum LocationType {
    case home
    case work
    case school
}
