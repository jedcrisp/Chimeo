import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

// MARK: - Map Annotation Models
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    
    enum AnnotationType {
        case userLocation
        case incident(Incident)
        case organization(Organization)
    }
}

struct MapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: SimpleAuthManager
    @StateObject private var serviceCoordinator = ServiceCoordinator()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.2148, longitude: -97.1331), // Denton, TX area (better fallback)
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var showingOrganizationProfile = false
    @State private var selectedOrganization: Organization?
    
    // Missing state variables for incidents and filters
    @State private var incidents: [Incident] = []
    @State private var selectedIncident: Incident?
    @State private var showingIncidentDetail = false
    @State private var showingFilters = false
    @State private var selectedIncidentTypes: Set<IncidentType> = Set(IncidentType.allCases)
    @State private var selectedSeverities: Set<IncidentSeverity> = Set(IncidentSeverity.allCases)
    
    // Map search functionality
    @State private var mapSearchText = ""
    @State private var mapSearchResults: [Organization] = []
    @State private var showingSearchSheet = false
    
    // Calendar functionality for org admins
    @State private var showingCalendar = false
    @State private var isOrganizationAdmin = false

    
    var body: some View {
        NavigationView {
            ZStack {
                mapContent
                overlayContent
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                
                // Location circle button removed
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
        // .sheet(item: $showingWeatherAlert) { alert in
        //     WeatherAlertView(alert: alert)
        // }

        .sheet(isPresented: $showingOrganizationProfile) {
            if let organization = selectedOrganization {
                NavigationView {
                    OrganizationProfileView(organization: organization)
                }
            }
        }

        .onChange(of: mapSearchText) { _, newValue in
            // Debounce search to prevent excessive API calls
            if !newValue.isEmpty {
                // Clear results immediately for better UX
                mapSearchResults = []
                
                // Debounce search with 0.5 second delay
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    // Only search if the text hasn't changed
                    if mapSearchText == newValue {
                        await searchOrganizationsOnMap(query: newValue)
                    }
                }
            } else {
                mapSearchResults = []
            }
        }



    }
    
    // MARK: - Computed Properties
    private var mapAnnotations: [MapAnnotationItem] {
        var annotations: [MapAnnotationItem] = []
        
        print("🗺️ Creating map annotations for \(organizations.count) organizations")
        print("🗺️ Organizations array: \(organizations.map { "\($0.name) (\($0.location.latitude), \($0.location.longitude))" })")
        
        // Add user location annotation (blue dot)
        if let userLocation = locationManager.currentLocation {
            annotations.append(MapAnnotationItem(
                coordinate: userLocation.coordinate,
                type: .userLocation
            ))
            print("📍 Added user location annotation")
        }
        
        // Create pins for organizations
        for org in organizations {
            // Check if we have valid coordinates
            let coordinate = CLLocationCoordinate2D(
                latitude: org.location.latitude,
                longitude: org.location.longitude
            )
            let hasValidCoordinates = coordinate.latitude != 0.0 && coordinate.longitude != 0.0
            
            if hasValidCoordinates {
                // Use the coordinates from the Location object
                annotations.append(MapAnnotationItem(
                    coordinate: coordinate,
                    type: .organization(org)
                ))
                print("📍 Added pin for \(org.name) at \(coordinate.latitude), \(coordinate.longitude)")
            } else {
                // Check if we have address data that can be geocoded
                // Try to get address from the nested location object first
                var address = org.location.address ?? ""
                var city = org.location.city ?? ""
                var state = org.location.state ?? ""
                var zipCode = org.location.zipCode ?? ""
                
                // If nested location doesn't have address data, try flat fields
                if address.isEmpty {
                    address = org.address ?? ""
                }
                if city.isEmpty {
                    city = org.city ?? ""
                }
                if state.isEmpty {
                    state = org.state ?? ""
                }
                if zipCode.isEmpty {
                    zipCode = org.zipCode ?? ""
                }
                
                if !address.isEmpty && !city.isEmpty && !state.isEmpty {
                    // Add a temporary pin at a default location (will be updated after geocoding)
                    let tempCoordinate = CLLocationCoordinate2D(latitude: 33.2148, longitude: -97.1331)
                    annotations.append(MapAnnotationItem(
                        coordinate: tempCoordinate,
                        type: .organization(org)
                    ))
                }
            }
        }
        
        print("🗺️ Total map annotations created: \(annotations.count)")
        return annotations
    }
    
    
    // MARK: - Subviews
    private var mapContent: some View {
        Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                switch annotation.type {
                case .userLocation:
                    UserLocationAnnotationView()
                case .organization(let org):
                    OrganizationAnnotationView(
                        organization: org,
                        selectedOrganization: $selectedOrganization,
                        showingOrganizationProfile: $showingOrganizationProfile,
                        isSelected: selectedOrganization?.id == org.id
                    )
                default:
                    EmptyView()
                }
            }
        }
        .onAppear {
            // Single, lightweight onAppear block
            print("🗺️ Map view appeared")
            
            // Start location updates to show user location
            locationManager.startLocationUpdates()
            
            // Try to center on user location immediately if available
            if let userLocation = locationManager.currentLocation {
                print("📍 User location available immediately: \(userLocation.coordinate)")
                withAnimation(.easeInOut(duration: 0.5)) {
                    region.center = userLocation.coordinate
                    region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                }
            } else {
                print("📍 User location not available yet, will center when available")
                // Center on user location when it becomes available
                centerOnUserLocation()
            }
            
            // Only load data if user is authenticated
            if authManager.isAuthenticated {
                // Load basic data only
                Task {
                    loadData()
                    
                    // Check and fix logo URLs for organizations that might have photos but no logo URL set
                    await checkAndFixOrganizationLogos()
                    
                    // Check if user is an organization admin
                    await checkAdminStatus()
                }
            } else {
                print("⚠️ User not authenticated, skipping data load")
            }
        }
        .onDisappear {
            // Stop location updates when map is not visible
            locationManager.stopLocationUpdates()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            // Automatically center on user location when it changes
            if let location = newLocation {
                print("📍 User location updated: \(location.coordinate)")
                withAnimation(.easeInOut(duration: 0.5)) {
                    region.center = location.coordinate
                    region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                print("🔐 User authenticated, loading map data")
                Task {
                    loadData()
                }
            }
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView()
        }
    }
    
    private var overlayContent: some View {
        ZStack {
            if !locationManager.isLocationEnabled {
                LocationPermissionView()
            }
            
            if isLoading {
                ProgressView("Loading incidents...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
            
                    // Floating Search Bar at Bottom
    VStack {
        Spacer()
        
        // Functional Search Bar with Dropdown (floating very close to menu bar)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search organizations, cities, states...", text: $mapSearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16, weight: .medium))
                    .onSubmit {
                        Task {
                            await searchOrganizationsOnMap(query: mapSearchText)
                        }
                    }
                
                if !mapSearchText.isEmpty {
                    Button(action: { 
                        mapSearchText = ""
                        mapSearchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                }
                
                // Calendar button for organization admins
                if isOrganizationAdmin {
                    Button(action: {
                        showingCalendar = true
                    }) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            
            // Dropdown Results List
            if !mapSearchText.isEmpty && !mapSearchResults.isEmpty {
                VStack(spacing: 0) {
                    // Results Header
                    HStack {
                        Text("Found \(min(mapSearchResults.count, 5)) organizations")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    // Results List
                    VStack(spacing: 0) {
                        ForEach(mapSearchResults.prefix(5), id: \.id) { organization in
                            Button(action: {
                                selectedOrganization = organization
                                showingOrganizationProfile = true
                                mapSearchText = ""
                                mapSearchResults = []
                            }) {
                                HStack(spacing: 16) {
                                    OrganizationLogoView(organization: organization, size: 36, showBorder: false)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(organization.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        if let city = organization.location.city, let state = organization.location.state {
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text("\(city), \(state)")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color(.systemBackground))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Separator line (except for last item)
                            if organization.id != mapSearchResults.prefix(5).last?.id {
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundColor(Color(.systemGray5))
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 80) // Much closer to the bottom menu bar
    }
    
    // Expanded search box removed - keeping only the compact floating search bar
    
    // Old floating search results removed - now integrated into expanded search box
        }
    }
    

    
    private func loadData() {
        // Prevent multiple simultaneous data loads
        guard !isLoading else {
            print("Data load already in progress, skipping...")
            return
        }
        
        print("🗺️ Starting loadData() - Location: \(locationManager.currentLocation != nil ? "Available" : "Not available"), Auth: \(authManager.isAuthenticated ? "Authenticated" : "Not authenticated")")
        
        // Load organizations even without location - we'll geocode them
        // guard let location = locationManager.currentLocation else { 
        //     print("No location available yet")
        //     return 
        // }
        
        // Add safety check for authentication
        guard authManager.isAuthenticated else {
            print("User not authenticated")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Load organizations from Firestore
                let db = Firestore.firestore()
                let organizationsSnapshot = try await db.collection("organizations").getDocuments()
                
                var fetchedOrganizations: [Organization] = []
                for document in organizationsSnapshot.documents {
                    do {
                        // Use the custom decoder to properly parse all fields including private groups
                        let organization = try document.data(as: Organization.self)
                        print("📍 Loaded organization: \(organization.name)")
                        print("   Coordinates: \(organization.location.latitude), \(organization.location.longitude)")
                        print("   Address: \(organization.location.address ?? "none")")
                        fetchedOrganizations.append(organization)
                    } catch {
                        print("❌ Failed to decode organization \(document.documentID): \(error)")
                        // Fallback to manual creation for backward compatibility
                        let data = document.data()
                        let lat = data["latitude"] as? Double ?? 0.0
                        let lng = data["longitude"] as? Double ?? 0.0
                        let address = data["address"] as? String
                        print("📍 Manual creation for: \(data["name"] as? String ?? "Unknown")")
                        print("   Raw coordinates: \(lat), \(lng)")
                        print("   Raw address: \(address ?? "none")")
                        
                        let organization = Organization(
                            id: document.documentID,
                            name: data["name"] as? String ?? "Unknown Organization",
                            type: data["type"] as? String ?? "business",
                            description: data["description"] as? String ?? "",
                            location: Location(
                                latitude: lat,
                                longitude: lng,
                                address: address,
                                city: data["city"] as? String,
                                state: data["state"] as? String,
                                zipCode: data["zipCode"] as? String
                            ),
                            verified: data["verified"] as? Bool ?? false,
                            followerCount: data["followerCount"] as? Int ?? 0,
                            logoURL: data["logoURL"] as? String,
                            website: data["website"] as? String,
                            phone: data["phone"] as? String,
                            email: data["email"] as? String,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
                            groupsArePrivate: data["groupsArePrivate"] as? Bool ?? false,
                            allowPublicGroupJoin: data["allowPublicGroupJoin"] as? Bool ?? true,
                            address: data["address"] as? String,
                            city: data["city"] as? String,
                            state: data["state"] as? String,
                            zipCode: data["zipCode"] as? String
                        )
                        fetchedOrganizations.append(organization)
                    }
                }
                
                await MainActor.run {
                    self.organizations = fetchedOrganizations
                    self.isLoading = false
                    
                    print("🗺️ Map loaded \(fetchedOrganizations.count) organizations")
                    
                    // Debug each organization's coordinates
                    for org in fetchedOrganizations {
                        print("   📍 \(org.name): lat=\(org.location.latitude), lng=\(org.location.longitude), address=\(org.address ?? "none")")
                    }
                }
                
                // Geocode addresses to get proper coordinates for pins
                await geocodeAddressesToCoordinates()
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Error loading data: \(error)")
                }
            }
        }
    }
    
    private func refreshData() {
        // Call loadData directly without wrapping in MainActor.run
        Task {
            loadData()
        }
    }
    
    private func refreshOrganizations() async {
        // TODO: Add organization fetching to SimpleAuthManager
        let fetchedOrganizations = [Organization]()
        await MainActor.run {
            self.organizations = fetchedOrganizations
            print("🗺️ Map organizations refreshed: \(fetchedOrganizations.count) organizations")
        }
    }
    
    private func centerOnUserLocation() {
        // Center map on user's current location
        if let location = locationManager.currentLocation {
            print("📍 Centering map on user location: \(location.coordinate)")
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = location.coordinate
                region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
        } else {
            print("📍 No user location available, starting location updates")
            // Start location updates if not available
            locationManager.startLocationUpdates()
        }
    }
    
    /// Search organizations on the map
    private func searchOrganizationsOnMap(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                mapSearchResults = []
            }
            return
        }
        
        // TODO: Add organization search to SimpleAuthManager
        let searchResults = [Organization]()
        await MainActor.run {
            mapSearchResults = searchResults
        }
    }
    
    /// Validate and geocode organization addresses and update pins if needed
    private func validateOrganizationCoordinates() async {
        print("🔍 Starting coordinate validation for \(organizations.count) organizations...")
        
        // Geocode each organization's address and update in-memory coordinates when needed
        for (index, org) in organizations.enumerated() {
            let fullAddress = org.location.fullAddress
            print("   📍 Checking \(org.name): \(fullAddress)")
            
            if fullAddress.isEmpty { 
                print("      ❌ No address available")
                continue 
            }

            // Perform geocoding
            if let geocodedLocation = await geocodeAddress(fullAddress) {
                let current = CLLocationCoordinate2D(
                    latitude: org.location.latitude,
                    longitude: org.location.longitude
                )
                print("      ✅ Geocoded to: (\(geocodedLocation.latitude), \(geocodedLocation.longitude))")

                // Determine if an update is needed: missing coords or far from geocoded coords
                var needsUpdate = false
                if current.latitude == 0.0 && current.longitude == 0.0 {
                    needsUpdate = true
                    print("      🔄 Missing coordinates - will update")
                } else {
                    let currentCL = CLLocation(latitude: current.latitude, longitude: current.longitude)
                    let newCL = CLLocation(latitude: geocodedLocation.latitude, longitude: geocodedLocation.longitude)
                    let distanceMeters = currentCL.distance(from: newCL)
                    // Update if more than ~75m away from geocoded address
                    needsUpdate = distanceMeters > 75
                    print("      📏 Distance: \(Int(distanceMeters))m - \(needsUpdate ? "will update" : "no update needed")")
                }

                if needsUpdate {
                    print("📍 Updating org \(org.name) coordinates to geocoded address: \(geocodedLocation.latitude), \(geocodedLocation.longitude)")

                    // Create updated organization with new location
                    let updatedOrganization = Organization(
                        id: org.id,
                        name: org.name,
                        type: org.type,
                        description: org.description,
                        location: geocodedLocation,
                        verified: org.verified,
                        followerCount: org.followerCount,
                        logoURL: org.logoURL,
                        website: org.website,
                        phone: org.phone,
                        email: org.email,
                        groups: nil, // MapView doesn't manage groups
                        adminIds: org.adminIds,
                        createdAt: org.createdAt,
                        updatedAt: Date()
                    )

                    // Apply update on main actor to refresh UI/pins
                    await MainActor.run {
                        organizations[index] = updatedOrganization
                        print("      ✅ Updated \(org.name) coordinates in memory")
                    }
                }
            } else {
                print("   ❌ Failed to geocode address for org: \(org.name)")
            }
        }
        
        print("🔍 Coordinate validation completed")
    }
    
    /// Geocode an address string to coordinates
    private func geocodeAddress(_ address: String) async -> Location? {
        let geocoder = CLGeocoder()
        
        do {
            print("🌍 Geocoding address: \(address)")
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let placemark = placemarks.first,
               let location = placemark.location {
                let geocodedLocation = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: address,
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    zipCode: placemark.postalCode
                )
                print("   ✅ Geocoded to: (\(geocodedLocation.latitude), \(geocodedLocation.longitude))")
                return geocodedLocation
            } else {
                print("   ❌ No placemarks found for address")
            }
        } catch {
            print("❌ Geocoding error: \(error)")
        }
        
        return nil
    }
    
    /// Log the current state of organization coordinates for debugging
    private func logOrganizationCoordinateState() async {
        print("🗺️ Final organization coordinate state:")
        let validOrgs = organizations.filter { 
            $0.location.latitude != 0.0 && 
            $0.location.longitude != 0.0 
        }
        let invalidOrgs = organizations.filter { 
            $0.location.latitude == 0.0 || 
            $0.location.longitude == 0.0 
        }
        
        print("   ✅ Valid coordinates: \(validOrgs.count) organizations")
        for org in validOrgs {
            print("      - \(org.name): (\(org.location.latitude), \(org.location.longitude))")
        }
        
        print("   ❌ Invalid coordinates: \(invalidOrgs.count) organizations")
        for org in invalidOrgs {
            print("      - \(org.name): Address: \(org.location.fullAddress)")
        }
        
        print("   📍 Total annotations to show: \(validOrgs.count)")
    }
    
    /// Update existing organizations that might be missing coordinates
    private func updateExistingOrganizationCoordinates() async {
        let invalidOrgs = organizations.filter { 
            $0.location.latitude == 0.0 || 
            $0.location.longitude == 0.0 
        }
        
        if !invalidOrgs.isEmpty {
            print("🔄 Found \(invalidOrgs.count) organizations with invalid coordinates, attempting to update...")
            
            for (_, org) in invalidOrgs.enumerated() {
                let fullAddress = org.location.fullAddress
                if fullAddress.isEmpty { continue }
                
                if let geocodedLocation = await geocodeAddress(fullAddress) {
                    print("📍 Updating coordinates for \(org.name): \(geocodedLocation.latitude), \(geocodedLocation.longitude)")
                    
                    // Update the organization in our local array
                    let updatedOrganization = Organization(
                        id: org.id,
                        name: org.name,
                        type: org.type,
                        description: org.description,
                        location: geocodedLocation,
                        verified: org.verified,
                        followerCount: org.followerCount,
                        logoURL: org.logoURL,
                        website: org.website,
                        phone: org.phone,
                        email: org.email,
                        groups: nil, // MapView doesn't manage groups
                        adminIds: org.adminIds,
                        createdAt: org.createdAt,
                        updatedAt: Date()
                    )
                    
                    // Find and update the organization in the organizations array
                    if let orgIndex = organizations.firstIndex(where: { $0.id == org.id }) {
                        await MainActor.run {
                            organizations[orgIndex] = updatedOrganization
                        }
                    }
                }
            }
        }
    }
    
    /// Geocode all organization addresses to get proper coordinates for pins
    private func geocodeAllOrganizationAddresses() async {
        print("🌍 Starting geocoding for all organizations...")
        
        for (index, org) in organizations.enumerated() {
            print("   📍 Processing \(org.name)...")
            
            // Check if this organization already has valid coordinates
            let currentCoordinate = CLLocationCoordinate2D(
                latitude: org.location.latitude,
                longitude: org.location.longitude
            )
            if currentCoordinate.latitude != 0.0 && currentCoordinate.longitude != 0.0 {
                print("      ✅ \(org.name) already has valid coordinates: (\(currentCoordinate.latitude), \(currentCoordinate.longitude))")
                continue
            }
            
            // Build address from components (try both nested and flat fields)
            let address = org.location.address ?? org.address ?? ""
            let city = org.location.city ?? org.city ?? ""
            let state = org.location.state ?? org.state ?? ""
            let zipCode = org.location.zipCode ?? org.zipCode ?? ""
            
            print("      📍 Address components for \(org.name):")
            print("         Address: '\(address)'")
            print("         City: '\(city)'")
            print("         State: '\(state)'")
            print("         ZipCode: '\(zipCode)'")
            
            let addressComponents = [address, city, state, zipCode].filter { !$0.isEmpty }
            let fullAddress = addressComponents.joined(separator: ", ")
            
            if !addressComponents.isEmpty {
                print("      🌍 Geocoding \(org.name): \(fullAddress)")
                
                if let geocodedLocation = await geocodeAddress(fullAddress) {
                    print("      ✅ Geocoded to: (\(geocodedLocation.latitude), \(geocodedLocation.longitude))")
                    
                    // Update the organization with geocoded coordinates
                    let updatedOrganization = Organization(
                        id: org.id,
                        name: org.name,
                        type: org.type,
                        description: org.description,
                        location: geocodedLocation,
                        verified: org.verified,
                        followerCount: org.followerCount,
                        logoURL: org.logoURL,
                        website: org.website,
                        phone: org.phone,
                        email: org.email,
                        groups: org.groups,
                        adminIds: org.adminIds,
                        createdAt: org.createdAt,
                        updatedAt: Date(),
                        address: org.address,
                        city: org.city,
                        state: org.state,
                        zipCode: org.zipCode
                    )
                    
                    // Update in memory to refresh the map
                    await MainActor.run {
                        organizations[index] = updatedOrganization
                        print("      🔄 Updated \(org.name) coordinates in memory")
                        
                        // Force map refresh to show updated pin locations
                        print("      🗺️ Triggering map refresh for \(org.name)")
                    }
                    
                    // Save the updated coordinates to Firestore
                    await saveOrganizationCoordinatesToFirestore(updatedOrganization)
                } else {
                    print("      ❌ Failed to geocode address")
                }
            } else {
                print("      ❌ No address data available for \(org.name)")
            }
            
            print("      ---")
        }
        
        print("🌍 Geocoding completed")
    }
    
    /// Save organization coordinates to Firestore
    private func saveOrganizationCoordinatesToFirestore(_ organization: Organization) async {
        let db = Firestore.firestore()
        
        do {
            // Update the location field in Firestore
            let locationData: [String: Any] = [
                "latitude": organization.location.latitude,
                "longitude": organization.location.longitude,
                "address": organization.location.address ?? "",
                "city": organization.location.city ?? "",
                "state": organization.location.state ?? "",
                "zipCode": organization.location.zipCode ?? ""
            ]
            
            try await db.collection("organizations")
                .document(organization.id)
                .updateData([
                    "location": locationData,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            
            print("💾 Saved coordinates for \(organization.name) to Firestore")
        } catch {
            print("❌ Failed to save coordinates for \(organization.name): \(error)")
        }
    }
    

    
    /// Debug function to check raw Firestore data for addresses
    private func debugFirestoreAddresses() async {
        print("🔍 Debugging Firestore address data...")
        
        for org in organizations {
            print("   📍 Organization: \(org.name)")
            print("      Raw address: '\(org.location.address ?? "nil")'")
            print("      Raw city: '\(org.location.city ?? "nil")'")
            print("      Raw state: '\(org.location.state ?? "nil")'")
            print("      Raw zipCode: '\(org.location.zipCode ?? "nil")'")
            print("      Raw latitude: \(org.location.latitude)")
            print("      Raw longitude: \(org.location.longitude)")
            
            // Check if the issue is with empty strings vs nil
            let addressEmpty = org.location.address?.isEmpty ?? true
            let cityEmpty = org.location.city?.isEmpty ?? true
            let stateEmpty = org.location.state?.isEmpty ?? true
            let zipEmpty = org.location.zipCode?.isEmpty ?? true
            
            print("      Address empty: \(addressEmpty)")
            print("      City empty: \(cityEmpty)")
            print("      State empty: \(stateEmpty)")
            print("      Zip empty: \(zipEmpty)")
            
            // Debug the Location struct itself
            print("      Location struct: \(org.location)")
            print("      Location type: \(type(of: org.location))")
            
            // Check if location is actually a Location struct
            if let _ = org.location as? Location {
                print("      ✅ Location is Location struct")
            } else {
                print("      ❌ Location is NOT Location struct - it's: \(type(of: org.location))")
            }
            
            // Check flat address fields
            print("      Flat address: '\(org.address ?? "nil")'")
            print("      Flat city: '\(org.city ?? "nil")'")
            print("      Flat state: '\(org.state ?? "nil")'")
            print("      Flat zipCode: '\(org.zipCode ?? "nil")'")
            
            print("      ---")
        }
    }
    
    /// Geocode addresses to get real coordinates for pins
    private func geocodeAddressesToCoordinates() async {
        print("🌍 Starting geocoding for all organizations...")
        
        for (index, org) in organizations.enumerated() {
            // Get the flat address fields that we know have data
            let address = org.address ?? ""
            let city = org.city ?? ""
            let state = org.state ?? ""
            let zipCode = org.zipCode ?? ""
            
            print("   📍 Geocoding \(org.name)")
            print("      Address: '\(address)'")
            print("      City: '\(city)'")
            print("      State: '\(state)'")
            print("      ZipCode: '\(zipCode)'")
            
            if !address.isEmpty && !city.isEmpty && !state.isEmpty {
                let fullAddress = "\(address), \(city), \(state) \(zipCode)"
                print("      📍 Full Address: \(fullAddress)")
                
                if let geocodedLocation = await geocodeAddress(fullAddress) {
                    print("      ✅ Geocoded to: (\(geocodedLocation.latitude), \(geocodedLocation.longitude))")
                    
                    // Update the organization with real coordinates
                    let updatedOrganization = Organization(
                        id: org.id,
                        name: org.name,
                        type: org.type,
                        description: org.description,
                        location: geocodedLocation,
                        verified: org.verified,
                        followerCount: org.followerCount,
                        logoURL: org.logoURL,
                        website: org.website,
                        phone: org.phone,
                        email: org.email,
                        groups: org.groups,
                        adminIds: org.adminIds,
                        createdAt: org.createdAt,
                        updatedAt: org.updatedAt,
                        address: org.address,
                        city: org.city,
                        state: org.state,
                        zipCode: org.zipCode
                    )
                    
                    // Update in memory to refresh the map
                    await MainActor.run {
                        organizations[index] = updatedOrganization
                        print("      🔄 Updated \(org.name) with real coordinates")
                    }
                } else {
                    print("      ❌ Failed to geocode address")
                }
            } else {
                print("      ❌ Missing address data - skipping geocoding")
            }
            print("      ---")
        }
        
        print("🌍 Geocoding completed")
    }
    
    
    /// Check and fix organization logo URLs
    private func checkAndFixOrganizationLogos() async {
        for organization in organizations {
            // Only check organizations that don't have a logo URL set
            if organization.logoURL == nil || organization.logoURL?.isEmpty == true {
                // TODO: Add logo URL checking to SimpleAuthManager
                print("Logo URL checking not implemented in SimpleAuthManager")
            }
        }
        
        // Don't refresh organizations here to avoid infinite loops
        // await refreshOrganizations()
    }
    
    
    /// Geocode Firestore addresses to get real coordinates for pins
    private func geocodeFirestoreAddresses() async {
        print("🌍 Geocoding Firestore addresses...")
        
        for (index, org) in organizations.enumerated() {
            // Get address components from Firestore
            let address = org.location.address ?? ""
            let city = org.location.city ?? ""
            let state = org.location.state ?? ""
            let zipCode = org.location.zipCode ?? ""
            
            // Only geocode if we have address data
            if !address.isEmpty && !city.isEmpty && !state.isEmpty {
                let fullAddress = "\(address), \(city), \(state) \(zipCode)"
                print("   📍 Geocoding \(org.name): \(fullAddress)")
                
                if let geocodedLocation = await geocodeAddress(fullAddress) {
                    print("      ✅ Geocoded to: (\(geocodedLocation.latitude), \(geocodedLocation.longitude))")
                    
                    // Update the organization with real coordinates
                    let updatedOrganization = Organization(
                        id: org.id,
                        name: org.name,
                        type: org.type,
                        description: org.description,
                        location: geocodedLocation,
                        verified: org.verified,
                        followerCount: org.followerCount,
                        logoURL: org.logoURL,
                        website: org.website,
                        phone: org.phone,
                        email: org.email,
                        groups: nil,
                        adminIds: org.adminIds,
                        createdAt: org.createdAt,
                        updatedAt: Date()
                    )
                    
                    // Update in memory to refresh the map
                    await MainActor.run {
                        organizations[index] = updatedOrganization
                        print("      🔄 Updated \(org.name) with real coordinates")
                    }
                } else {
                    print("      ❌ Failed to geocode address")
                }
            } else {
                print("   📍 Skipping \(org.name) - missing address data")
            }
        }
        
        print("🌍 Firestore address geocoding completed")
    }
    

}

// MARK: - Annotation Views
struct IncidentAnnotationView: View {
    let incident: Incident
    @Binding var selectedIncident: Incident?
    @Binding var showingIncidentDetail: Bool
    let isSelected: Bool
    
    var body: some View {
        Button(action: {
            selectedIncident = incident
            showingIncidentDetail = true
        }) {
            VStack(spacing: 2) {
                Image(systemName: incident.type.icon)
                    .font(.system(size: isSelected ? 20 : 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .background(incident.severity.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                if let distance = incident.distance {
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct OrganizationAnnotationView: View {
    let organization: Organization
    @Binding var selectedOrganization: Organization?
    @Binding var showingOrganizationProfile: Bool
    let isSelected: Bool
    
    var body: some View {
        Button(action: {
            selectedOrganization = organization
            showingOrganizationProfile = true
        }) {
            VStack(spacing: 2) {
                // Organization Pin
                ZStack {
                    // Pin background - different colors for verified vs pending
                    Circle()
                        .fill(organization.verified ? Color.blue : Color.orange)
                        .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                        .shadow(color: .black.opacity(0.3), radius: isSelected ? 4 : 2, x: 0, y: isSelected ? 2 : 1)
                    
                    // Organization logo or icon
                    if let logoURL = organization.logoURL, !logoURL.isEmpty {
                        // Show organization logo if available using OrganizationLogoView for consistency
                        OrganizationLogoView(organization: organization, size: isSelected ? 24 : 20, showBorder: false)
                    } else {
                        // Fallback to icon if no logo
                        Image(systemName: getOrganizationIcon())
                            .font(.system(size: isSelected ? 20 : 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Verification badge removed - pins indicate verified status
                }
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                // Organization name label with status - REMOVED
            }
        }
        .buttonStyle(.plain)
    }
    
    private func getOrganizationIcon() -> String {
        switch organization.type.lowercased() {
        case "church": return "building.2.fill"
        case "pto": return "graduationcap.fill"
        case "school": return "building.columns.fill"
        case "business": return "building.2.fill"
        case "government": return "building.columns.fill"
        case "nonprofit": return "heart.fill"
        case "emergency": return "cross.fill"
        case "physical_therapy": return "cross.case.fill"
        default: return "building.2.fill"
        }
    }
}

// MARK: - User Location Annotation View
struct UserLocationAnnotationView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
    
    var body: some View {
        ZStack {
            // Outer blue circle with transparency
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
            
            // Profile photo or fallback
            if let user = authManager.currentUser, let profilePhotoURL = user.profilePhotoURL, !profilePhotoURL.isEmpty {
                CachedAsyncImage(
                    url: profilePhotoURL,
                    size: 32,
                    fallback: AnyView(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            )
                    )
                )
                .onAppear {
                    print("📍 UserLocationAnnotationView: Showing profile photo - \(profilePhotoURL)")
                }
            } else {
                // Fallback to blue circle with person icon
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                .onAppear {
                    if let user = authManager.currentUser {
                        print("📍 UserLocationAnnotationView: No profile photo - user: \(user.name ?? "Unknown"), profilePhotoURL: \(user.profilePhotoURL ?? "nil")")
                    } else {
                        print("📍 UserLocationAnnotationView: No current user")
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Filter View
struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIncidentTypes: Set<IncidentType>
    @Binding var selectedSeverities: Set<IncidentSeverity>
    
    var body: some View {
        NavigationView {
            List {
                Section("Incident Types") {
                    ForEach(IncidentType.allCases, id: \.self) { type in
                        FilterToggleButton(
                            title: type.displayName,
                            icon: type.icon,
                            color: type.color,
                            isSelected: selectedIncidentTypes.contains(type)
                        ) {
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
                        FilterToggleButton(
                            title: severity.displayName,
                            icon: "exclamationmark.triangle",
                            color: severity.color,
                            isSelected: selectedSeverities.contains(severity)
                        ) {
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

struct FilterToggleButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Location Permission View
struct LocationPermissionView: View {
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Location Access Required")
                .font(.headline)
            
            Text("LocalAlert needs location access to show you nearby incidents and alerts.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Enable Location Access") {
                locationManager.requestLocationPermission()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .padding()
    }
}

// MARK: - Weather Alert Annotation View - temporarily disabled
// struct WeatherAlertAnnotationView: View {
//     let alert: WeatherAlert
//     @Binding var showingWeatherAlert: WeatherAlert?
//     
//     var body: some View {
//         Button(action: {
//             showingWeatherAlert = alert
//         }) {
//             VStack(spacing: 2) {
//                 Image(systemName: alert.type.icon)
//                     .font(.system(size: 18, weight: .semibold))
//                     .foregroundColor(.white)
//                     .frame(width: 36, height: 36)
//                     .background(alert.type.color)
//                     .clipShape(Circle())
//                     .overlay(
//                         Circle()
//                             .stroke(Color.white, lineWidth: 3)
//                     )
//                     .overlay(
//                         Circle()
//                             .stroke(alert.severity.color, lineWidth: 2)
//                             .scaleEffect(1.2)
//                     )
//                 
//                 if let distance = alert.distance {
//                     Text(String(format: "%.1f mi", distance))
//                         .font(.caption2)
//                         .foregroundColor(.white)
//                         .padding(.horizontal, 4)
//                         .padding(.vertical, 2)
//                         .background(Color.black.opacity(0.7))
//                         .cornerRadius(4)
//                 }
//                 
//                 // Alert indicator
//                 Text("!")
//                     .font(.caption2)
//                     .fontWeight(.bold)
//                     .foregroundColor(.white)
//                     .frame(width: 16, height: 16)
//                     .background(Color.red)
//                     .clipShape(Circle())
//                     .offset(x: 12, y: -8)
//             }
//         }
//         .buttonStyle(.plain)
//     }
// }

// MARK: - Simple Weather Widget
struct SimpleWeatherWidget: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(spacing: 0) {
            // Current weather card
            Button(action: {
                // Will show weather details when we add them
            }) {
                HStack(spacing: 12) {
                    // Weather icon and status
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.sun")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Weather")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Button(action: {
                            weatherService.refreshWeatherData()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            
            // Weather alerts banner (if any)
            if !weatherService.getActiveAlerts().isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weather Alerts Active")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(weatherService.getActiveAlerts().count) alert(s) in your area")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.9), Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Weather Alerts View
struct WeatherAlertsView: View {
    @ObservedObject var weatherService: WeatherService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if weatherService.weatherAlerts.isEmpty {
                    // No alerts
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Active Weather Alerts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("There are currently no weather alerts in your area.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // Show alerts
                    List {
                        ForEach(weatherService.weatherAlerts, id: \.self) { alert in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alert.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text("Active now")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Alert details
                                HStack {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Last updated: \(weatherService.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "Unknown")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("Refresh") {
                                        weatherService.refreshWeatherData()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Refresh Alerts") {
                        weatherService.refreshWeatherData()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Test buttons for development
                    Button("Add Test Alert") {
                        weatherService.addMockAlert()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Clear Alerts") {
                        weatherService.clearMockAlerts()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Weather Alerts")
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

// MARK: - Simple Weather Info View
struct SimpleWeatherInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "cloud.sun")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Weather Information")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Weather alerts and current conditions will be available here once the weather service is fully integrated.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Weather notification system ready")
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("Location services active")
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Weather data integration in progress")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Weather Status")
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
    
    // MARK: - Admin Status Checking
    private func checkAdminStatus() async {
        guard let userId = authManager.currentUser?.id else {
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
            return
        }
        
        do {
            // Check if user is admin of any organization
            let db = Firestore.firestore()
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            
            var isAdmin = false
            for orgDoc in orgsSnapshot.documents {
                let orgData = orgDoc.data()
                if let adminIds = orgData["adminIds"] as? [String], adminIds.contains(userId) {
                    isAdmin = true
                    break
                }
            }
            
            await MainActor.run {
                self.isOrganizationAdmin = isAdmin
                print("🔐 User admin status: \(isAdmin ? "Admin" : "Not admin")")
            }
        } catch {
            print("❌ Error checking admin status: \(error)")
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(LocationManager())
        .environmentObject(SimpleAuthManager())
} 