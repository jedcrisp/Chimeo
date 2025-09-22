import SwiftUI
import MapKit
import Contacts
import FirebaseAuth

// MARK: - Notification Names
extension Notification.Name {
    static let resetSettingsNavigation = Notification.Name("resetSettingsNavigation")
}

struct ContentView: View {
    @StateObject private var authManager = SimpleAuthManager()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @State private var hasError = false
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(apiService)
                    .environmentObject(serviceCoordinator)
            } else {
                ModernAuthView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            print("🔍 ContentView: User is authenticated: \(authManager.isAuthenticated)")
            print("🔍 ContentView: Current user: \(authManager.currentUser?.id ?? "nil")")
            print("🔍 ContentView: Firebase Auth current user: \(Auth.auth().currentUser?.uid ?? "none")")
        }
        .onAppear {
            // Add safety delay and error handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                locationManager.requestLocationPermission()
            }
        }
        .alert("Error", isPresented: $hasError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            SettingsView()
                .onReceive(NotificationCenter.default.publisher(for: .resetSettingsNavigation)) { _ in
                    // Reset navigation when Settings tab is tapped
                    navigationPath = NavigationPath()
                }
        }
    }
}

// MARK: - Creator Requests View
struct CreatorRequestsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var pendingRequests: [OrganizationRequest] = []
    @State private var isLoading = false
    @State private var selectedRequest: OrganizationRequest?
    @State private var showingRequestDetail = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading requests...")
                        .padding()
                } else if pendingRequests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Pending Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("All organization registration requests have been reviewed.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section("📊 Summary") {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                Text("Pending Review")
                                Spacer()
                                Text("\(pendingRequests.count)")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Section("📋 Pending Requests") {
                            ForEach(pendingRequests) { request in
                                SimpleRequestRow(request: request) {
                                    selectedRequest = request
                                    showingRequestDetail = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadPendingRequests()
                    }
                }
            }
            .sheet(isPresented: $showingRequestDetail) {
                if let request = selectedRequest {
                    SimpleRequestDetailView(request: request) {
                        // Refresh the list after review
                        loadPendingRequests()
                    }
                }
            }
            .onAppear {
                loadPendingRequests()
            }
        }
    }
    
    private func loadPendingRequests() {
        isLoading = true
        
        Task {
            do {
                let requests = try await apiService.getPendingOrganizationRequests()
                await MainActor.run {
                    self.pendingRequests = requests
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to load requests: \(error)")
                }
            }
        }
    }
}



// MARK: - Creator Request Detail View (Removed - Using existing OrganizationRequestDetailView)
    

