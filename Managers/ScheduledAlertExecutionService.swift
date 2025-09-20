//
//  ScheduledAlertExecutionService.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Scheduled Alert Execution Service
class ScheduledAlertExecutionService: ObservableObject {
    private let db = Firestore.firestore()
    private let organizationAlertService: OrganizationAlertService
    private let notificationService: iOSNotificationService
    
    @Published var isRunning = false
    @Published var lastExecutionTime: Date?
    @Published var executionCount = 0
    
    init(organizationAlertService: OrganizationAlertService = OrganizationAlertService(), notificationService: iOSNotificationService = iOSNotificationService()) {
        self.organizationAlertService = organizationAlertService
        self.notificationService = notificationService
    }
    
    // MARK: - Main Execution Method
    
    func executeScheduledAlerts() async {
        print("⏰ Starting scheduled alert execution...")
        
        isRunning = true
        lastExecutionTime = Date()
        
        do {
            // Get all active scheduled alerts that are due
            let dueAlerts = try await getDueScheduledAlerts()
            
            print("📋 Found \(dueAlerts.count) due scheduled alerts")
            
            for alert in dueAlerts {
                await executeScheduledAlert(alert)
            }
            
            executionCount += dueAlerts.count
            
            print("✅ Scheduled alert execution completed. Processed \(dueAlerts.count) alerts")
            
        } catch {
            print("❌ Error executing scheduled alerts: \(error)")
        }
        
        isRunning = false
    }
    
    // MARK: - Get Due Scheduled Alerts
    
