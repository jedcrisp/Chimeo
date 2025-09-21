import Foundation
import SwiftUI
import CoreLocation

// MARK: - Notification Names
extension Notification.Name {
    static let organizationUpdated = Notification.Name("organizationUpdated")
}

// MARK: - Incident Types
enum IncidentType: String, CaseIterable, Codable {
    case weather = "weather"
    case road = "road"
    case fire = "fire"
    case police = "police"
    case medical = "medical"
    case emergency = "emergency"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .weather: return "Weather"
        case .road: return "Road"
        case .fire: return "Fire"
        case .police: return "Police"
        case .medical: return "Medical"
        case .emergency: return "Emergency"
        case .other: return "Other"
        }
    }
    
    var color: Color {
        switch self {
        case .weather: return .blue
        case .road: return .orange
        case .fire: return .red
        case .police: return .purple
        case .medical: return .green
        case .emergency: return .red
        case .other: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .weather: return "cloud.rain"
        case .road: return "car"
        case .fire: return "flame"
        case .police: return "shield"
        case .medical: return "cross"
        case .emergency: return "exclamationmark.triangle.fill"
        case .other: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Incident Severity
enum IncidentSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Location
struct Location: Codable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    
    // Custom coding keys to map Firestore field names to Swift properties
    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case address  // Firestore uses "address", not "laddress"
        case city
        case state
        case zipCode
    }
    
    init(latitude: Double, longitude: Double, address: String? = nil, city: String? = nil, state: String? = nil, zipCode: String? = nil) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
    }
    
    // Custom decoding to handle string coordinates from Firestore
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle coordinates that might be stored as strings or numbers
        var latitude: Double = 0.0
        var longitude: Double = 0.0
        
        if let latString = try? container.decode(String.self, forKey: .latitude),
           let lat = Double(latString) {
            latitude = lat
        } else if let lat = try? container.decodeIfPresent(Double.self, forKey: .latitude) {
            latitude = lat
        }
        
        if let lonString = try? container.decode(String.self, forKey: .longitude),
           let lon = Double(lonString) {
            longitude = lon
        } else if let lon = try? container.decodeIfPresent(Double.self, forKey: .longitude) {
            longitude = lon
        }
        
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.state = try container.decodeIfPresent(String.self, forKey: .state)
        self.zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode)
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var fullAddress: String {
        var components: [String] = []
        
        if let address = address, !address.isEmpty {
            components.append(address)
        }
        
        if let city = city, !city.isEmpty {
            components.append(city)
        }
        
        if let state = state, !state.isEmpty {
            components.append(state)
        }
        
        if let zipCode = zipCode, !zipCode.isEmpty {
            components.append(zipCode)
        }
        
        return components.isEmpty ? "Location unavailable" : components.joined(separator: ", ")
    }
}

