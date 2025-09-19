import Foundation
import SwiftUI
import CoreLocation

// MARK: - Incident Types
enum IncidentType: String, CaseIterable, Codable {
    case weather = "weather"
    case road = "road"
    case fire = "fire"
    case police = "police"
    case medical = "medical"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .weather: return "Weather"
        case .road: return "Road"
        case .fire: return "Fire"
        case .police: return "Police"
        case .medical: return "Medical"
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
    
    init(latitude: Double, longitude: Double, address: String? = nil, city: String? = nil, state: String? = nil, zipCode: String? = nil) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
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
struct Organization: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let description: String?
    let location: Location
    let verified: Bool
    let followerCount: Int
    let website: String?
    let phone: String?
    let email: String?
    let groups: [OrganizationGroup]?
    
    init(id: String = UUID().uuidString, name: String, type: String, description: String? = nil, location: Location, verified: Bool = false, followerCount: Int = 0, website: String? = nil, phone: String? = nil, email: String? = nil, groups: [OrganizationGroup]? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.location = location
        self.verified = verified
        self.followerCount = followerCount
        self.website = website
        self.phone = phone
        self.email = email
        self.groups = groups
    }
    
    var groupCount: Int {
        return groups?.count ?? 0
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
    let email: String?
    let name: String?
    let homeLocation: Location?
    let workLocation: Location?
    let schoolLocation: Location?
    let alertRadius: Double
    let preferences: UserPreferences
    let createdAt: Date
    let isAdmin: Bool
    
    init(id: String, email: String?, name: String?, homeLocation: Location?, workLocation: Location?, schoolLocation: Location?, alertRadius: Double, preferences: UserPreferences, createdAt: Date, isAdmin: Bool = false) {
        self.id = id
        self.email = email
        self.name = name
        self.homeLocation = homeLocation
        self.workLocation = workLocation
        self.schoolLocation = schoolLocation
        self.alertRadius = alertRadius
        self.preferences = preferences
        self.createdAt = createdAt
        self.isAdmin = isAdmin
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable {
    let incidentTypes: [IncidentType]
    let criticalAlertsOnly: Bool
    let pushNotifications: Bool
    let quietHoursEnabled: Bool
    let quietHoursStart: Date?
    let quietHoursEnd: Date?
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
    case business = "business"
    case church = "church"
    case school = "school"
    case pto = "pto"
    case government = "government"
    case nonprofit = "nonprofit"
    case emergency = "emergency"
    case hospital = "hospital"
    case clinic = "clinic"
    case medicalPractice = "medical_practice"
    case dentalPractice = "dental_practice"
    case pharmacy = "pharmacy"
    case rehabilitation = "rehabilitation"
    case physicalTherapy = "physical_therapy"
    case mentalHealth = "mental_health"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .business: return "Business"
        case .church: return "Church/Religious Organization"
        case .school: return "School/Educational"
        case .pto: return "PTO/PTA"
        case .government: return "Government Agency"
        case .nonprofit: return "Non-Profit Organization"
        case .emergency: return "Emergency Services"
        case .hospital: return "Hospital/Medical Center"
        case .clinic: return "Medical Clinic"
        case .medicalPractice: return "Medical Practice"
        case .dentalPractice: return "Dental Practice"
        case .pharmacy: return "Pharmacy"
        case .rehabilitation: return "Rehabilitation Center"
        case .physicalTherapy: return "Physical Therapy"
        case .mentalHealth: return "Mental Health Facility"
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
    let address: String
    let city: String
    let state: String
    let zipCode: String
    let contactPersonName: String
    let contactPersonTitle: String
    let contactPersonPhone: String
    let contactPersonEmail: String
    let status: RequestStatus
    let submittedAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let reviewNotes: String?
    let verificationDocuments: [String]?
    
    init(name: String, type: OrganizationType, description: String, website: String?, phone: String?, email: String, address: String, city: String, state: String, zipCode: String, contactPersonName: String, contactPersonTitle: String, contactPersonPhone: String, contactPersonEmail: String, status: RequestStatus) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.description = description
        self.website = website
        self.phone = phone
        self.email = email
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.contactPersonName = contactPersonName
        self.contactPersonTitle = contactPersonTitle
        self.contactPersonPhone = contactPersonPhone
        self.contactPersonEmail = contactPersonEmail
        self.status = status
        self.submittedAt = Date()
        self.reviewedAt = nil
        self.reviewedBy = nil
        self.reviewNotes = nil
        self.verificationDocuments = nil
    }
    
    var coordinate: CLLocationCoordinate2D {
        // This would be geocoded from the address
        // For now, return a default coordinate
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    var fullAddress: String {
        "\(address), \(city), \(state) \(zipCode)"
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
struct OrganizationGroup: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let organizationId: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(id: String = UUID().uuidString, name: String, description: String? = nil, organizationId: String, isActive: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.organizationId = organizationId
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
