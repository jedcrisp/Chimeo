import SwiftUI
import FirebaseAuth
import FirebaseFirestore


struct CreateScheduledAlertView: View {
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: IncidentType?
    @State private var selectedSeverity: IncidentSeverity?
    @State private var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var location = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var currentUserOrganization: Organization?
    @State private var selectedGroup: OrganizationGroup?
    @State private var isRecurring = false
    @State private var recurrenceFrequency = RecurrenceFrequency.weekly
    @State private var recurrenceInterval = 1
    @State private var recurrenceEndDate = Date().addingTimeInterval(86400 * 30) // 30 days later
    @State private var expiresAt: Date?
    @State private var hasExpiration = false
    
    @State private var groups: [OrganizationGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Modern Header with Close Button
                    VStack(spacing: 12) {
                        HStack {
                            // Close Button
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                    .background(
                                        Circle()
                                            .fill(Color(.systemBackground))
                                            .frame(width: 32, height: 32)
                                    )
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .center, spacing: 4) {
                                Text("Schedule Alert")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Create a scheduled alert")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Placeholder for symmetry
                            Color.clear
                                .frame(width: 32, height: 32)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Alert Details Section
                    VStack(spacing: 0) {
                        // Section Header
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            Text("Alert Details")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Title Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alert Title")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                TextField("Enter alert title", text: $title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                            }
                            
                            // Description Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                TextField("Describe the alert details", text: $description, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(3...6)
                                    .font(.body)
                            }
                            
                            // Type and Severity Row (Optional)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Type (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Picker("Type", selection: $selectedType) {
                                        Text("None").tag(nil as IncidentType?)
                                        ForEach(IncidentType.allCases, id: \.self) { type in
                                            HStack {
                                                Image(systemName: type.icon)
                                                    .foregroundColor(type.color)
                                                Text(type.displayName)
                                            }
                                            .tag(type as IncidentType?)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Severity (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Picker("Severity", selection: $selectedSeverity) {
                                        Text("None").tag(nil as IncidentSeverity?)
                                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                                            HStack {
                                                Image(systemName: severity.icon)
                                                    .foregroundColor(severity.color)
                                                Text(severity.displayName)
                                            }
                                            .tag(severity as IncidentSeverity?)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                    
                    // Schedule Section
                    VStack(spacing: 0) {
                        // Section Header
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("Schedule")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        
                        VStack(spacing: 16) {
                            // Date Picker
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Scheduled Date & Time")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 12) {
                                    // Date Picker
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                        DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                                            .datePickerStyle(CompactDatePickerStyle())
                                        Spacer()
                                    }
                                    
                                    Divider()
                                    
                                    // Time Picker
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                        DatePicker("Time", selection: $scheduledDate, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(CompactDatePickerStyle())
                                        Spacer()
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                            }
                            
                            // Recurring Toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Repeat Alert")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Set up recurring alerts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $isRecurring)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 8)
                            
                            // Recurring Options
                            if isRecurring {
                                VStack(spacing: 12) {
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recurrence Pattern")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Picker("Frequency", selection: $recurrenceFrequency) {
                                            ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                                                Text(frequency.displayName).tag(frequency)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        
                                        HStack {
                                            Text("Every")
                                                .foregroundColor(.secondary)
                                            Stepper("\(recurrenceInterval)", value: $recurrenceInterval, in: 1...99)
                                                .labelsHidden()
                                            Text(recurrenceFrequency.rawValue)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        
                                        DatePicker("End Date", selection: $recurrenceEndDate, displayedComponents: .date)
                                            .datePickerStyle(CompactDatePickerStyle())
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Organization & Group Card
                    VStack(alignment: .leading, spacing: 20) {
                        CardHeader(title: "Organization & Group", icon: "building.2", color: .green)
                        
                        VStack(spacing: 16) {
                            // Current Organization Display
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Organization")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let organization = currentUserOrganization {
                                    HStack {
                                        if let logoURL = organization.logoURL, !logoURL.isEmpty {
                                            AsyncImage(url: URL(string: logoURL)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Image(systemName: "building.2")
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(width: 24, height: 24)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "building.2")
                                                .foregroundColor(.gray)
                                                .frame(width: 24, height: 24)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(organization.name)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text("Your Organization")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title3)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green.opacity(0.1))
                                    )
                                } else {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text("Loading organization...")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange.opacity(0.1))
                                    )
                                }
                            }
                            
                            // Group Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Target Group")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !groups.isEmpty {
                                    Picker("Group", selection: $selectedGroup) {
                                        Text("All Members").tag(nil as OrganizationGroup?)
                                        ForEach(groups, id: \.id) { group in
                                            HStack {
                                                Image(systemName: "person.3")
                                                    .foregroundColor(.blue)
                                                Text(group.name)
                                            }
                                            .tag(group as OrganizationGroup?)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .onAppear {
                                        print("🔍 Group picker appeared with \(groups.count) groups")
                                        for group in groups {
                                            print("   📋 Group: \(group.name) (ID: \(group.id))")
                                        }
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: "person.3")
                                            .foregroundColor(.secondary)
                                        Text("No groups available (\(groups.count))")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                                    .onAppear {
                                        print("🔍 No groups available - groups count: \(groups.count)")
                                    }
                                }
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Location Card
                    VStack(alignment: .leading, spacing: 20) {
                        CardHeader(title: "Location", icon: "location", color: .purple)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Address")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                TextField("Street address", text: $location)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("City")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    TextField("City", text: $city)
                                        .textFieldStyle(ModernTextFieldStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("State")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    TextField("State", text: $state)
                                        .textFieldStyle(ModernTextFieldStyle())
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ZIP Code")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                TextField("ZIP Code", text: $zipCode)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Expiration Card
                    VStack(alignment: .leading, spacing: 20) {
                        CardHeader(title: "Expiration", icon: "clock", color: .red)
                        
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Set Expiration")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Optional: Set when this alert expires")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $hasExpiration)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 8)
                            
                            if hasExpiration {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Expires At")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    DatePicker("", selection: Binding(
                                        get: { expiresAt ?? Date().addingTimeInterval(86400 * 7) },
                                        set: { expiresAt = $0 }
                                    ), displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Primary Action Button
                        Button(action: scheduleAlert) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isLoading ? "Creating Alert..." : "Schedule Alert")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .disabled(title.isEmpty || description.isEmpty || currentUserOrganization == nil || isLoading)
                        .opacity((title.isEmpty || description.isEmpty || currentUserOrganization == nil || isLoading) ? 0.6 : 1.0)
                        
                        // Secondary Action Button
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Schedule Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                Task {
                    await loadCurrentUserOrganization()
                }
            }
        }
    }
    
    private func loadCurrentUserOrganization() async {
        do {
            // Get current user
            print("🔍 Loading current user organization...")
            let currentUser = try await getCurrentUser()
            print("✅ Got current user: \(currentUser.name ?? "Unknown") (ID: \(currentUser.id))")
            print("🔍 User organizations: \(currentUser.organizations ?? [])")
            
            // Get user's organization ID
            var organizationId: String?
            
            // First try to get from user's organizations array
            if let orgs = currentUser.organizations, !orgs.isEmpty {
                organizationId = orgs.first
                print("✅ Found organization from user.organizations: \(organizationId!)")
            } else {
                // Try to get from Firebase Auth user's custom claims or database
                print("🔍 User has no organizations array, trying to find organization from database...")
                
                // Try to find organization by checking if user is admin of any organization
                let db = Firestore.firestore()
                let orgsQuery = try await db.collection("organizations")
                    .whereField("adminIds.\(currentUser.id)", isEqualTo: true)
                    .getDocuments()
                
                if let firstOrg = orgsQuery.documents.first {
                    organizationId = firstOrg.documentID
                    print("✅ Found organization from adminIds query: \(organizationId!)")
                } else {
                    print("❌ No organization found where user is admin")
                }
            }
            
            guard let orgId = organizationId else {
                print("❌ User has no organization")
                await MainActor.run {
                    errorMessage = "You are not associated with any organization. Please contact your administrator."
                    showingError = true
                }
                return
            }
            
            print("🔍 User's organization ID: \(orgId)")
            
            // Fetch the organization details
            guard let organization = try await apiService.getOrganizationById(orgId) else {
                print("❌ Organization not found with ID: \(orgId)")
                await MainActor.run {
                    errorMessage = "Organization not found. Please contact your administrator."
                    showingError = true
                }
                return
            }
            
            print("✅ Fetched organization: \(organization.name) (ID: \(organization.id))")
            print("🔍 Organization groups from object: \(organization.groups?.count ?? 0)")
            
            await MainActor.run {
                self.currentUserOrganization = organization
            }
            
            // Load groups for this organization
            print("🔍 Loading groups for organization...")
            await loadGroups(for: organization)
            
        } catch {
            print("Error loading current user organization: \(error)")
            await MainActor.run {
                if error is APIError && error as? APIError == .unauthorized {
                    errorMessage = "Unable to verify your authentication. Please try logging out and back in."
                } else {
                    errorMessage = "Failed to load your organization: \(error.localizedDescription)"
                }
                showingError = true
            }
        }
    }
    
    
    private func loadGroups(for organization: Organization?) async {
        guard let organization = organization else {
            await MainActor.run {
                groups = []
                selectedGroup = nil
            }
            return
        }
        
        do {
            // Fetch groups from the database using the API service
            let fetchedGroups = try await apiService.getOrganizationGroups(organizationId: organization.id)
            
            await MainActor.run {
                groups = fetchedGroups
                selectedGroup = nil
                print("✅ Loaded \(fetchedGroups.count) groups for organization: \(organization.name)")
            }
        } catch {
            print("❌ Error loading groups: \(error)")
            await MainActor.run {
                groups = []
                selectedGroup = nil
            }
        }
    }
    
    private func scheduleAlert() {
        guard !title.isEmpty,
              !description.isEmpty,
              let organization = currentUserOrganization else { return }
        
        isLoading = true
        
        Task {
            do {
                let currentUser = try await getCurrentUser()
                
                let alertLocation: Location? = {
                    if !location.isEmpty || !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
                        return Location(
                            latitude: 0.0, // Will be geocoded later
                            longitude: 0.0,
                            address: location.isEmpty ? nil : location,
                            city: city.isEmpty ? nil : city,
                            state: state.isEmpty ? nil : state,
                            zipCode: zipCode.isEmpty ? nil : zipCode
                        )
                    }
                    return nil
                }()
                
                let recurrencePattern: RecurrencePattern? = isRecurring ? RecurrencePattern(
                    frequency: recurrenceFrequency,
                    interval: recurrenceInterval,
                    endDate: recurrenceEndDate
                ) : nil
                
                let alert = ScheduledAlert(
                    title: title,
                    description: description,
                    organizationId: organization.id,
                    organizationName: organization.name,
                    groupId: selectedGroup?.id,
                    groupName: selectedGroup?.name,
                    type: selectedType ?? .other,
                    severity: selectedSeverity ?? .medium,
                    location: alertLocation,
                    scheduledDate: scheduledDate,
                    isRecurring: isRecurring,
                    recurrencePattern: recurrencePattern,
                    postedBy: currentUser.name ?? "Unknown",
                    postedByUserId: currentUser.id,
                    expiresAt: hasExpiration ? expiresAt : nil
                )
                
                try await calendarService.createScheduledAlert(alert)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func getCurrentUser() async throws -> User {
        // Try multiple sources for current user
        var currentUser: User?
        
        // First try APIService
        if let apiUser = apiService.currentUser {
            currentUser = apiUser
            print("✅ Found user from APIService: \(apiUser.name ?? "Unknown")")
        }
        // Then try UserDefaults
        else if let data = UserDefaults.standard.data(forKey: "currentUser"),
                let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
            print("✅ Found user from UserDefaults: \(user.name ?? "Unknown")")
        }
        // Finally try Firebase Auth and create user from it
        else if let firebaseUser = Auth.auth().currentUser {
            print("✅ Found Firebase user, creating User object: \(firebaseUser.uid)")
            currentUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email,
                name: firebaseUser.displayName ?? "User",
                phone: firebaseUser.phoneNumber,
                profilePhotoURL: firebaseUser.photoURL?.absoluteString,
                homeLocation: nil,
                workLocation: nil,
                schoolLocation: nil,
                alertRadius: 10.0,
                preferences: UserPreferences(
                    incidentTypes: Array(IncidentType.allCases),
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                ),
                createdAt: Date(),
                isAdmin: false
            )
        }
        
        guard let user = currentUser else {
            print("❌ No current user found from any source")
            throw APIError.unauthorized
        }
        
        return user
    }
}

// MARK: - Color Extension for Hex String
extension Color {
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
}


#Preview {
    CreateScheduledAlertView(calendarService: CalendarService())
}
