import SwiftUI
import CoreLocation

struct DiscoverOrganizationsView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @StateObject private var followStatusManager = FollowStatusManager.shared
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var showingOrganizationProfile: Organization?
    @State private var searchText = ""
    
    var filteredOrganizations: [Organization] {
        let filtered: [Organization]
        if searchText.isEmpty {
            filtered = organizations
        } else {
            filtered = organizations.filter { organization in
                organization.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by real geographic distance from user's current location
        guard let userLocation = locationManager.currentLocation else {
            return filtered // Return unsorted if no user location available
        }
        
        return filtered.sorted { org1, org2 in
            let distance1 = calculateRealDistance(from: userLocation, to: org1.location)
            let distance2 = calculateRealDistance(from: userLocation, to: org2.location)
            return distance1 < distance2
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search organizations...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                if isLoading {
                    ProgressView("Loading organizations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredOrganizations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "building.2")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text(searchText.isEmpty ? "No organizations found" : "No organizations match your search")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if searchText.isEmpty {
                            Text("Organizations will appear here once they're verified")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredOrganizations) { organization in
                        DiscoverOrganizationRowView(organization: organization) {
                            showingOrganizationProfile = organization
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Discover")
            .onAppear {
                // Start location updates to get user's current location/zip code
                locationManager.startLocationUpdates()
                loadOrganizations()
            }
            .onDisappear {
                // Stop location updates when view disappears
                locationManager.stopLocationUpdates()
            }
            .sheet(item: $showingOrganizationProfile) { organization in
                OrganizationProfileView(organization: organization)
            }
        }
    }
    
    private func loadOrganizations() {
        isLoading = true
        
        Task {
            do {
                let fetchedOrganizations = try await apiService.fetchOrganizations()
                await MainActor.run {
                    self.organizations = fetchedOrganizations
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading organizations: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getUserZipCode() -> String? {
        // Get user's actual zip code from current location
        guard let userLocation = locationManager.currentLocation else {
            return "75001" // Fallback to Dallas area zip code
        }
        
        // Use reverse geocoding to get zip code from current location
        return getUserZipCodeFromLocation(userLocation)
    }
    
    private func getUserZipCodeFromLocation(_ location: CLLocation) -> String? {
        // This is a synchronous approximation - in production you might want async geocoding
        // For now, we'll estimate based on coordinates
        
        // Get coordinates
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Simple zip code estimation based on coordinates (this is a rough approximation)
        // In production, you'd want to use CLGeocoder for accurate results
        
        // Texas zip code ranges (rough approximation)
        if latitude >= 25.8 && latitude <= 36.5 && longitude >= -106.6 && longitude <= -93.5 {
            // Estimate Texas zip code based on location
            let latOffset = Int((latitude - 25.8) * 100)
            let lonOffset = Int((longitude + 106.6) * 100)
            let estimatedZip = 75000 + latOffset + lonOffset
            return String(estimatedZip).prefix(5).description
        }
        
        // California zip code ranges
        if latitude >= 32.5 && latitude <= 42.0 && longitude >= -124.4 && longitude <= -114.1 {
            let latOffset = Int((latitude - 32.5) * 100)
            let lonOffset = Int((longitude + 124.4) * 100)
            let estimatedZip = 90000 + latOffset + lonOffset
            return String(estimatedZip).prefix(5).description
        }
        
        // New York zip code ranges
        if latitude >= 40.5 && latitude <= 45.0 && longitude >= -79.8 && longitude <= -71.8 {
            let latOffset = Int((latitude - 40.5) * 100)
            let lonOffset = Int((longitude + 79.8) * 100)
            let estimatedZip = 10000 + latOffset + lonOffset
            return String(estimatedZip).prefix(5).description
        }
        
        // Default fallback
        return "75001"
    }
    
    private func calculateRealDistance(from userLocation: CLLocation, to organizationLocation: Location) -> Double {
        // Calculate real geographic distance using Core Location
        let orgCLLocation = CLLocation(
            latitude: organizationLocation.latitude,
            longitude: organizationLocation.longitude
        )
        
        // Get distance in meters and convert to miles
        let distanceInMeters = userLocation.distance(from: orgCLLocation)
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert meters to miles
        
        return distanceInMiles
    }
}

struct DiscoverOrganizationRowView: View {
    let organization: Organization
    let onTap: () -> Void
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @StateObject private var followStatusManager = FollowStatusManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var localFollowStatus: Bool? // Local state for immediate UI updates
    
    // Computed property for follow status that automatically updates
    private var isFollowing: Bool {
        // Use local state if available, otherwise fall back to FollowStatusManager
        if let localStatus = localFollowStatus {
            print("   🔍 isFollowing computed property: using localFollowStatus = \(localStatus)")
            return localStatus
        }
        let fallbackStatus = followStatusManager.getFollowStatus(for: organization.id) ?? false
        print("   🔍 isFollowing computed property: using fallback status = \(fallbackStatus)")
        return fallbackStatus
    }
    
    // Distance calculation removed
    
    var body: some View {
        HStack(spacing: 12) {
            // Organization icon/logo - tappable to open profile
            Button(action: onTap) {
                OrganizationLogoView(organization: organization, size: 50, showBorder: false)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Organization info - tappable to open profile
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(organization.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if organization.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    // Distance display removed - no location icon needed
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Follow button - separate from profile opening
            Button(action: toggleFollow) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                            .font(.system(size: 14))
                    }
                    
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isFollowing ? .white : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFollowing ? Color.blue : Color.blue.opacity(0.1))
                )
            }
            .disabled(isLoading)
            .onAppear {
                print("🔍 Follow button onAppear for organization: \(organization.name)")
                print("   Initial localFollowStatus: \(localFollowStatus?.description ?? "nil")")
                print("   Initial fallback status: \(followStatusManager.getFollowStatus(for: organization.id)?.description ?? "nil")")
                checkFollowStatus()
            }
        }
        .padding(.vertical, 8)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func getUserZipCode() -> String? {
        // Get user's actual zip code from current location
        guard let userLocation = locationManager.currentLocation else {
            return "75001" // Fallback to Dallas area zip code
        }
        
        // Use reverse geocoding to get zip code from current location
        return getUserZipCodeFromLocation(userLocation)
    }
    
    private func getUserZipCodeFromLocation(_ location: CLLocation) -> String? {
        // This is a synchronous approximation - in production you might want async geocoding
        // For now, we'll estimate based on coordinates
        
        // Get coordinates
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        // Simple zip code estimation based on coordinates (this is a rough approximation)
        // In production, you'd want to use CLGeocoder for accurate results
        
        // Texas zip code ranges (rough approximation)
        if latitude >= 25.8 && latitude <= 36.5 && longitude >= -106.6 && longitude <= -93.5 {
            // Estimate Texas zip code based on location
            let latOffset = Int((latitude - 25.8) * 100)
            let lonOffset = Int((longitude + 106.6) * 100)
            let estimatedZip = 75000 + latOffset + lonOffset
            return String(estimatedZip).prefix(5).description
        }
        
        // California zip code ranges
        if latitude >= 32.5 && latitude <= 42.0 && longitude >= -124.4 && longitude <= -114.1 {
            let latOffset = Int((latitude - 32.5) * 100)
            let lonOffset = Int((longitude + 124.4) * 100)
            let estimatedZip = 90000 + latOffset + lonOffset
            return String(estimatedZip).prefix(5).description
        }
        
        // New York zip code ranges
        if latitude >= 40.5 && latitude <= 45.0 && longitude >= -79.8 && longitude <= -71.8 {
            let latOffset = Int((latitude - 40.5) * 100)
            let lonOffset = Int((longitude + 79.8) * 100)
            let estimatedZip = 10000 + latOffset + lonOffset
            return String(estimatedZip).prefix(5).description
        }
        
        // Default fallback
        return "75001"
    }
    
    private func calculateRealDistance(from userLocation: CLLocation, to organizationLocation: Location) -> Double {
        // Calculate real geographic distance using Core Location
        let orgCLLocation = CLLocation(
            latitude: organizationLocation.latitude,
            longitude: organizationLocation.longitude
        )
        
        // Get distance in meters and convert to miles
        let distanceInMeters = userLocation.distance(from: orgCLLocation)
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert meters to miles
        
        return distanceInMiles
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
    
    private func checkFollowStatus() {
        print("🔍 checkFollowStatus called for organization: \(organization.name)")
        Task {
            do {
                let following = try await apiService.isFollowingOrganization(organization.id)
                print("   🔍 API returned following status: \(following)")
                await MainActor.run {
                    // Update both local state and FollowStatusManager
                    localFollowStatus = following
                    followStatusManager.updateFollowStatus(organizationId: organization.id, isFollowing: following)
                    print("🔍 Follow status for \(organization.name): \(following)")
                    print("   🔍 Updated localFollowStatus to: \(following)")
                }
            } catch {
                print("❌ Error checking follow status: \(error)")
                await MainActor.run {
                    // Update both local state and FollowStatusManager
                    localFollowStatus = false
                    followStatusManager.updateFollowStatus(organizationId: organization.id, isFollowing: false)
                }
            }
        }
    }
    
    private func toggleFollow() {
        print("🔍 toggleFollow called for organization: \(organization.name)")
        print("   Current isFollowing state: \(isFollowing)")
        print("   ServiceCoordinator available: \(serviceCoordinator != nil)")
        
        // Immediately update local state for instant UI feedback
        let newFollowStatus = !isFollowing
        localFollowStatus = newFollowStatus
        
        print("   🔄 Setting localFollowStatus to: \(newFollowStatus)")
        print("   🔄 Will call: \(newFollowStatus ? "followOrganization" : "unfollowOrganization")")
        
        isLoading = true
        
        Task {
            do {
                print("🔄 Starting follow/unfollow operation...")
                if isFollowing {
                    print("🔄 Currently following, so unfollowing organization: \(organization.id)")
                    try await serviceCoordinator.unfollowOrganization(organization.id)
                } else {
                    print("🔄 Currently not following, so following organization: \(organization.id)")
                    try await serviceCoordinator.followOrganization(organization.id)
                }
                
                // Update the FollowStatusManager to reflect the new state
                followStatusManager.updateFollowStatus(organizationId: organization.id, isFollowing: newFollowStatus)
                print("✅ Follow/unfollow operation completed successfully. New status: \(newFollowStatus)")
                
                await MainActor.run {
                    // Ensure localFollowStatus matches the new state
                    localFollowStatus = newFollowStatus
                    print("   🔄 Updated localFollowStatus to match new state: \(newFollowStatus)")
                    isLoading = false
                }
                
            } catch {
                print("❌ Error in toggleFollow: \(error.localizedDescription)")
                print("   Error type: \(type(of: error))")
                
                // Revert local state on error
                await MainActor.run {
                    localFollowStatus = !newFollowStatus // Revert to previous state
                    isLoading = false
                    
                    // Show detailed error to user
                    let errorMessage = """
                    Follow operation failed:
                    
                    Error: \(error.localizedDescription)
                    Type: \(type(of: error))
                    
                    Please try again or contact support if the issue persists.
                    """
                    
                    // You can add an alert here to show the error
                    print("🚨 User should see this error: \(errorMessage)")
                }
            }
        }
    }
}

#Preview {
    DiscoverOrganizationsView()
        .environmentObject(APIService())
        .environmentObject(LocationManager())
}