// MARK: - Organization
struct Organization: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let type: String
    let description: String?
    let location: Location
    let verified: Bool
    let followerCount: Int
    let logoURL: String?
    let website: String?
    let phone: String?
    let email: String?
    let groups: [OrganizationGroup]?
    let adminIds: [String: Bool]?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Direct access to address fields (flat in Firestore)
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    
    // Custom coding keys to map flat Firestore fields to nested Swift structure
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case description
        case location
        case verified
        case followerCount
        case logoURL
        case website
        case phone
        case email
        case groups
        case adminIds
        case createdAt
        case updatedAt
        // Map flat address fields to nested location
        case address
        case city
        case state
        case zipCode
    }
    
    init(id: String = UUID().uuidString, name: String, type: String, description: String? = nil, location: Location, verified: Bool = false, followerCount: Int = 0, logoURL: String? = nil, website: String? = nil, phone: String? = nil, email: String? = nil, groups: [OrganizationGroup]? = nil, adminIds: [String: Bool]? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, address: String? = nil, city: String? = nil, state: String? = nil, zipCode: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.location = location
        self.verified = verified
        self.followerCount = followerCount
        self.logoURL = logoURL
        self.website = website
        self.phone = phone
        self.email = email
        self.groups = groups
        self.adminIds = adminIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
    }
    
    // Custom decoding to handle flat address fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode basic fields
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.verified = try container.decode(Bool.self, forKey: .verified)
        self.followerCount = try container.decode(Int.self, forKey: .followerCount)
        self.logoURL = try container.decodeIfPresent(String.self, forKey: .logoURL)
        self.website = try container.decodeIfPresent(String.self, forKey: .website)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.groups = try container.decodeIfPresent([OrganizationGroup].self, forKey: .groups)
        self.adminIds = try container.decodeIfPresent([String: Bool].self, forKey: .adminIds)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        // Decode flat address fields
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.city = try container.decodeIfPresent(String.self, forKey: .city)
        self.state = try container.decodeIfPresent(String.self, forKey: .state)
        self.zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode)
        
        // Handle location - try nested first, then fall back to flat fields
        if let nestedLocation = try? container.decode(Location.self, forKey: .location) {
            self.location = nestedLocation
        } else {
            // Create Location from flat address fields
            let address = try container.decodeIfPresent(String.self, forKey: .address)
            let city = try container.decodeIfPresent(String.self, forKey: .city)
            let state = try container.decodeIfPresent(String.self, forKey: .state)
            let zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode)
            
            // Create a Location struct with the flat address data
            self.location = Location(
                latitude: 0.0, // Will be geocoded later
                longitude: 0.0, // Will be geocoded later
                address: address,
                city: city,
                state: state,
                zipCode: zipCode
            )
        }
    }
    
    // Custom encoding to handle flat address fields
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode basic fields
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(verified, forKey: .verified)
        try container.encode(followerCount, forKey: .followerCount)
        try container.encodeIfPresent(logoURL, forKey: .logoURL)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(phone, forKey: .phone)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(groups, forKey: .groups)
        try container.encodeIfPresent(adminIds, forKey: .adminIds)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        
        // Encode location as nested object
        try container.encode(location, forKey: .location)
        
        // Also encode flat address fields for backward compatibility
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(zipCode, forKey: .zipCode)
    }
    
    var groupCount: Int {
        return groups?.count ?? 0
    }
    
    var isAdmin: Bool {
        return adminIds?.isEmpty == false
    }
    
    // Generate a clean, URL-friendly ID for Firestore
    var firestoreId: String {
        let cleanName = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "&", with: "_and_")
        
        // Clean up multiple underscores
        var result = cleanName
        while result.contains("__") {
            result = result.replacingOccurrences(of: "__", with: "_")
        }
        
        // Remove leading/trailing underscores
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        return result
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Organization, rhs: Organization) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - User Statistics
struct UserStatistics: Codable {
    let totalAlertsReceived: Int
    let alertsThisWeek: Int
    let organizationsFollowing: Int
    let incidentReportsSubmitted: Int
    let lastActive: Date
}

// MARK: - User
struct User: Codable, Identifiable {
    let id: String
    var email: String?
    var name: String?
    var searchableName: String? // Easy to find users in Firestore console
    var customDisplayName: String?
    var phone: String?
    var profilePhotoURL: String?
    var homeLocation: Location?
    var workLocation: Location?
    var schoolLocation: Location?
    var alertRadius: Double
    var preferences: UserPreferences
    let createdAt: Date
    var updatedAt: Date?
    let isAdmin: Bool
    var isOrganizationAdmin: Bool?
    var organizations: [String]?
    var needsPasswordSetup: Bool?
    var needsPasswordChange: Bool?
    var firebaseAuthId: String?
    
    init(id: String, email: String?, name: String?, phone: String?, profilePhotoURL: String? = nil, homeLocation: Location?, workLocation: Location?, schoolLocation: Location?, alertRadius: Double, preferences: UserPreferences, createdAt: Date, isAdmin: Bool = false, displayName: String? = nil, isOrganizationAdmin: Bool? = nil, organizations: [String]? = nil, updatedAt: Date? = nil, needsPasswordSetup: Bool? = nil, needsPasswordChange: Bool? = nil, firebaseAuthId: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.searchableName = name?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.customDisplayName = displayName ?? name
        self.phone = phone
        self.profilePhotoURL = profilePhotoURL
        self.homeLocation = homeLocation
        self.workLocation = workLocation
        self.schoolLocation = schoolLocation
        self.alertRadius = alertRadius
        self.preferences = preferences
        self.createdAt = createdAt
        self.isAdmin = isAdmin
        self.isOrganizationAdmin = isOrganizationAdmin
        self.organizations = organizations
        self.updatedAt = updatedAt
        self.needsPasswordSetup = needsPasswordSetup
        self.needsPasswordChange = needsPasswordChange
        self.firebaseAuthId = firebaseAuthId
    }
    
