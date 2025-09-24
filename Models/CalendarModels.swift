//
//  CalendarModels.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Calendar Event
struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let alertId: String? // Reference to the scheduled alert
    let createdBy: String
    let createdByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let isRecurring: Bool
    let recurrencePattern: RecurrencePattern?
    let color: String // Hex color for calendar display
    
    init(id: String = UUID().uuidString, title: String, description: String? = nil, startDate: Date, endDate: Date, isAllDay: Bool = false, location: String? = nil, alertId: String? = nil, createdBy: String, createdByUserId: String, createdAt: Date = Date(), updatedAt: Date = Date(), isRecurring: Bool = false, recurrencePattern: RecurrencePattern? = nil, color: String = "#007AFF") {
        self.id = id
        self.title = title
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.alertId = alertId
        self.createdBy = createdBy
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isRecurring = isRecurring
        self.recurrencePattern = recurrencePattern
        self.color = color
    }
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var isPast: Bool {
        return endDate < Date()
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(startDate)
    }
    
    var isUpcoming: Bool {
        return startDate > Date()
    }
}

// MARK: - Recurrence Pattern
struct RecurrencePattern: Codable {
    let frequency: RecurrenceFrequency
    let interval: Int // Every X days/weeks/months/years
    let endDate: Date?
    let occurrences: Int? // Number of occurrences
    let daysOfWeek: [Int]? // 1-7 (Sunday = 1)
    let dayOfMonth: Int? // 1-31
    let weekOfMonth: Int? // 1-5 (first, second, etc.)
    
    init(frequency: RecurrenceFrequency, interval: Int = 1, endDate: Date? = nil, occurrences: Int? = nil, daysOfWeek: [Int]? = nil, dayOfMonth: Int? = nil, weekOfMonth: Int? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrences = occurrences
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
        self.weekOfMonth = weekOfMonth
    }
}

// MARK: - Recurrence Frequency
enum RecurrenceFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Scheduled Alert
struct ScheduledAlert: Identifiable, Codable {
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
    let scheduledDate: Date
    let isRecurring: Bool
    let recurrencePattern: RecurrencePattern?
    let postedBy: String
    let postedByUserId: String
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    let imageURLs: [String]
    let expiresAt: Date?
    let calendarEventId: String? // Reference to the calendar event
    
    init(id: String = UUID().uuidString, title: String, description: String, organizationId: String, organizationName: String, groupId: String? = nil, groupName: String? = nil, type: IncidentType, severity: IncidentSeverity, location: Location? = nil, scheduledDate: Date, isRecurring: Bool = false, recurrencePattern: RecurrencePattern? = nil, postedBy: String, postedByUserId: String, createdAt: Date = Date(), updatedAt: Date = Date(), isActive: Bool = true, imageURLs: [String] = [], expiresAt: Date? = nil, calendarEventId: String? = nil) {
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
        self.scheduledDate = scheduledDate
        self.isRecurring = isRecurring
        self.recurrencePattern = recurrencePattern
        self.postedBy = postedBy
        self.postedByUserId = postedByUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
        self.imageURLs = imageURLs
        self.expiresAt = expiresAt
        self.calendarEventId = calendarEventId
    }
    
    var isPast: Bool {
        return scheduledDate < Date()
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(scheduledDate)
    }
    
    var isUpcoming: Bool {
        return scheduledDate > Date()
    }
    
    var timeUntilScheduled: TimeInterval {
        return scheduledDate.timeIntervalSinceNow
    }
    
