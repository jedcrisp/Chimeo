import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var locationManager: LocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.1032, longitude: -96.6705), // Allen, TX
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var incidents: [Incident] = []
    @State private var organizations: [Organization] = []
    @State private var showingIncidentDetail = false
    @State private var selectedIncident: Incident?
    @State private var showingFilters = false
    @State private var selectedIncidentTypes: Set<IncidentType> = Set(IncidentType.allCases)
    @State private var selectedSeverities: Set<IncidentSeverity> = Set(IncidentSeverity.allCases)
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map
                Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        annotation.view
                            .onTapGesture {
                                handleAnnotationTap(annotation)
                            }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Overlay Content
                overlayContent
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadData) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingIncidentDetail) {
                if let incident = selectedIncident {
                    IncidentDetailView(incident: incident)
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(
                    selectedIncidentTypes: $selectedIncidentTypes,
                    selectedSeverities: $selectedSeverities
                )
            }
            .onAppear {
                loadData()
            }
            .onChange(of: selectedIncidentTypes) { _, _ in
                loadData()
            }
            .onChange(of: selectedSeverities) { _, _ in
                loadData()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var mapAnnotations: [MapAnnotationItem] {
        var annotations: [MapAnnotationItem] = []
        
        // Add incident annotations
        for incident in incidents {
            if selectedIncidentTypes.contains(incident.type) && selectedSeverities.contains(incident.severity) {
                annotations.append(MapAnnotationItem(
                    coordinate: incident.location.coordinate,
                    view: IncidentAnnotationView(incident: incident),
                    type: .incident,
                    id: incident.id
                ))
            }
        }
        
        // Add organization annotations
        for organization in organizations {
            annotations.append(MapAnnotationItem(
                coordinate: organization.location.coordinate,
                view: OrganizationAnnotationView(organization: organization),
                type: .organization,
                id: organization.id
            ))
        }
        
        return annotations
    }
    
    private var overlayContent: some View {
        VStack {
            Spacer()
            
            // Map Controls
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // Location Button
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    
                    // Weather Button
                    Button(action: showWeatherInfo) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Methods
    private func loadData() {
        isLoading = true
        
        Task {
            do {
                // Load incidents
                let fetchedIncidents = try await apiService.fetchIncidents(
                    latitude: region.center.latitude,
                    longitude: region.center.longitude,
                    radius: 25.0,
                    types: Array(selectedIncidentTypes)
                )
                
                // Load organizations
                let fetchedOrganizations = try await apiService.fetchOrganizations()
                
                await MainActor.run {
                    self.incidents = fetchedIncidents
                    self.organizations = fetchedOrganizations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleAnnotationTap(_ annotation: MapAnnotationItem) {
        switch annotation.type {
        case .incident:
            if let incident = incidents.first(where: { $0.id == annotation.id }) {
                selectedIncident = incident
                showingIncidentDetail = true
            }
        case .organization:
            // Handle organization tap
            break
        }
    }
    
    private func centerOnUserLocation() {
        if let location = locationManager.currentLocation {
            withAnimation {
                region.center = location.coordinate
            }
        }
    }
    
    private func showWeatherInfo() {
        // Show weather information
        print("Weather info requested")
    }
}

// MARK: - Map Annotation Item
struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let view: AnyView
    let type: AnnotationType
    
    init(coordinate: CLLocationCoordinate2D, view: some View, type: AnnotationType, id: String) {
        self.id = id
        self.coordinate = coordinate
        self.view = AnyView(view)
        self.type = type
    }
}

enum AnnotationType {
    case incident
    case organization
}

// MARK: - Incident Annotation View
struct IncidentAnnotationView: View {
    let incident: Incident
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            // Severity indicator
            Circle()
                .fill(incident.severity.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
                .offset(y: -6)
        }
        .shadow(radius: 2)
    }
}

// MARK: - Organization Annotation View
struct OrganizationAnnotationView: View {
    let organization: Organization
    
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "building.2.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(organization.verified ? Color.green : Color.blue)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            // Verification indicator
            if organization.verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .background(Color.white)
                    .clipShape(Circle())
                    .offset(y: -6)
            }
        }
        .shadow(radius: 2)
    }
}

// MARK: - Filter View
struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIncidentTypes: Set<IncidentType>
    @Binding var selectedSeverities: Set<IncidentSeverity>
    
    var body: some View {
        NavigationView {
            Form {
                Section("Incident Types") {
                    ForEach(IncidentType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                                .frame(width: 30)
                            
                            Text(type.displayName)
                            
                            Spacer()
                            
                            if selectedIncidentTypes.contains(type) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedIncidentTypes.contains(type) {
                                selectedIncidentTypes.remove(type)
                            } else {
                                selectedIncidentTypes.insert(type)
                            }
                        }
                    }
                }
                
                Section("Severity Levels") {
                    ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                        HStack {
                            Circle()
                                .fill(severity.color)
                                .frame(width: 12, height: 12)
                            
                            Text(severity.displayName)
                            
                            Spacer()
                            
                            if selectedSeverities.contains(severity) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSeverities.contains(severity) {
                                selectedSeverities.remove(severity)
                            } else {
                                selectedSeverities.insert(severity)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
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