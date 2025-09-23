//
//  ScheduledAlertDetailView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct ScheduledAlertDetailView: View {
    let alert: ScheduledAlert
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    
    init(alert: ScheduledAlert, calendarService: CalendarService) {
        self.alert = alert
        self.calendarService = calendarService
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        timeFormatter.dateFormat = "h:mm a"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(alert.severity.color)
                                .frame(width: 16, height: 16)
                            
                            Text(alert.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                        }
                        
                        Text(alert.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Alert Type & Severity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Alert Details")
                            .font(.headline)
                        
                        HStack {
                            Text("Type:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(alert.type.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Severity:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(alert.severity.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(alert.severity.color)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Schedule
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dateFormatter.string(from: alert.scheduledDate))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(timeFormatter.string(from: alert.scheduledDate))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Organization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Organization")
                            .font(.headline)
                        
                        Text(alert.organizationName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let groupName = alert.groupName {
                            Text("Group: \(groupName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Location
                    if let location = alert.location {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.headline)
                            
                            Text(location.fullAddress)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Recurrence
                    if alert.isRecurring, let pattern = alert.recurrencePattern {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recurrence")
                                .font(.headline)
                            
                            Text("Repeats every \(pattern.interval) \(pattern.frequency.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let endDate = pattern.endDate {
                                Text("Until \(dateFormatter.string(from: endDate))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Expiration
                    if let expiresAt = alert.expiresAt {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expiration")
                                .font(.headline)
                            
                            Text("\(dateFormatter.string(from: expiresAt)) at \(timeFormatter.string(from: expiresAt))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Created By
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Created By")
                            .font(.headline)
                        
                        Text(alert.postedBy)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Scheduled Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Alert") {
                            showingEditView = true
                        }
                        
                        Button("Delete Alert", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditScheduledAlertView(alert: alert, calendarService: calendarService)
            }
            .alert("Delete Alert", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAlert()
                }
            } message: {
                Text("Are you sure you want to delete this scheduled alert? This action cannot be undone.")
            }
        }
    }
    
    private func deleteAlert() {
        isDeleting = true
        
        Task {
            do {
                try await calendarService.deleteScheduledAlert(alert.id, organizationId: alert.organizationId)
                
                // Calendar events are no longer supported - only scheduled alerts
                // No need to delete associated calendar events
                
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // Handle error
                }
            }
        }
    }
}

// MARK: - Edit Scheduled Alert View
struct EditScheduledAlertView: View {
    let alert: ScheduledAlert
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var title: String
    @State private var description: String
    @State private var selectedType: IncidentType
    @State private var selectedSeverity: IncidentSeverity
    @State private var scheduledDate: Date
    @State private var location: String
    @State private var city: String
    @State private var state: String
    @State private var zipCode: String
    @State private var selectedOrganization: Organization?
    @State private var selectedGroup: OrganizationGroup?
    @State private var isRecurring: Bool
    @State private var recurrenceFrequency: RecurrenceFrequency
    @State private var recurrenceInterval: Int
    @State private var recurrenceEndDate: Date
    @State private var expiresAt: Date?
    @State private var hasExpiration: Bool
    
    @State private var organizations: [Organization] = []
    @State private var groups: [OrganizationGroup] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init(alert: ScheduledAlert, calendarService: CalendarService) {
        self.alert = alert
        self.calendarService = calendarService
        
        _title = State(initialValue: alert.title)
        _description = State(initialValue: alert.description)
        _selectedType = State(initialValue: alert.type)
        _selectedSeverity = State(initialValue: alert.severity)
        _scheduledDate = State(initialValue: alert.scheduledDate)
        _location = State(initialValue: alert.location?.address ?? "")
        _city = State(initialValue: alert.location?.city ?? "")
        _state = State(initialValue: alert.location?.state ?? "")
        _zipCode = State(initialValue: alert.location?.zipCode ?? "")
        _isRecurring = State(initialValue: alert.isRecurring)
        _recurrenceFrequency = State(initialValue: alert.recurrencePattern?.frequency ?? .weekly)
        _recurrenceInterval = State(initialValue: alert.recurrencePattern?.interval ?? 1)
        _recurrenceEndDate = State(initialValue: alert.recurrencePattern?.endDate ?? Date().addingTimeInterval(86400 * 30))
        _expiresAt = State(initialValue: alert.expiresAt)
        _hasExpiration = State(initialValue: alert.expiresAt != nil)
    }
    
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
            .navigationTitle("Edit Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAlert()
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
                    self.selectedOrganization = orgs.first { $0.id == alert.organizationId }
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
        selectedGroup = groups.first { $0.id == alert.groupId }
    }
    
    private func saveAlert() {
        guard !title.isEmpty,
              !description.isEmpty,
              let organization = selectedOrganization else { return }
        
        isLoading = true
        
        Task {
            do {
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
                
                let updatedAlert = ScheduledAlert(
                    id: alert.id,
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
                    postedBy: alert.postedBy,
                    postedByUserId: alert.postedByUserId,
                    createdAt: alert.createdAt,
                    updatedAt: Date(),
                    isActive: alert.isActive,
                    imageURLs: alert.imageURLs,
                    expiresAt: hasExpiration ? expiresAt : nil,
                    calendarEventId: alert.calendarEventId
                )
                
                try await calendarService.updateScheduledAlert(updatedAlert)
                
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
}

#Preview {
    ScheduledAlertDetailView(
        alert: ScheduledAlert(
            title: "Sample Alert",
            description: "This is a sample scheduled alert description",
            organizationId: "org123",
            organizationName: "Sample Organization",
            type: .emergency,
            severity: .high,
            scheduledDate: Date().addingTimeInterval(3600),
            postedBy: "John Doe",
            postedByUserId: "user123"
        ),
        calendarService: CalendarService()
    )
}