    private func getDueScheduledAlerts() async throws -> [ScheduledAlert] {
        let now = Date()
        
        let query = db.collection("scheduledAlerts")
            .whereField("isActive", isEqualTo: true)
            .whereField("scheduledDate", isLessThanOrEqualTo: now)
            .order(by: "scheduledDate", descending: false)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: ScheduledAlert.self)
        }
    }
    
    // MARK: - Execute Individual Scheduled Alert
    
    private func executeScheduledAlert(_ alert: ScheduledAlert) async {
        print("🚨 Executing scheduled alert: \(alert.title)")
        
        do {
            // Convert scheduled alert to organization alert
            let organizationAlert = OrganizationAlert(
                title: alert.title,
                description: alert.description,
                organizationId: alert.organizationId,
                organizationName: alert.organizationName,
                groupId: alert.groupId,
                groupName: alert.groupName,
                type: alert.type,
                severity: alert.severity,
                location: alert.location,
                postedBy: alert.postedBy,
                postedByUserId: alert.postedByUserId,
                imageURLs: alert.imageURLs
            )
            
            // Post the alert through the organization alert service
            try await organizationAlertService.postOrganizationAlert(organizationAlert)
            
            // Handle recurrence if applicable
            if alert.isRecurring, let pattern = alert.recurrencePattern {
                await handleRecurrence(for: alert, pattern: pattern)
            } else {
                // Deactivate the alert since it's not recurring
                await deactivateScheduledAlert(alert.id)
            }
            
            print("✅ Successfully executed scheduled alert: \(alert.title)")
            
        } catch {
            print("❌ Error executing scheduled alert \(alert.title): \(error)")
        }
    }
    
    // MARK: - Handle Recurrence
    
    private func handleRecurrence(for alert: ScheduledAlert, pattern: RecurrencePattern) async {
        print("🔄 Handling recurrence for alert: \(alert.title)")
        
        do {
            // Calculate next occurrence
            guard let nextDate = calculateNextOccurrence(from: alert.scheduledDate, pattern: pattern) else {
                print("❌ Could not calculate next occurrence for alert: \(alert.title)")
                await deactivateScheduledAlert(alert.id)
                return
            }
            
            // Check if we should continue recurring
            if let endDate = pattern.endDate, nextDate > endDate {
                print("📅 Recurrence end date reached for alert: \(alert.title)")
                await deactivateScheduledAlert(alert.id)
                return
            }
            
            // Update the scheduled date for the next occurrence
            let updatedAlert = ScheduledAlert(
                id: alert.id,
                title: alert.title,
                description: alert.description,
                organizationId: alert.organizationId,
                organizationName: alert.organizationName,
                groupId: alert.groupId,
                groupName: alert.groupName,
                type: alert.type,
                severity: alert.severity,
                location: alert.location,
                scheduledDate: nextDate,
                isRecurring: alert.isRecurring,
                recurrencePattern: alert.recurrencePattern,
                postedBy: alert.postedBy,
                postedByUserId: alert.postedByUserId,
                createdAt: alert.createdAt,
                updatedAt: Date(),
                isActive: alert.isActive,
                imageURLs: alert.imageURLs,
                expiresAt: alert.expiresAt,
                calendarEventId: alert.calendarEventId
            )
            
            try await db.collection("scheduledAlerts").document(alert.id).setData(updatedAlert.toDictionary())
            
            print("✅ Updated scheduled alert for next occurrence: \(nextDate)")
            
        } catch {
            print("❌ Error handling recurrence for alert \(alert.title): \(error)")
        }
    }
    
    // MARK: - Calculate Next Occurrence
    
    private func calculateNextOccurrence(from date: Date, pattern: RecurrencePattern) -> Date? {
        let calendar = Calendar.current
        
        switch pattern.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: pattern.interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: pattern.interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: pattern.interval, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: pattern.interval, to: date)
        }
    }
    
    // MARK: - Deactivate Scheduled Alert
    
    private func deactivateScheduledAlert(_ alertId: String) async {
        do {
            try await db.collection("scheduledAlerts").document(alertId).updateData([
                "isActive": false,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Deactivated scheduled alert: \(alertId)")
            
        } catch {
            print("❌ Error deactivating scheduled alert \(alertId): \(error)")
        }
    }
    
    // MARK: - Background Execution
    
    func startBackgroundExecution() {
        print("🔄 Starting background execution for scheduled alerts")
        
        // Execute immediately
        Task {
            await executeScheduledAlerts()
        }
        
        // Set up timer for periodic execution (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.executeScheduledAlerts()
            }
        }
    }
    
    // MARK: - Cleanup Expired Alerts
    
    func cleanupExpiredAlerts() async {
        print("🧹 Cleaning up expired scheduled alerts...")
        
        do {
            let now = Date()
            
            let query = db.collection("scheduledAlerts")
                .whereField("isActive", isEqualTo: true)
                .whereField("expiresAt", isLessThan: now)
            
            let snapshot = try await query.getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.updateData([
                    "isActive": false,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
            
            print("✅ Cleaned up \(snapshot.documents.count) expired scheduled alerts")
            
        } catch {
            print("❌ Error cleaning up expired alerts: \(error)")
        }
    }
}

// MARK: - ScheduledAlert Extension for Dictionary Conversion
extension ScheduledAlert {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "description": description,
            "organizationId": organizationId,
            "organizationName": organizationName,
            "groupId": groupId ?? "",
            "groupName": groupName ?? "",
            "type": type.rawValue,
            "severity": severity.rawValue,
            "location": [
                "latitude": location?.latitude ?? 0.0,
                "longitude": location?.longitude ?? 0.0,
                "address": location?.address ?? "",
                "city": location?.city ?? "",
                "state": location?.state ?? "",
                "zipCode": location?.zipCode ?? ""
            ],
            "scheduledDate": scheduledDate,
            "isRecurring": isRecurring,
            "recurrencePattern": recurrencePattern?.toDictionary() ?? [:],
            "postedBy": postedBy,
            "postedByUserId": postedByUserId,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "isActive": isActive,
            "imageURLs": imageURLs,
            "expiresAt": expiresAt ?? FieldValue.serverTimestamp(),
            "calendarEventId": calendarEventId ?? ""
        ]
        
        return dict
    }
}
