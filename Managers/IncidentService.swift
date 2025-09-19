import Foundation
import FirebaseFirestore
import CoreLocation

// MARK: - Incident Service
class IncidentService: ObservableObject {
    
    // MARK: - Incident Fetching
    func fetchIncidents(latitude: Double, longitude: Double, radius: Double, types: [IncidentType]? = nil) async throws -> [Incident] {
        print("🔍 Fetching incidents for location: (\(latitude), \(longitude)) with radius: \(radius)km")
        
        let db = Firestore.firestore()
        let incidentsRef = db.collection("incidents")
        
        var query = incidentsRef
            .whereField("isActive", isEqualTo: true)
        
        // Filter by incident types if specified
        if let types = types, !types.isEmpty {
            let typeStrings = types.map { $0.rawValue }
            query = query.whereField("type", in: typeStrings)
        }
        
        let snapshot = try await query.getDocuments()
        
        var incidents: [Incident] = []
        
        for document in snapshot.documents {
            do {
                let incident = try parseIncidentFromFirestore(docId: document.documentID, data: document.data())
                if let inc = incident {
                    // Calculate distance from user location
                    let incidentLocation = CLLocation(latitude: inc.location.latitude, longitude: inc.location.longitude)
                    let userLocation = CLLocation(latitude: latitude, longitude: longitude)
                    let distance = incidentLocation.distance(from: userLocation) / 1000 // Convert to km
                    
                    // Only include incidents within the specified radius
                    if distance <= radius {
                        var incidentWithDistance = inc
                        // Note: This would require making distance mutable in the Incident struct
                        incidents.append(inc)
                    }
                }
            } catch {
                print("⚠️ Warning: Could not parse incident \(document.documentID): \(error)")
            }
        }
        
        // Sort by distance (closest first)
        incidents.sort { incident1, incident2 in
            let loc1 = CLLocation(latitude: incident1.location.latitude, longitude: incident1.location.longitude)
            let loc2 = CLLocation(latitude: incident2.location.latitude, longitude: incident2.location.longitude)
            let userLoc = CLLocation(latitude: latitude, longitude: longitude)
            
            let distance1 = loc1.distance(from: userLoc)
            let distance2 = loc2.distance(from: userLoc)
            
            return distance1 < distance2
        }
        
        print("✅ Found \(incidents.count) incidents within \(radius)km radius")
        return incidents
    }
    
    // MARK: - Report Incident
    func reportIncident(_ report: IncidentReport) async throws -> IncidentReport {
        print("📝 Reporting incident: \(report.title)")
        print("   Type: \(report.type.displayName)")
        print("   Severity: \(report.severity.displayName)")
        print("   Location: \(report.location.address)")
        
        let db = Firestore.firestore()
        
        // Create incident data
        let incidentData: [String: Any] = [
            "title": report.title,
            "description": report.description,
            "type": report.type.rawValue,
            "severity": report.severity.rawValue,
            "location": [
                "latitude": report.location.latitude,
                "longitude": report.location.longitude,
                "address": report.location.address,
                "city": report.location.city,
                "state": report.location.state,
                "zipCode": report.location.zipCode
            ],
            "reportedBy": report.reportedBy,
            "status": report.status.rawValue,
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        let incidentRef = db.collection("incidents").document()
        try await incidentRef.setData(incidentData)
        
        print("✅ Incident reported successfully")
        print("   📍 Incident ID: \(incidentRef.documentID)")
        
        // Return updated report with the new ID
        var updatedReport = report
        // Note: This would require making id mutable in the IncidentReport struct
        return report
    }
    
    // MARK: - Update Incident
    func updateIncident(_ incident: Incident) async throws {
        print("✏️ Updating incident: \(incident.title)")
        
        let db = Firestore.firestore()
        
        let updateData: [String: Any] = [
            "title": incident.title,
            "description": incident.description,
            "type": incident.type.rawValue,
            "severity": incident.severity.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("incidents").document(incident.id).updateData(updateData)
        
        print("✅ Incident updated successfully")
    }
    
    // MARK: - Delete Incident
    func deleteIncident(_ incidentId: String) async throws {
        print("🗑️ Deleting incident: \(incidentId)")
        
        let db = Firestore.firestore()
        
        // Soft delete by setting isActive to false
        try await db.collection("incidents").document(incidentId).updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ Incident deleted successfully")
    }
    
    // MARK: - Incident Parsing
    private func parseIncidentFromFirestore(docId: String, data: [String: Any]) throws -> Incident? {
        let title = data["title"] as? String ?? "Unknown"
        let description = data["description"] as? String ?? ""
        let typeString = data["type"] as? String ?? "other"
        let severityString = data["severity"] as? String ?? "low"
        let statusString = data["status"] as? String ?? "open"
        let locationData = data["location"] as? [String: Any] ?? [:]
        let reportedBy = data["reportedBy"] as? String ?? "Unknown"
        let reporterId = data["reporterId"] as? String ?? ""
        let isActive = data["isActive"] as? Bool ?? true
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        let location = Location(
            latitude: locationData["latitude"] as? Double ?? 0.0,
            longitude: locationData["longitude"] as? Double ?? 0.0,
            address: locationData["address"] as? String ?? "",
            city: locationData["city"] as? String ?? "",
            state: locationData["state"] as? String ?? "",
            zipCode: locationData["zipCode"] as? String ?? ""
        )
        
        let type = IncidentType(rawValue: typeString) ?? .other
        let severity = IncidentSeverity(rawValue: severityString) ?? .low
        let status = ReportStatus(rawValue: statusString) ?? .pending
        
        return Incident(
            id: docId,
            title: title,
            description: description,
            type: type,
            severity: severity,
            location: location,
            organization: nil,
            verified: false,
            confidence: 0.0,
            reportedAt: createdAt,
            updatedAt: updatedAt,
            photos: nil,
            distance: nil,
            userId: nil,
            reporterId: reporterId
        )
    }
    
    // MARK: - Address to Coordinates
    func addressToCoordinates(address: String) async throws -> (latitude: Double, longitude: Double) {
        print("📍 Converting address to coordinates: \(address)")
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            
            if let placemark = placemarks.first,
               let location = placemark.location {
                let coordinates = (latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                print("✅ Address converted successfully: (\(coordinates.latitude), \(coordinates.longitude))")
                return coordinates
            } else {
                throw IncidentError.geocodingFailed
            }
        } catch {
            print("❌ Failed to convert address to coordinates: \(error)")
            throw IncidentError.geocodingFailed
        }
    }
    
    // MARK: - Generate Firestore ID
    func generateFirestoreId(from string: String) -> String {
        let cleanString = string.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "&", with: "_and_")
        
        // Clean up multiple underscores
        var result = cleanString
        while result.contains("__") {
            result = result.replacingOccurrences(of: "__", with: "_")
        }
        
        // Remove leading/trailing underscores
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        return result
    }
}

// MARK: - Incident Errors
enum IncidentError: Error, LocalizedError {
    case geocodingFailed
    case invalidLocation
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .geocodingFailed:
            return "Failed to convert address to coordinates"
        case .invalidLocation:
            return "Invalid location data"
        case .parsingFailed:
            return "Failed to parse incident data"
        }
    }
}
