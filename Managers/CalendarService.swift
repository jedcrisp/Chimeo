//
//  CalendarService.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Calendar Service
class CalendarService: ObservableObject {
    private let db = Firestore.firestore()
    private let notificationService: iOSNotificationService
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(notificationService: iOSNotificationService = iOSNotificationService()) {
        self.notificationService = notificationService
    }
    
    // MARK: - Calendar Event Management (Removed - using only scheduled alerts now)
    
    // MARK: - Scheduled Alert Management
    
    func createScheduledAlert(_ alert: ScheduledAlert) async throws {
        print("⏰ Creating scheduled alert: \(alert.title)")
        
        let alertData: [String: Any] = [
            "id": alert.id,
            "title": alert.title,
            "description": alert.description,
            "organizationId": alert.organizationId,
            "organizationName": alert.organizationName,
            "groupId": alert.groupId ?? "",
            "groupName": alert.groupName ?? "",
            "type": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": [
                "latitude": alert.location?.latitude ?? 0.0,
                "longitude": alert.location?.longitude ?? 0.0,
                "address": alert.location?.address ?? "",
                "city": alert.location?.city ?? "",
                "state": alert.location?.state ?? "",
                "zipCode": alert.location?.zipCode ?? ""
            ],
            "scheduledDate": alert.scheduledDate,
            "isRecurring": alert.isRecurring,
            "recurrencePattern": alert.recurrencePattern?.toDictionary() ?? [:],
            "postedBy": alert.postedBy,
            "postedByUserId": alert.postedByUserId,
            "createdAt": alert.createdAt,
            "updatedAt": Date(),
            "isActive": alert.isActive,
            "imageURLs": alert.imageURLs,
            "expiresAt": alert.expiresAt ?? Date(),
            "calendarEventId": alert.calendarEventId ?? ""
        ]
        
