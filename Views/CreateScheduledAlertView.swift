import SwiftUI


struct CreateScheduledAlertView: View {
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType = IncidentType.emergency
    @State private var selectedSeverity = IncidentSeverity.high
    @State private var scheduledDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var location = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var selectedOrganization: Organization?
    @State private var selectedGroup: OrganizationGroup?
    @State private var isRecurring = false
    @State private var recurrenceFrequency = RecurrenceFrequency.weekly
    @State private var recurrenceInterval = 1
    @State private var recurrenceEndDate = Date().addingTimeInterval(86400 * 30) // 30 days later
    @State private var expiresAt: Date?
    @State private var hasExpiration = false
    
    @State private var organizations: [Organization] = []
    @State private var groups: [OrganizationGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Modern Header
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Schedule Alert")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Create a scheduled alert for your organization")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Image(systemName: "bell.badge.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                )
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
                            
                            // Type and Severity Row
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Type")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Picker("Type", selection: $selectedType) {
                                        ForEach(IncidentType.allCases, id: \.self) { type in
                                            HStack {
                                                Image(systemName: type.icon)
                                                    .foregroundColor(type.color)
                                                Text(type.displayName)
                                            }
                                            .tag(type)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Severity")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Picker("Severity", selection: $selectedSeverity) {
                                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                                            HStack {
                                                Image(systemName: severity.icon)
                                                    .foregroundColor(severity.color)
                                                Text(severity.displayName)
                                            }
                                            .tag(severity)
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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Scheduled Date & Time")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                DatePicker("", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
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
                    
                    // Organization Card
                    VStack(alignment: .leading, spacing: 20) {
                        CardHeader(title: "Organization", icon: "building.2", color: .green)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Organization")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Picker("Organization", selection: $selectedOrganization) {
                                    Text("Choose an organization").tag(nil as Organization?)
                                    ForEach(organizations, id: \.id) { org in
                                        HStack {
                                            if let logoURL = org.logoURL, !logoURL.isEmpty {
                                                AsyncImage(url: URL(string: logoURL)) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    Image(systemName: "building.2")
                                                        .foregroundColor(.gray)
                                                }
                                                .frame(width: 20, height: 20)
                                                .clipShape(Circle())
                                            } else {
                                                Image(systemName: "building.2")
                                                    .foregroundColor(.gray)
                                                    .frame(width: 20, height: 20)
                                            }
                                            Text(org.name)
                                        }
                                        .tag(org as Organization?)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .onChange(of: selectedOrganization) { _, newValue in
                                    loadGroups(for: newValue)
                                }
                            }
                            
                            if !groups.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Target Group (Optional)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Picker("Group", selection: $selectedGroup) {
                                        Text("All Members").tag(nil as OrganizationGroup?)
                                        ForEach(groups, id: \.id) { group in
                                            Text(group.name).tag(group as OrganizationGroup?)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
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
                        .disabled(title.isEmpty || description.isEmpty || selectedOrganization == nil || isLoading)
                        .opacity((title.isEmpty || description.isEmpty || selectedOrganization == nil || isLoading) ? 0.6 : 1.0)
                        
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
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                loadOrganizations()
            }
        }
    }
    
    private func loadOrganizations() {
        Task {
            do {
                let orgs = try await apiService.fetchOrganizations()
                await MainActor.run {
                    self.organizations = orgs
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load organizations: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func loadGroups(for organization: Organization?) {
        guard let organization = organization else {
            groups = []
            selectedGroup = nil
            return
        }
        
        groups = organization.groups ?? []
        selectedGroup = nil
    }
    
    private func scheduleAlert() {
        guard !title.isEmpty,
              !description.isEmpty,
              let organization = selectedOrganization else { return }
        
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
                    type: selectedType,
                    severity: selectedSeverity,
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
        // This should be implemented to get the current user
        // For now, return a mock user
        return User(
            id: "mock_user_id",
            email: "user@example.com",
            name: "Current User",
            phone: nil,
            profilePhotoURL: nil,
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