    // Computed property for easy searching (fallback to stored customDisplayName)
    var displayName: String {
        return customDisplayName ?? name ?? email ?? "Unknown User"
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    var incidentTypes: [IncidentType]
    var criticalAlertsOnly: Bool
    var pushNotifications: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: Date?
    var quietHoursEnd: Date?
}

// MARK: - Incident
struct Incident: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: IncidentType
    let severity: IncidentSeverity
    let location: Location
    let organization: Organization?
    let verified: Bool
    let confidence: Double
    let reportedAt: Date
    let updatedAt: Date
    let photos: [String]?
    let distance: Double?
    let userId: String?
    let reporterId: String?
}

// MARK: - Incident Report
struct IncidentReport: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: IncidentType
    let severity: IncidentSeverity
    let location: Location
    let photos: [String]?
    let reportedBy: String
    let status: ReportStatus
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Report Status
enum ReportStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case underReview = "under_review"
    case verified = "verified"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .underReview: return "Under Review"
        case .verified: return "Verified"
        case .rejected: return "Rejected"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .underReview: return .blue
        case .verified: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Organization Types
enum OrganizationType: String, CaseIterable, Codable {
    // Primary Categories
    case business = "business"
    case nonprofit = "nonprofit"
    case government = "government"
    case emergency = "emergency"
    
    // Education & Community
    case school = "school"
    case church = "church"
    case pto = "pto"
    
    // Healthcare
    case hospital = "hospital"
    case clinic = "clinic"
    case medicalPractice = "medical_practice"
    case pharmacy = "pharmacy"
    
    // Other
    case other = "other"
    
    var displayName: String {
        switch self {
        case .business: return "Business"
        case .nonprofit: return "Non-Profit Organization"
        case .government: return "Government Agency"
        case .emergency: return "Emergency Services"
        case .school: return "School/Educational"
        case .church: return "Church/Religious Organization"
        case .pto: return "PTO/PTA"
        case .hospital: return "Hospital/Medical Center"
        case .clinic: return "Medical Clinic"
        case .medicalPractice: return "Medical Practice"
        case .pharmacy: return "Pharmacy"
        case .other: return "Other"
        }
    }
    
    var category: String {
        switch self {
        case .business: return "Business"
        case .nonprofit, .government, .emergency: return "Public Service"
        case .school, .church, .pto: return "Education & Community"
        case .hospital, .clinic, .medicalPractice, .pharmacy: return "Healthcare"
        case .other: return "Other"
        }
    }
}

// MARK: - Request Status
enum RequestStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case underReview = "under_review"
    case approved = "approved"
    case rejected = "rejected"
    case requiresMoreInfo = "requires_more_info"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .underReview: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .requiresMoreInfo: return "More Info Required"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .underReview: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .requiresMoreInfo: return .yellow
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .underReview: return "magnifyingglass"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .requiresMoreInfo: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Organization Request
struct OrganizationRequest: Codable, Identifiable {
    let id: String
    let name: String
    let type: OrganizationType
    let description: String
    let website: String?
    let phone: String?
    let email: String
    let location: Location
    let contactPersonName: String
    let contactPersonTitle: String
    let contactPersonPhone: String
    let contactPersonEmail: String
    let adminPassword: String
    let status: RequestStatus
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let reviewNotes: String?
    let verificationDocuments: [String]?
    
    // Computed properties for backward compatibility
    var address: String { location.address ?? "" }
    var city: String { location.city ?? "" }
    var state: String { location.state ?? "" }
    var zipCode: String { location.zipCode ?? "" }
    
