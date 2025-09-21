//
//  CreateScheduledAlertView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

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
            Form {
                Section("Alert Details") {
                    TextField("Alert Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                            Text(severity.displayName).tag(severity)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Scheduled Date", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Toggle("Repeat", isOn: $isRecurring)
                    
                    if isRecurring {
                        Picker("Frequency", selection: $recurrenceFrequency) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        
                        HStack {
                            Text("Every")
                            Stepper("\(recurrenceInterval)", value: $recurrenceInterval, in: 1...99)
                            Text(recurrenceFrequency.rawValue)
                        }
                        
                        DatePicker("End Date", selection: $recurrenceEndDate, displayedComponents: .date)
                    }
                }
                
                Section("Organization") {
                    Picker("Organization", selection: $selectedOrganization) {
                        Text("Select Organization").tag(nil as Organization?)
                        ForEach(organizations, id: \.id) { org in
                            Text(org.name).tag(org as Organization?)
                        }
                    }
                    .onChange(of: selectedOrganization) { _, newValue in
                        loadGroups(for: newValue)
                    }
                    
                    if !groups.isEmpty {
                        Picker("Group (Optional)", selection: $selectedGroup) {
                            Text("All Members").tag(nil as OrganizationGroup?)
                            ForEach(groups, id: \.id) { group in
                                Text(group.name).tag(group as OrganizationGroup?)
                            }
                        }
                    }
                }
                
                Section("Location") {
                    TextField("Address", text: $location)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("ZIP Code", text: $zipCode)
                }
                
                Section("Expiration") {
                    Toggle("Set Expiration", isOn: $hasExpiration)
                    
                    if hasExpiration {
                        DatePicker("Expires At", selection: Binding(
                            get: { expiresAt ?? Date().addingTimeInterval(86400 * 7) },
                            set: { expiresAt = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Schedule Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") {
                        scheduleAlert()
                    }
                    .disabled(title.isEmpty || description.isEmpty || selectedOrganization == nil || isLoading)
                }
            }
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
                
                // Create corresponding calendar event
                let event = CalendarEvent(
                    title: title,
                    description: description,
                    startDate: scheduledDate,
                    endDate: scheduledDate.addingTimeInterval(3600), // 1 hour duration
                    isAllDay: false,
                    location: alertLocation?.fullAddress,
                    alertId: alert.id,
                    createdBy: currentUser.name ?? "Unknown",
                    createdByUserId: currentUser.id,
                    isRecurring: isRecurring,
                    recurrencePattern: recurrencePattern,
                    color: selectedSeverity.color.hexString
                )
                
                try await calendarService.createEvent(event)
                
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
