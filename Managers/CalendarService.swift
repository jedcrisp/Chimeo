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
    
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(notificationService: iOSNotificationService = iOSNotificationService()) {
        self.notificationService = notificationService
    }
    
    // MARK: - Calendar Event Management
    
    func createEvent(_ event: CalendarEvent) async throws {
        print("📅 Creating calendar event: \(event.title)")
        
        let eventData: [String: Any] = [
            "title": event.title,
            "description": event.description ?? "",
            "startDate": event.startDate,
            "endDate": event.endDate,
            "isAllDay": event.isAllDay,
            "location": event.location ?? "",
            "alertId": event.alertId ?? "",
            "createdBy": event.createdBy,
            "createdByUserId": event.createdByUserId,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isRecurring": event.isRecurring,
            "recurrencePattern": event.recurrencePattern?.toDictionary() ?? [:],
            "color": event.color
        ]
        
        try await db.collection("calendarEvents").document(event.id).setData(eventData)
        
        await MainActor.run {
            self.events.append(event)
        }
        
        print("✅ Calendar event created successfully")
    }
    
    func updateEvent(_ event: CalendarEvent) async throws {
        print("📅 Updating calendar event: \(event.title)")
        
        let eventData: [String: Any] = [
            "title": event.title,
            "description": event.description ?? "",
            "startDate": event.startDate,
            "endDate": event.endDate,
            "isAllDay": event.isAllDay,
            "location": event.location ?? "",
            "alertId": event.alertId ?? "",
            "createdBy": event.createdBy,
            "createdByUserId": event.createdByUserId,
            "createdAt": event.createdAt,
            "updatedAt": FieldValue.serverTimestamp(),
            "isRecurring": event.isRecurring,
            "recurrencePattern": event.recurrencePattern?.toDictionary() ?? [:],
            "color": event.color
        ]
        
        try await db.collection("calendarEvents").document(event.id).setData(eventData)
        
        await MainActor.run {
            if let index = self.events.firstIndex(where: { $0.id == event.id }) {
                self.events[index] = event
            }
        }
        
        print("✅ Calendar event updated successfully")
    }
    
    func deleteEvent(_ eventId: String) async throws {
        print("📅 Deleting calendar event: \(eventId)")
        
        try await db.collection("calendarEvents").document(eventId).delete()
        
        await MainActor.run {
            self.events.removeAll { $0.id == eventId }
        }
        
        print("✅ Calendar event deleted successfully")
    }
    
    func fetchEvents(for dateRange: DateInterval? = nil) async throws {
        print("📅 Fetching calendar events...")
        
        isLoading = true
        errorMessage = nil
        
        do {
            var query = db.collection("calendarEvents")
                .order(by: "startDate", descending: false)
            
            if let dateRange = dateRange {
                query = query
                    .whereField("startDate", isGreaterThanOrEqualTo: dateRange.start)
                    .whereField("startDate", isLessThanOrEqualTo: dateRange.end)
            }
            
            let snapshot = try await query.getDocuments()
            
            let fetchedEvents = snapshot.documents.compactMap { doc -> CalendarEvent? in
                try? doc.data(as: CalendarEvent.self)
            }
            
            await MainActor.run {
                self.events = fetchedEvents
                self.isLoading = false
            }
            
            print("✅ Fetched \(fetchedEvents.count) calendar events")
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error fetching calendar events: \(error)")
            throw error
        }
    }
    
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
            try await fetchEvents(for: dateRange)
            print("✅ Calendar data fetched successfully")
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
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date) ||
            calendar.isDate(event.endDate, inSameDayAs: date) ||
            (event.startDate <= date && event.endDate >= date)
        }
    }
    
    func getTodaysEvents() -> [CalendarEvent] {
        return getEventsForDate(Date())
    }
    
    // MARK: - Scheduled Alert Fetching (for specific dates)
    
    func getScheduledAlertsForDate(_ date: Date) -> [ScheduledAlert] {
        // Since we removed local caching, this now returns an empty array
        // Views that need scheduled alerts should fetch them directly from Firestore
        // or we could implement a direct Firestore query here
        return []
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