    init(name: String, type: OrganizationType, description: String, website: String?, phone: String?, email: String, address: String, city: String, state: String, zipCode: String, contactPersonName: String, contactPersonTitle: String, contactPersonPhone: String, contactPersonEmail: String, adminPassword: String, status: RequestStatus) {
        // Create a meaningful ID from the organization name instead of random UUID
        self.id = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "&", with: "_and_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        self.name = name
        self.type = type
        self.description = description
        self.website = website
        self.phone = phone
        self.email = email
        self.location = Location(
            latitude: 0, // Will be geocoded later
            longitude: 0, // Will be geocoded later
            address: address,
            city: city,
            state: state,
            zipCode: zipCode
        )
        self.contactPersonName = contactPersonName
        self.contactPersonTitle = contactPersonTitle
        self.contactPersonPhone = contactPersonPhone
        self.contactPersonEmail = contactPersonEmail
        self.adminPassword = adminPassword
        self.status = status
        self.submittedAt = Date()
        self.reviewedAt = nil
        self.reviewedBy = nil
        self.reviewNotes = nil
        self.verificationDocuments = nil
    }
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
    
    var fullAddress: String {
        location.fullAddress
    }
}

// MARK: - Admin Review
struct AdminReview: Codable, Identifiable {
    let id: String
    let requestId: String
    let adminId: String
    let adminName: String
    let status: RequestStatus
    let notes: String
    let reviewedAt: Date
    let nextSteps: [String]?
    
    init(requestId: String, adminId: String, adminName: String, status: RequestStatus, notes: String, nextSteps: [String]? = nil) {
        self.id = UUID().uuidString
        self.requestId = requestId
        self.adminId = adminId
        self.adminName = adminName
        self.status = status
        self.notes = notes
        self.reviewedAt = Date()
        self.nextSteps = nextSteps
    }
} 

// MARK: - Organization Group
struct OrganizationGroup: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let organizationId: String
    let isActive: Bool
    let memberCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String = UUID().uuidString, name: String, description: String? = nil, organizationId: String, isActive: Bool = true, memberCount: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.organizationId = organizationId
        self.isActive = isActive
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Organization Alert
struct OrganizationAlert: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let organizationId: String
    let organizationName: String
    let groupId: String?
    let groupName: String?
    let type: IncidentType
    let severity: IncidentSeverity
    let location: Location?
    let postedBy: String
    let postedByUserId: String
    let postedAt: Date
    let expiresAt: Date
    let imageURLs: [String]
    let isActive: Bool
    let distance: Double?
    
    init(id: String = UUID().uuidString, title: String, description: String, organizationId: String, organizationName: String, groupId: String? = nil, groupName: String? = nil, type: IncidentType, severity: IncidentSeverity, location: Location? = nil, postedBy: String, postedByUserId: String, postedAt: Date = Date(), imageURLs: [String] = [], distance: Double? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.groupId = groupId
        self.groupName = groupName
        self.type = type
        self.severity = severity
        self.location = location
        self.postedBy = postedBy
        self.postedByUserId = postedByUserId
        self.postedAt = postedAt
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 14, to: postedAt) ?? postedAt
        self.imageURLs = imageURLs
        self.isActive = true
        self.distance = distance
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiresAt)
        return components.day ?? 0
    }
}

// MARK: - Group Alert
struct GroupAlert: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let groupId: String
    let organizationId: String
    let type: IncidentType
    let severity: IncidentSeverity
    let location: Location?
    let reportedBy: String
    let reportedAt: Date
    let imageURLs: [String]
    let distance: Double?
    
    init(id: String = UUID().uuidString, title: String, description: String, groupId: String, organizationId: String, type: IncidentType, severity: IncidentSeverity, location: Location? = nil, reportedBy: String, reportedAt: Date = Date(), imageURLs: [String] = [], distance: Double? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.groupId = groupId
        self.organizationId = organizationId
        self.type = type
        self.severity = severity
        self.location = location
        self.reportedBy = reportedBy
        self.reportedAt = reportedAt
        self.imageURLs = imageURLs
        self.distance = distance
    }
}

// MARK: - User Group Preferences
struct UserGroupPreferences: Codable {
    let userId: String
    let organizationId: String
    let groupId: String
    let alertsEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(userId: String, organizationId: String, groupId: String, alertsEnabled: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.userId = userId
        self.organizationId = organizationId
        self.groupId = groupId
        self.alertsEnabled = alertsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 