    var daysUntilScheduled: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: scheduledDate)
        return components.day ?? 0
    }
    
    // MARK: - Custom Decoder for Firestore
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle String ID
        self.id = try container.decode(String.self, forKey: .id)
        
        // Handle basic strings
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.organizationId = try container.decode(String.self, forKey: .organizationId)
        self.organizationName = try container.decode(String.self, forKey: .organizationName)
        self.postedBy = try container.decode(String.self, forKey: .postedBy)
        self.postedByUserId = try container.decode(String.self, forKey: .postedByUserId)
        
        // Handle optional strings
        self.groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        self.groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        self.calendarEventId = try container.decodeIfPresent(String.self, forKey: .calendarEventId)
        
        // Handle enums
        self.type = try container.decode(IncidentType.self, forKey: .type)
        self.severity = try container.decode(IncidentSeverity.self, forKey: .severity)
        
        // Handle optional location
        self.location = try container.decodeIfPresent(Location.self, forKey: .location)
        
        // Handle dates - convert from Firestore Timestamp or Date
        if let timestamp = try? container.decode(FirebaseFirestore.Timestamp.self, forKey: .scheduledDate) {
            self.scheduledDate = timestamp.dateValue()
        } else {
            self.scheduledDate = try container.decode(Date.self, forKey: .scheduledDate)
        }
        
        if let timestamp = try? container.decode(FirebaseFirestore.Timestamp.self, forKey: .createdAt) {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let timestamp = try? container.decode(FirebaseFirestore.Timestamp.self, forKey: .updatedAt) {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
        
        if let timestamp = try? container.decodeIfPresent(FirebaseFirestore.Timestamp.self, forKey: .expiresAt) {
            self.expiresAt = timestamp.dateValue()
        } else {
            self.expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        }
        
        // Handle booleans - convert from Int (0/1) or Bool
        if let intValue = try? container.decode(Int.self, forKey: .isRecurring) {
            self.isRecurring = intValue != 0
        } else {
            self.isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        }
        
        if let intValue = try? container.decode(Int.self, forKey: .isActive) {
            self.isActive = intValue != 0
        } else {
            self.isActive = try container.decode(Bool.self, forKey: .isActive)
        }
        
        // Handle arrays
        self.imageURLs = try container.decodeIfPresent([String].self, forKey: .imageURLs) ?? []
        
        // Handle optional recurrence pattern
        self.recurrencePattern = try container.decodeIfPresent(RecurrencePattern.self, forKey: .recurrencePattern)
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, title, description, organizationId, organizationName
        case groupId, groupName, type, severity, location, scheduledDate
        case isRecurring, recurrencePattern, postedBy, postedByUserId
        case createdAt, updatedAt, isActive, imageURLs, expiresAt, calendarEventId
    }
}

// MARK: - Calendar View Mode
enum CalendarViewMode: String, CaseIterable {
    case month = "month"
    case week = "week"
    case day = "day"
    case agenda = "agenda"
    
    var displayName: String {
        switch self {
        case .month: return "Month"
        case .week: return "Week"
        case .day: return "Day"
        case .agenda: return "Agenda"
        }
    }
}

// MARK: - Calendar Filter
struct CalendarFilter {
    var showAlerts: Bool = true
    var showEvents: Bool = true
    var selectedTypes: Set<IncidentType> = Set(IncidentType.allCases)
    var selectedSeverities: Set<IncidentSeverity> = Set(IncidentSeverity.allCases)
    var selectedGroups: Set<String> = []
    var dateRange: DateInterval?
    
    var isFiltered: Bool {
        return !showAlerts || !showEvents || 
               selectedTypes.count != IncidentType.allCases.count ||
               selectedSeverities.count != IncidentSeverity.allCases.count ||
               !selectedGroups.isEmpty ||
               dateRange != nil
    }
}

// MARK: - Calendar Event Colors
enum CalendarEventColor: String, CaseIterable {
    case blue = "#007AFF"
    case green = "#34C759"
    case orange = "#FF9500"
    case red = "#FF3B30"
    case purple = "#AF52DE"
    case pink = "#FF2D92"
    case teal = "#5AC8FA"
    case indigo = "#5856D6"
    case yellow = "#FFCC00"
    case gray = "#8E8E93"
    
    var color: Color {
        Color(hex: self.rawValue) ?? .blue
    }
    
    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .yellow: return "Yellow"
        case .gray: return "Gray"
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
