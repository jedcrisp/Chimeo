import SwiftUI
import PhotosUI
import MapKit

struct ReportView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var apiService: APIService
    @State private var title = ""
    @State private var description = ""
    @State private var selectedIncidentType: IncidentType = .other
    @State private var selectedSeverity: IncidentSeverity = .medium
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingLocationPicker = false
    @State private var showingMapLocationPicker = false
    @State private var customLocation: Location?
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Incident Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                // Incident Type and Severity
                Section("Classification") {
                    Picker("Type", selection: $selectedIncidentType) {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(severity.color)
                                Text(severity.displayName)
                            }
                            .tag(severity)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Photos
                Section("Photos (Optional)") {
                    PhotosPicker(selection: $selectedPhotos, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Select Photos")
                        }
                    }
                    
                    if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count) photo(s) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Location
                Section("Location") {
                    if let customLocation = customLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let address = customLocation.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button("Change Location") {
                                showingLocationPicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    } else {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text("Using current location")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Set Custom Location") {
                            showingLocationPicker = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                // Submit Button
                Section {
                    Button(action: submitReport) {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Submitting...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit Report")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Report Incident")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $customLocation)
            }
            .sheet(isPresented: $showingMapLocationPicker) {
                MapLocationPickerView(selectedLocation: $customLocation)
            }
            .alert(isSuccess ? "Success" : "Error", isPresented: $showingAlert) {
                Button("OK") {
                    if isSuccess {
                        // Reset form on success
                        resetForm()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func submitReport() {
        guard !title.isEmpty && !description.isEmpty else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let location: Location
                if let customLocation = customLocation {
                    location = customLocation
                } else {
                    location = await getCurrentLocation()
                }
                
                let report = IncidentReport(
                    id: UUID().uuidString,
                    title: title,
                    description: description,
                    type: selectedIncidentType,
                    severity: selectedSeverity,
                    location: location,
                    photos: [], // In a real app, you'd upload photos and get URLs
                    reportedBy: apiService.currentUser?.id ?? "anonymous",
                    status: .pending,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                _ = try await apiService.reportIncident(report)
                
                await MainActor.run {
                    isSubmitting = false
                    isSuccess = true
                    alertMessage = "Your report has been submitted successfully and is pending review."
                    showingAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isSuccess = false
                    alertMessage = "Failed to submit report: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func getCurrentLocation() async -> Location {
        guard let currentLocation = locationManager.currentLocation else {
            // Fallback to Allen, TX coordinates
            return Location(
                latitude: 33.1032,
                longitude: -96.6705,
                address: nil,
                city: "Allen",
                state: "TX",
                zipCode: "75013"
            )
        }
        
        let placemark = await locationManager.reverseGeocode(location: currentLocation)
        
        return Location(
            latitude: currentLocation.coordinate.latitude,
            longitude: currentLocation.coordinate.longitude,
            address: placemark?.thoroughfare != nil ? "\(placemark?.subThoroughfare ?? "") \(placemark?.thoroughfare ?? "")" : nil,
            city: placemark?.locality,
            state: placemark?.administrativeArea,
            zipCode: placemark?.postalCode
        )
    }
    
    private func resetForm() {
        title = ""
        description = ""
        selectedIncidentType = .other
        selectedSeverity = .medium
        selectedPhotos = []
        customLocation = nil
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: Location?
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search for address...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding()
                
                // Search results
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    Text("No results found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(searchResults) { result in
                        Button(action: {
                            selectedLocation = result.location
                            dismiss()
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.headline)
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Map") {
                        // This would show the map picker
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        Task {
            // In a real app, you'd use a geocoding service
            // For now, we'll create mock results
            await MainActor.run {
                searchResults = [
                    SearchResult(
                        title: searchText,
                        subtitle: "Allen, TX",
                        location: Location(
                            latitude: 33.1032,
                            longitude: -96.6705,
                            address: searchText,
                            city: "Allen",
                            state: "TX",
                            zipCode: "75013"
                        )
                    )
                ]
                isSearching = false
            }
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let location: Location
}

// MARK: - Map Location Picker View
struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: Location?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Map Location Picker")
                    .font(.headline)
                    .padding()
                
                Text("Tap the button below to use your current location")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button("Use Current Location") {
                    // For now, we'll use a default location
                    // In a real app, you'd get the actual current location
                    selectedLocation = Location(
                        latitude: 33.1032,
                        longitude: -96.6705,
                        address: "Current Location",
                        city: "Allen",
                        state: "TX",
                        zipCode: "75013"
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ReportView()
        .environmentObject(LocationManager())
        .environmentObject(APIService())
} 