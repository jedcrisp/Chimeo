import SwiftUI
import MapKit
import UIKit

struct IncidentDetailView: View {
    let incident: Incident
    @Environment(\.dismiss) private var dismiss
    @State private var showingDirections = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with type and severity
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: incident.type.icon)
                                    .foregroundColor(incident.type.color)
                                Text(incident.type.displayName)
                                    .font(.headline)
                                    .foregroundColor(incident.type.color)
                            }
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(incident.severity.color)
                                Text(incident.severity.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(incident.severity.color)
                            }
                        }
                        
                        Spacer()
                        
                        if incident.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Title and description
                    VStack(alignment: .leading, spacing: 12) {
                        Text(incident.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(incident.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Location section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                        
                        // Mini map
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: incident.location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )))
                        .frame(height: 200)
                        .cornerRadius(10)
                        
                        // Address details
                        if let address = incident.location.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let city = incident.location.city, let state = incident.location.state {
                            Text("\(city), \(state)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Organization info
                    if let organization = incident.organization {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reported by")
                                .font(.headline)
                            
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(organization.verified ? .green : .gray)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(organization.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if organization.verified {
                                        Text("Verified Organization")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Timestamp
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reported")
                            .font(.headline)
                        
                        Text(incident.reportedAt, style: .relative)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Handle report similar incident
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Report Similar Incident")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            showingDirections = true
                        }) {
                            HStack {
                                Image(systemName: "location")
                                Text("Get Directions")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // Handle share incident
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Incident")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Incident Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingDirections) {
            DirectionsView(destination: incident.location)
        }
    }
}

struct DirectionsView: View {
    let destination: Location
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Directions to Incident")
                    .font(.headline)
                    .padding()
                
                // This would integrate with Apple Maps or Google Maps
                // For now, we'll show a placeholder
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Open in Maps")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tap below to open directions in your preferred maps app")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Open in Maps") {
                        let coordinate = destination.coordinate
                        let url = URL(string: "maps://?daddr=\(coordinate.latitude),\(coordinate.longitude)")!
                        
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                        
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .navigationTitle("Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleIncident = Incident(
        id: "1",
        title: "Traffic Accident on Main Street",
        description: "Multi-vehicle accident causing delays on Main Street near the intersection with Oak Avenue. Emergency services on scene.",
        type: .road,
        severity: .high,
        location: Location(
            latitude: 33.1032,
            longitude: -96.6705,
            address: "123 Main Street",
            city: "Allen",
            state: "TX",
            zipCode: "75013"
        ),
        organization: Organization(
            id: "org1",
            name: "Allen Police Department",
            type: "Police",
            description: "Local law enforcement agency",
            location: Location(
                latitude: 33.1032,
                longitude: -96.6705,
                address: "123 Main Street",
                city: "Allen",
                state: "TX",
                zipCode: "75013"
            ),
            verified: true,
            followerCount: 1500,
            website: nil,
            phone: nil,
            email: nil
        ),
        verified: true,
        confidence: 0.95,
        reportedAt: Date(),
        updatedAt: Date(),
        photos: nil,
        distance: 2.5,
        userId: "user123",
        reporterId: "user123"
    )
    
    IncidentDetailView(incident: sampleIncident)
} 