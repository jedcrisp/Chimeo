import SwiftUI
import CoreLocation
import UIKit

struct WeatherAlertView: View {
    let alert: WeatherAlert
    @Environment(\.dismiss) private var dismiss
    @State private var showingMap = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with alert type and severity
                    alertHeader
                    
                    // Alert details
                    alertDetails
                    
                    // Instructions
                    if let instructions = alert.instructions {
                        instructionsSection(instructions)
                    }
                    
                    // Location information
                    locationSection
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Weather Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingMap) {
            WeatherAlertMapView(alert: alert)
        }
    }
    
    private var alertHeader: some View {
        VStack(spacing: 16) {
            // Alert icon and type
            VStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(alert.type.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
                
                Text(alert.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(alert.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Severity indicator
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(alert.severity.color)
                
                Text(alert.severity.displayName)
                    .font(.headline)
                    .foregroundColor(alert.severity.color)
                
                Spacer()
                
                Text(alert.formattedTimeRemaining)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding()
            .background(alert.severity.color.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var alertDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Alert Details")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(
                    icon: "text.bubble",
                    title: "Description",
                    value: alert.description
                )
                
                DetailRow(
                    icon: "clock",
                    title: "Effective Time",
                    value: formatDate(alert.effectiveTime)
                )
                
                DetailRow(
                    icon: "clock.badge.xmark",
                    title: "Expires",
                    value: formatDate(alert.expirationTime)
                )
                
                DetailRow(
                    icon: "building.2",
                    title: "Source",
                    value: alert.source
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func instructionsSection(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety Instructions")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(instructions)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Affected Area")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                if let distance = alert.distance {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        
                        Text("\(String(format: "%.1f", distance)) miles from your location")
                            .font(.body)
                    }
                }
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    Text(alert.location.fullAddress)
                        .font(.body)
                }
                
                Button("View on Map") {
                    showingMap = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Share Alert") {
                shareAlert()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            Button("Get More Info") {
                openWeatherWebsite()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func shareAlert() {
        let alertText = """
        Weather Alert: \(alert.title)
        
        \(alert.description)
        
        Severity: \(alert.severity.displayName)
        Location: \(alert.location.fullAddress)
        Expires: \(formatDate(alert.expirationTime))
        
        Stay safe and follow local weather reports.
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [alertText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func openWeatherWebsite() {
        // In a real app, you'd open the National Weather Service website
        // or your app's weather information page
        if let url = URL(string: "https://www.weather.gov") {
            UIApplication.shared.open(url)
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

struct WeatherAlertMapView: View {
    let alert: WeatherAlert
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: alert.location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )))
            .ignoresSafeArea(edges: .bottom)
            .overlay(
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Text(alert.title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text(alert.location.fullAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                }
            )
            .navigationTitle("Alert Location")
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
    let sampleAlert = WeatherAlert(
        id: "test-1",
        type: .severeThunderstorm,
        title: "Severe Thunderstorm Warning",
        description: "A severe thunderstorm has been detected in your area with potential for damaging winds and hail.",
        severity: .high,
        location: Location(
            latitude: 33.1032,
            longitude: -96.6705,
            city: "Allen",
            state: "TX"
        ),
        effectiveTime: Date().addingTimeInterval(-3600),
        expirationTime: Date().addingTimeInterval(3600),
        instructions: "Stay indoors and away from windows. Avoid using electrical appliances and plumbing.",
        source: "National Weather Service",
        polygon: nil,
        distance: 2.5
    )
    
    return WeatherAlertView(alert: sampleAlert)
}