        // Create separate data for scheduledAlerts collection with server timestamps
        let scheduledAlertData: [String: Any] = [
            "title": alert.title,
            "description": alert.description,
            "organizationId": alert.organizationId,
            "organizationName": alert.organizationName,
            "groupId": alert.groupId ?? "",
            "groupName": alert.groupName ?? "",
            "type": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": [
                "latitude": alert.location?.latitude ?? 0.0,
                "longitude": alert.location?.longitude ?? 0.0,
                "address": alert.location?.address ?? "",
                "city": alert.location?.city ?? "",
                "state": alert.location?.state ?? "",
                "zipCode": alert.location?.zipCode ?? ""
            ],
            "scheduledDate": alert.scheduledDate,
            "isRecurring": alert.isRecurring,
            "recurrencePattern": alert.recurrencePattern?.toDictionary() ?? [:],
            "postedBy": alert.postedBy,
            "postedByUserId": alert.postedByUserId,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": alert.isActive,
            "imageURLs": alert.imageURLs,
            "expiresAt": alert.expiresAt ?? FieldValue.serverTimestamp(),
            "calendarEventId": alert.calendarEventId ?? ""
        ]
        
        // Only add to organization's scheduledAlerts subcollection
        let orgScheduledAlertRef = db.collection("organizations")
            .document(alert.organizationId)
            .collection("scheduledAlerts")
            .document(alert.id)
        
        try await orgScheduledAlertRef.setData(scheduledAlertData)
        print("✅ Scheduled alert created successfully")
        
        // Verify the data was saved by reading it back
        let verifyRef = db.collection("organizations")
            .document(alert.organizationId)
            .collection("scheduledAlerts")
        let verifySnapshot = try await verifyRef.getDocuments()
        print("🔍 Verification - Scheduled alerts count in organization subcollection: \(verifySnapshot.documents.count)")
        if let lastDoc = verifySnapshot.documents.last {
            let lastAlert = lastDoc.data()
            print("🔍 Verification - Last alert title: \(lastAlert["title"] as? String ?? "Unknown")")
        }
        
        print("   📍 Added to organization subcollection: organizations/\(alert.organizationId)/scheduledAlerts")
    }
    
    func updateScheduledAlert(_ alert: ScheduledAlert) async throws {
        print("⏰ Updating scheduled alert: \(alert.title)")
        
        let alertData: [String: Any] = [
            "id": alert.id,
            "title": alert.title,
            "description": alert.description,
            "organizationId": alert.organizationId,
            "organizationName": alert.organizationName,
            "groupId": alert.groupId ?? "",
            "groupName": alert.groupName ?? "",
            "type": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": [
                "latitude": alert.location?.latitude ?? 0.0,
                "longitude": alert.location?.longitude ?? 0.0,
                "address": alert.location?.address ?? "",
                "city": alert.location?.city ?? "",
                "state": alert.location?.state ?? "",
                "zipCode": alert.location?.zipCode ?? ""
            ],
            "scheduledDate": alert.scheduledDate,
            "isRecurring": alert.isRecurring,
            "recurrencePattern": alert.recurrencePattern?.toDictionary() ?? [:],
            "postedBy": alert.postedBy,
            "postedByUserId": alert.postedByUserId,
            "createdAt": alert.createdAt,
            "updatedAt": Date(),
            "isActive": alert.isActive,
            "imageURLs": alert.imageURLs,
            "expiresAt": alert.expiresAt ?? Date(),
            "calendarEventId": alert.calendarEventId ?? ""
        ]
        
        // Create separate data for scheduledAlerts collection with server timestamps
        let scheduledAlertData: [String: Any] = [
            "title": alert.title,
            "description": alert.description,
            "organizationId": alert.organizationId,
            "organizationName": alert.organizationName,
            "groupId": alert.groupId ?? "",
            "groupName": alert.groupName ?? "",
            "type": alert.type.rawValue,
            "severity": alert.severity.rawValue,
            "location": [
                "latitude": alert.location?.latitude ?? 0.0,
                "longitude": alert.location?.longitude ?? 0.0,
                "address": alert.location?.address ?? "",
                "city": alert.location?.city ?? "",
                "state": alert.location?.state ?? "",
                "zipCode": alert.location?.zipCode ?? ""
            ],
            "scheduledDate": alert.scheduledDate,
            "isRecurring": alert.isRecurring,
            "recurrencePattern": alert.recurrencePattern?.toDictionary() ?? [:],
            "postedBy": alert.postedBy,
            "postedByUserId": alert.postedByUserId,
            "createdAt": alert.createdAt,
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": alert.isActive,
            "imageURLs": alert.imageURLs,
            "expiresAt": alert.expiresAt ?? FieldValue.serverTimestamp(),
            "calendarEventId": alert.calendarEventId ?? ""
        ]
        
        // Only update in organization's scheduledAlerts subcollection
        let orgScheduledAlertRef = db.collection("organizations")
            .document(alert.organizationId)
            .collection("scheduledAlerts")
            .document(alert.id)
        
        try await orgScheduledAlertRef.setData(scheduledAlertData)
        
        print("✅ Scheduled alert updated successfully")
        print("   📍 Updated in organization subcollection: organizations/\(alert.organizationId)/scheduledAlerts")
    }
    
    func deleteScheduledAlert(_ alertId: String, organizationId: String) async throws {
        print("⏰ Deleting scheduled alert: \(alertId)")
        
        // Only delete from organization's scheduledAlerts subcollection
        let orgScheduledAlertRef = db.collection("organizations")
            .document(organizationId)
            .collection("scheduledAlerts")
            .document(alertId)
        
        try await orgScheduledAlertRef.delete()
        
        print("✅ Scheduled alert deleted successfully")
        print("   📍 Removed from organization subcollection: organizations/\(organizationId)/scheduledAlerts")
    }
    
    
    // MARK: - Combined Calendar Data
    
    func fetchCalendarData(for dateRange: DateInterval? = nil) async throws {
        print("📅 Fetching calendar data...")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // No longer fetching calendar events - only using scheduled alerts
            await MainActor.run {
                self.isLoading = false
            }
            print("✅ Calendar data fetched successfully (scheduled alerts only)")
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error fetching calendar data: \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    func getEventsForDate(_ date: Date) -> [CalendarEvent] {
        // No longer using calendar events - only scheduled alerts
        return []
    }
    
    func getTodaysEvents() -> [CalendarEvent] {
        // No longer using calendar events - only scheduled alerts
        return []
    }
    
    // MARK: - Scheduled Alert Fetching (for specific dates)
    
    func getScheduledAlertsForDate(_ date: Date) -> [ScheduledAlert] {
        // Since we removed local caching, this now returns an empty array
        // Views that need scheduled alerts should fetch them directly from Firestore
        // or we could implement a direct Firestore query here
        return []
    }
    
    // MARK: - Fetch Scheduled Alerts from Firestore
    
    func fetchScheduledAlertsForDate(_ date: Date) async throws -> [ScheduledAlert] {
        print("⏰ Fetching scheduled alerts for date: \(date)")
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        // Get all organizations first
        let organizationsSnapshot = try await db.collection("organizations").getDocuments()
        var allAlerts: [ScheduledAlert] = []
        
        for orgDoc in organizationsSnapshot.documents {
            let orgId = orgDoc.documentID
            
            // Query scheduled alerts for this organization within the date range
            // First get all alerts in the date range, then filter by isActive in code
            let alertsQuery = db.collection("organizations")
                .document(orgId)
                .collection("scheduledAlerts")
                .whereField("scheduledDate", isGreaterThanOrEqualTo: startOfDay)
                .whereField("scheduledDate", isLessThan: endOfDay)
            
            let alertsSnapshot = try await alertsQuery.getDocuments()
            
            for alertDoc in alertsSnapshot.documents {
                do {
                    // Create a ScheduledAlert by manually parsing the data and using document ID
                    let data = alertDoc.data()
                    let alert = try ScheduledAlert.fromFirestoreData(data, documentId: alertDoc.documentID)
                    
                    // Filter by isActive in code instead of query
                    if alert.isActive {
                        allAlerts.append(alert)
                    }
                } catch {
                    print("❌ Failed to parse alert document: \(alertDoc.documentID)")
                    print("❌ Parsing error: \(error)")
                }
            }
        }
        
        // Sort by scheduled date
        allAlerts.sort { $0.scheduledDate < $1.scheduledDate }
        
        print("✅ Found \(allAlerts.count) scheduled alerts for \(date)")
        return allAlerts
    }
    
    func fetchScheduledAlertsForDateRange(_ startDate: Date, endDate: Date) async throws -> [ScheduledAlert] {
        print("⏰ Fetching scheduled alerts for date range: \(startDate) to \(endDate)")
        
        // Get all organizations first
        let organizationsSnapshot = try await db.collection("organizations").getDocuments()
        print("📋 Found \(organizationsSnapshot.documents.count) organizations")
        var allAlerts: [ScheduledAlert] = []
        
        for orgDoc in organizationsSnapshot.documents {
            let orgId = orgDoc.documentID
            print("🔍 Checking organization: \(orgId)")
            
            // Query scheduled alerts for this organization within the date range
            // First get all alerts in the date range, then filter by isActive in code
            let alertsQuery = db.collection("organizations")
                .document(orgId)
                .collection("scheduledAlerts")
                .whereField("scheduledDate", isGreaterThanOrEqualTo: startDate)
                .whereField("scheduledDate", isLessThanOrEqualTo: endDate)
            
            let alertsSnapshot = try await alertsQuery.getDocuments()
            print("📅 Found \(alertsSnapshot.documents.count) alerts in organization \(orgId)")
            
            for alertDoc in alertsSnapshot.documents {
                print("📄 Processing alert document: \(alertDoc.documentID)")
                do {
                    // Create a ScheduledAlert by manually parsing the data and using document ID
                    let data = alertDoc.data()
                    let alert = try ScheduledAlert.fromFirestoreData(data, documentId: alertDoc.documentID)
                    
                    // Filter by isActive in code instead of query
                    if alert.isActive {
                        print("✅ Successfully parsed active alert: \(alert.title) for date: \(alert.scheduledDate)")
                        allAlerts.append(alert)
                    } else {
                        print("⏸️ Skipping inactive alert: \(alert.title)")
                    }
                } catch {
                    print("❌ Failed to parse alert document: \(alertDoc.documentID)")
                    print("❌ Parsing error: \(error)")
                    print("📄 Document data: \(alertDoc.data())")
                }
            }
        }
        
        // Sort by scheduled date
        allAlerts.sort { $0.scheduledDate < $1.scheduledDate }
        
        print("✅ Found \(allAlerts.count) scheduled alerts for date range")
        for alert in allAlerts {
            print("📋 Alert: \(alert.title) - \(alert.scheduledDate)")
        }
        return allAlerts
    }
}