// MARK: - Simple Request Row
struct SimpleRequestRow: View {
    let request: OrganizationRequest
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(request.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(request.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(request.status.color.opacity(0.2))
                        .foregroundColor(request.status.color)
                        .cornerRadius(8)
                }
                
                Text(request.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(request.contactPersonName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(request.fullAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple Request Detail View
struct SimpleRequestDetailView: View {
    let request: OrganizationRequest
    let onReview: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var showingReviewSheet = false
    @State private var selectedReviewStatus: RequestStatus = .approved
    @State private var reviewNotes: String = ""
    @State private var nextSteps: [String] = []
    @State private var newNextStep: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text(request.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(request.type.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                Text(request.status.displayName)
                                    .foregroundColor(.orange)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        
                        Text(request.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Contact Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name: \(request.contactPersonName)")
                            Text("Title: \(request.contactPersonTitle)")
                            Text("Phone: \(request.contactPersonPhone)")
                            Text("Email: \(request.contactPersonEmail)")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(.headline)
                        
                        Text(request.fullAddress)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Review Action Buttons
                    reviewButtons
                }
                .padding()
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReviewSheet) {
                ReviewOrganizationRequestSheet(
                    request: request,
                    reviewNotes: $reviewNotes,
                    selectedReviewStatus: $selectedReviewStatus,
                    nextSteps: $nextSteps,
                    newNextStep: $newNextStep,
                    onSubmit: submitReview
                )
            }

        }
    }
    
    private var reviewButtons: some View {
        VStack(spacing: 12) {
            Button(action: { 
                selectedReviewStatus = .approved
                // Force sheet refresh by temporarily dismissing and showing again
                showingReviewSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showingReviewSheet = true
                }
            }) {
                HStack { Image(systemName: "checkmark.circle.fill"); Text("Approve") }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            HStack(spacing: 12) {
                Button(action: { 
                    selectedReviewStatus = .requiresMoreInfo
                    // Force sheet refresh by temporarily dismissing and showing again
                    showingReviewSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingReviewSheet = true
                    }
                }) {
                    HStack { Image(systemName: "questionmark.circle.fill"); Text("Request More Info") }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(10)
                }
                Button(action: { 
                    selectedReviewStatus = .rejected
                    // Force sheet refresh by temporarily dismissing and showing again
                    showingReviewSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingReviewSheet = true
                    }
                }) {
                    HStack { Image(systemName: "xmark.circle.fill"); Text("Reject") }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(10)
                }
            }
        }
        .padding(.top, 4)
    }
    
    private func submitReview() {
        let review = AdminReview(
            requestId: request.id,
            adminId: "admin-123",
            adminName: "Admin User",
            status: selectedReviewStatus,
            notes: reviewNotes,
            nextSteps: nextSteps.isEmpty ? nil : nextSteps
        )
        Task {
            do {
                _ = try await apiService.reviewOrganizationRequest(request.id, review: review)
                if selectedReviewStatus == .approved {
                    _ = try await apiService.approveOrganizationRequest(request.id)
                }
                await MainActor.run {
                    showingReviewSheet = false
                    dismiss()
                    onReview()
                }
            } catch {
                print("Error submitting review: \(error)")
            }
        }
    }
}


// MARK: - Simple My Alerts View
struct SimpleMyAlertsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var organizations: [Organization] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showingAddOrganization = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search organizations...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading organizations...")
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if organizations.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("No Organizations Followed")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Follow organizations to get alerts about incidents and updates in your area.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Find Organizations") {
                            showingAddOrganization = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredOrganizations) { organization in
                            NavigationLink(destination: OrganizationProfileView(organization: organization)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(organization.name)
                                            .font(.headline)
                                        Text(organization.type)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("My Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddOrganization = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddOrganization) {
                NavigationView {
                    VStack {
                        Text("Add Organization")
                            .font(.title)
                        Text("This feature is coming soon")
                            .foregroundColor(.secondary)
                        Button("Done") { showingAddOrganization = false }
                            .buttonStyle(.borderedProminent)
                    }
                    .navigationTitle("Add Organization")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") { showingAddOrganization = false }
                        }
                    }
                }
            }
            .onAppear {
                loadOrganizations()
            }
            .refreshable {
                await loadOrganizationsAsync()
            }
        }
    }
    
    private var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return organizations
        }
        
        return organizations.filter { org in
            org.name.localizedCaseInsensitiveContains(searchText) ||
            org.description?.localizedCaseInsensitiveContains(searchText) == true ||
            org.type.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadOrganizations() {
        isLoading = true
        
        Task {
            await loadOrganizationsAsync()
        }
    }
    
    private func loadOrganizationsAsync() async {
        isLoading = true
        
        do {
            let fetchedOrganizations = try await apiService.fetchOrganizations()
            
            await MainActor.run {
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



// MARK: - Add Group Sheet
struct AddGroupSheet: View {
    let organizationId: String
    let onAdd: (OrganizationGroup) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var groupDescription = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Group Information") {
                    TextField("Group Name", text: $groupName)
                    
                    TextField("Description (Optional)", text: $groupDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Text("This group will be created for the organization and users can choose to receive alerts from it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addGroup()
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addGroup() {
        let newGroup = OrganizationGroup(
            name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: groupDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : groupDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            organizationId: organizationId
        )
        
        onAdd(newGroup)
        dismiss()
    }
}

// MARK: - Address Autocomplete Field
struct AddressAutocompleteField: View {
    let placeholder: String
    @Binding var text: String
    @State private var searchResults: [CNPostalAddress] = []
    @State private var isSearching = false
    @State private var showingSuggestions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text) { _, newValue in
                    searchAddresses(query: newValue)
                }
                .onTapGesture {
                    if !searchResults.isEmpty {
                        showingSuggestions = true
                    }
                }
            
            // Suggestions Dropdown
            if showingSuggestions && !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchResults.prefix(5), id: \.self) { address in
                        Button(action: {
                            text = formatAddress(address)
                            showingSuggestions = false
                            searchResults = []
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatAddress(address))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                let city = address.city
                                let state = address.state
                                if !city.isEmpty && !state.isEmpty {
                                    Text("\(city), \(state)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .background(Color(.systemBackground))
                        
                        if address != searchResults.prefix(5).last {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .zIndex(1)
            }
        }
        .onTapGesture {
            // Close suggestions when tapping outside
            showingSuggestions = false
        }
    }
    
    private func searchAddresses(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            showingSuggestions = false
            return
        }
        
        isSearching = true
        
        // Use Apple's built-in address search
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let error = error {
                    print("Address search error: \(error)")
                    return
                }
                
                if let response = response {
                    // Convert MKMapItem results to CNPostalAddress format
                    self.searchResults = response.mapItems.compactMap { item in
                        guard let postalAddress = item.placemark.postalAddress else { return nil }
                        return postalAddress
                    }
                    
                    // Show suggestions if we have results
                    if !self.searchResults.isEmpty {
                        self.showingSuggestions = true
                    }
                }
            }
        }
    }
    
    private func formatAddress(_ address: CNPostalAddress) -> String {
        var components: [String] = []
        
        let street = address.street
        if !street.isEmpty {
            components.append(street)
        }
        
        let city = address.city
        if !city.isEmpty {
            components.append(city)
        }
        
        let state = address.state
        if !state.isEmpty {
            components.append(state)
        }
        
        let postalCode = address.postalCode
        if !postalCode.isEmpty {
            components.append(postalCode)
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Weather Alerts Tab View
struct WeatherAlertsTabView: View {
    @EnvironmentObject var weatherNotificationManager: WeatherNotificationManager
    @EnvironmentObject var weatherService: WeatherService
    @State private var showingWeatherSettings = false
    @State private var showingAddLocation = false
    @State private var followedLocations: [FollowedLocation] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Weather Status Card
                VStack(spacing: 16) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Weather Alerts")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Stay informed about severe weather in your area")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Alert Settings
                VStack(spacing: 16) {
                    HStack {
                        Text("Alert Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Configure") {
                            showingWeatherSettings = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 12) {
                        // Weather Alerts Toggle
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Weather Alerts")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Severe weather warnings and advisories")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $weatherNotificationManager.weatherAlertsEnabled)
                                .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Critical Alerts Toggle
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Critical Alerts")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Life-threatening weather conditions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $weatherNotificationManager.criticalAlertsEnabled)
                                .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Notification Status
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: weatherNotificationManager.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(weatherNotificationManager.hasPermission ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weatherNotificationManager.hasPermission ? "Notifications Enabled" : "Notifications Disabled")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(weatherNotificationManager.hasPermission ? "You'll receive weather alerts" : "Enable notifications to get alerts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !weatherNotificationManager.hasPermission {
                            Button("Enable") {
                                weatherNotificationManager.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Followed Locations
                VStack(spacing: 16) {
                    HStack {
                        Text("Followed Locations")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Add Location") {
                            showingAddLocation = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if followedLocations.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "location.slash")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("No Locations Added")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Add cities or zip codes to get weather alerts for specific areas")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(followedLocations, id: \.id) { location in
                                FollowedLocationRow(
                                    location: location,
                                    onToggle: { isEnabled in
                                        toggleLocation(locationId: location.id.uuidString, enabled: isEnabled)
                                    },
                                    onDelete: {
                                        deleteLocation(locationId: location.id.uuidString)
                                    }
                                )
                            }
                        }
                    }
                }
                
                // Quick Actions
                VStack(spacing: 12) {
                    Button("View Current Alerts") {
                        // This will be handled by the MapView weather button
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Refresh Weather Data") {
                        // Trigger weather refresh
                        weatherService.refreshWeatherData()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .navigationTitle("Weather Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingWeatherSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingWeatherSettings) {
                WeatherSettingsSheet()
            }
            .onChange(of: weatherNotificationManager.weatherAlertsEnabled) { _, newValue in
                weatherNotificationManager.updateSettings()
            }
            .onChange(of: weatherNotificationManager.criticalAlertsEnabled) { _, newValue in
                weatherNotificationManager.updateSettings()
            }
            .onAppear {
                loadFollowedLocations()
            }
            .sheet(isPresented: $showingAddLocation) {
                AddLocationSheet { newLocation in
                    followedLocations.append(newLocation)
                    saveFollowedLocations()
                }
            }
        }
    }
    
    private func loadFollowedLocations() {
        // Load saved locations from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "followedWeatherLocations"),
           let locations = try? JSONDecoder().decode([FollowedLocation].self, from: data) {
            followedLocations = locations
        }
    }
    
    private func saveFollowedLocations() {
        // Save locations to UserDefaults
        if let data = try? JSONEncoder().encode(followedLocations) {
            UserDefaults.standard.set(data, forKey: "followedWeatherLocations")
        }
    }
    
    private func toggleLocation(locationId: String, enabled: Bool) {
        if let index = followedLocations.firstIndex(where: { $0.id.uuidString == locationId }) {
            followedLocations[index].isEnabled = enabled
            saveFollowedLocations()
        }
    }
    
    private func deleteLocation(locationId: String) {
        followedLocations.removeAll { $0.id.uuidString == locationId }
        saveFollowedLocations()
    }
}

// MARK: - Weather Settings Sheet
struct WeatherSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var weatherNotificationManager: WeatherNotificationManager
    
    var body: some View {
        NavigationView {
            Form {
                Section("Weather Alert Types") {
                    Text("Configure which types of weather alerts you want to receive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Weather Alerts Toggle
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weather Alerts")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Severe weather warnings and advisories")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $weatherNotificationManager.weatherAlertsEnabled)
                            .labelsHidden()
                    }
                    
                    // Critical Alerts Toggle
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Critical Alerts")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Life-threatening weather conditions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $weatherNotificationManager.criticalAlertsEnabled)
                            .labelsHidden()
                    }
                }
                
                Section("Notification Settings") {
                    if !weatherNotificationManager.hasPermission {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            
                            Text("Notifications Disabled")
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Button("Enable") {
                                weatherNotificationManager.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Text("Notifications Enabled")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section("About") {
                    Text("Weather alerts are provided by the National Weather Service and are updated every 5 minutes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Weather Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        weatherNotificationManager.updateSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}









// MARK: - Followed Location Row
struct FollowedLocationRow: View {
    let location: FollowedLocation
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Location Icon
            Image(systemName: location.type.icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            
            // Location Info
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(location.type.displayName): \(location.value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { location.isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .scaleEffect(0.8)
            
            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Add Location Sheet
struct AddLocationSheet: View {
    let onAdd: (FollowedLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var locationName = ""
    @State private var selectedType: WeatherLocationType = .city
    @State private var locationValue = ""
    @State private var isSearching = false
    @State private var searchResults: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location Information") {
                    TextField("Location Name (e.g., Wylie, TX)", text: $locationName)
                    
                    Picker("Location Type", selection: $selectedType) {
                        ForEach(WeatherLocationType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    
                    TextField(selectedType == .city ? "City, State" : 
                             selectedType == .zipCode ? "Zip Code" : 
                             "Latitude, Longitude", text: $locationValue)
                        .onChange(of: locationValue) { _, newValue in
                            if selectedType == .city {
                                searchCities(query: newValue)
                            }
                        }
                }
                
                if selectedType == .city && !searchResults.isEmpty {
                    Section("Suggestions") {
                        ForEach(searchResults, id: \.self) { suggestion in
                            Button(action: {
                                locationName = suggestion
                                locationValue = suggestion
                                searchResults = []
                            }) {
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundColor(.blue)
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section {
                    Text("This location will be monitored for weather alerts. You can enable/disable alerts for each location individually.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addLocation()
                    }
                    .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                             locationValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func searchCities(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Simple city suggestions for common Texas cities
        let texasCities = [
            "Wylie, TX", "Garland, TX", "Southlake, TX", "Plano, TX", "Dallas, TX",
            "Fort Worth, TX", "Arlington, TX", "Irving, TX", "Frisco, TX", "McKinney, TX",
            "Allen, TX", "Richardson, TX", "Carrollton, TX", "Lewisville, TX", "Flower Mound, TX"
        ]
        
        searchResults = texasCities.filter { city in
            city.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func addLocation() {
        let newLocation = FollowedLocation(
            name: locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            value: locationValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        onAdd(newLocation)
        dismiss()
    }
}

#Preview {
    ContentView()
        .environmentObject(APIService())
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager())
} 