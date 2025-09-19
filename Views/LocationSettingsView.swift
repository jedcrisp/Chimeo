import SwiftUI
import CoreLocation

// MARK: - Location Type for Settings
enum LocationSettingType: String, CaseIterable {
    case home = "home"
    case work = "work"
    case school = "school"
    
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .school: return "School"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .home: return .blue
        case .work: return .green
        case .school: return .orange
        }
    }
}

struct LocationSettingsView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingAddLocation = false
    @State private var selectedLocationType: LocationSettingType = .home
    @State private var editingLocation: Location?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Your Locations")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Manage your home, work, and school locations for personalized alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            // Current Location Status
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(locationManager.isLocationEnabled ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location Access")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(locationManager.isLocationEnabled ? "Enabled" : "Disabled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !locationManager.isLocationEnabled {
                        Button("Enable") {
                            locationManager.requestLocationPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            // Location List
            VStack(spacing: 16) {
                HStack {
                    Text("Saved Locations")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Add Location") {
                        showingAddLocation = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                
                if let user = apiService.currentUser {
                    VStack(spacing: 12) {
                        if let homeLocation = user.homeLocation {
                            LocationRow(
                                location: homeLocation,
                                type: .home,
                                onEdit: { editingLocation = homeLocation }
                            )
                        }
                        
                        if let workLocation = user.workLocation {
                            LocationRow(
                                location: workLocation,
                                type: .work,
                                onEdit: { editingLocation = workLocation }
                            )
                        }
                        
                        if let schoolLocation = user.schoolLocation {
                            LocationRow(
                                location: schoolLocation,
                                type: .school,
                                onEdit: { editingLocation = schoolLocation }
                            )
                        }
                        
                        if user.homeLocation == nil && user.workLocation == nil && user.schoolLocation == nil {
                            VStack(spacing: 16) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("No locations saved")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Add your home, work, or school location to receive personalized alerts")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            )
                        }
                    }
                }
            }
            
            // Description
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why set locations?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("LocalAlert uses your locations to send you relevant alerts for incidents in your area. The more locations you add, the better we can serve you.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView()
        }
        .sheet(item: $editingLocation) { location in
            EditLocationView(location: location)
        }
    }
}

// MARK: - Location Row
struct LocationRow: View {
    let location: Location
    let type: LocationSettingType
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let address = location.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let city = location.city, let state = location.state {
                    Text("\(city), \(state)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Edit") {
                onEdit()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// LocationSettingType is defined above for this view

// MARK: - Add Location View (Placeholder)
struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Add Location View")
                    .font(.title)
                
                Text("This view would allow users to add new locations")
                    .foregroundColor(.secondary)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Edit Location View (Placeholder)
struct EditLocationView: View {
    let location: Location
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Edit Location View")
                    .font(.title)
                
                Text("This view would allow users to edit existing locations")
                    .foregroundColor(.secondary)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Edit Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        LocationSettingsView()
            .environmentObject(APIService())
            .environmentObject(LocationManager())
    }
}
