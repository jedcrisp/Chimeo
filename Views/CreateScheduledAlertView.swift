//
//  CreateScheduledAlertView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

// MARK: - Custom View Modifiers and Styles

struct CardHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
    }
}

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
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Schedule New Alert")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Text("Create a scheduled alert for your organization")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Alert Details Card
                    VStack(alignment: .leading, spacing: 20) {
                        CardHeader(title: "Alert Details", icon: "exclamationmark.triangle.fill", color: .orange)
                        
                        VStack(spacing: 16) {
                            // Title Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alert Title")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                TextField("Enter alert title", text: $title)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                            
                            // Description Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                TextField("Describe the alert details", text: $description, axis: .vertical)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                            
                            // Type and Severity Row
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Type")
                                        .font(.headline)
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
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Severity")
                                        .font(.headline)
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
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Schedule Card
                    VStack(alignment: .leading, spacing: 20) {
                        CardHeader(title: "Schedule", icon: "calendar", color: .blue)
                        
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
                    VStack(spacing: 12) {
                        Button(action: scheduleAlert) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "bell.badge.fill")
                                }
                                Text(isLoading ? "Scheduling..." : "Schedule Alert")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(title.isEmpty || description.isEmpty || selectedOrganization == nil || isLoading)
                        .opacity((title.isEmpty || description.isEmpty || selectedOrganization == nil || isLoading) ? 0.6 : 1.0)
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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