// MARK: - Recurrence Pattern Extension
extension RecurrencePattern {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "frequency": frequency.rawValue,
            "interval": interval
        ]
        
        if let endDate = endDate {
            dict["endDate"] = endDate
        }
        
        if let occurrences = occurrences {
            dict["occurrences"] = occurrences
        }
        
        if let daysOfWeek = daysOfWeek {
            dict["daysOfWeek"] = daysOfWeek
        }
        
        if let dayOfMonth = dayOfMonth {
            dict["dayOfMonth"] = dayOfMonth
        }
        
        if let weekOfMonth = weekOfMonth {
            dict["weekOfMonth"] = weekOfMonth
        }
        
        return dict
    }
    
    init?(from dictionary: [String: Any]) {
        guard let frequencyString = dictionary["frequency"] as? String,
              let frequency = RecurrenceFrequency(rawValue: frequencyString),
              let interval = dictionary["interval"] as? Int else {
            return nil
        }
        
        self.frequency = frequency
        self.interval = interval
        self.endDate = dictionary["endDate"] as? Date
        self.occurrences = dictionary["occurrences"] as? Int
        self.daysOfWeek = dictionary["daysOfWeek"] as? [Int]
        self.dayOfMonth = dictionary["dayOfMonth"] as? Int
        self.weekOfMonth = dictionary["weekOfMonth"] as? Int
    }
}
