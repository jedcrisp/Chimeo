import SwiftUI
import MapKit

struct IncidentDetailView: View {
    let incident: Incident
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Description
                    descriptionSection
                    
                    // Location
                    locationSection
                    
                    // Organization (if available)
                    if let organization = incident.organization {
                        organizationSection(organization)
                    }
                    
                    // Details
                    detailsSection
                    
                    // Map
                    mapSection
                }
                .padding()
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
    }
    
    // MARK: - Sections
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: incident.type.icon)
                    .font(.title)
                    .foregroundColor(incident.type.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(incident.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(incident.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(incident.type.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(incident.type.color.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(incident.severity.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(incident.severity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(incident.severity.color.opacity(0.1))
                        .cornerRadius(8)
                    
                    if incident.verified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Verified")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Divider()
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(incident.description)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.blue)
                
                Text(incident.location.fullAddress)
                    .font(.body)
                
                Spacer()
                
                if let distance = incident.distance {
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func organizationSection(_ organization: Organization) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Organization")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(organization.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if organization.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(organization.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Label("Reported", systemImage: "clock")
                    Spacer()
                    Text(incident.reportedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Updated", systemImage: "arrow.clockwise")
                    Spacer()
                    Text(incident.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if incident.confidence > 0 {
                    HStack {
                        Label("Confidence", systemImage: "chart.bar.fill")
                        Spacer()
                        Text("\(Int(incident.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.body)
        }
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location on Map")
                .font(.headline)
                .fontWeight(.semibold)
            
            Map(position: .constant(MapCameraPosition.region(
                MKCoordinateRegion(
                    center: incident.location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            ))) {
                Annotation("Incident", coordinate: incident.location.coordinate) {
                    Image(systemName: incident.type.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(incident.type.color)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
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
        distance: 2.5
    )
    
    IncidentDetailView(incident: sampleIncident)
} 