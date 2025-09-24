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
                VStack(spacing: 20) {
                    // Professional Header with Gradient
                    VStack(spacing: 20) {
                        // Alert Title and Severity Badge
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    // Severity Indicator
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(alert.severity.color)
                                        .frame(width: 4, height: 40)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(alert.title)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        
                                        Text(alert.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                
                                // Type and Severity Pills
                                HStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: alert.type.icon)
                                            .font(.caption)
                                            .foregroundColor(alert.type.color)
                                        Text(alert.type.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(alert.type.color.opacity(0.1))
                                    .foregroundColor(alert.type.color)
                                    .cornerRadius(12)
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundColor(alert.severity.color)
                                        Text(alert.severity.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(alert.severity.color.opacity(0.1))
                                    .foregroundColor(alert.severity.color)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground),
                                Color(.systemGray6).opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Schedule Information Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text("Schedule")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(dateFormatter.string(from: alert.scheduledDate))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(timeFormatter.string(from: alert.scheduledDate))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    // Organization Information Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "building.2")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("Organization")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "building.2.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(alert.organizationName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            if let groupName = alert.groupName, !groupName.isEmpty {
                                HStack {
                                    Image(systemName: "person.3")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Group: \(groupName)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Image(systemName: "person.3")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("All Members")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    // Location Information Card
                    if let location = alert.location {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "location")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                Text("Location")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "location.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(location.fullAddress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    } else {
                        // Location unavailable card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "location.slash")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                Text("Location")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Location unavailable")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }
                    
                    // Recurrence Information Card
                    if alert.isRecurring, let pattern = alert.recurrencePattern {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "repeat")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                Text("Recurrence")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Repeats every \(pattern.interval) \(pattern.frequency.rawValue)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                
                                if let endDate = pattern.endDate {
                                    HStack {
                                        Image(systemName: "calendar.badge.minus")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Until \(dateFormatter.string(from: endDate))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }
                    
                    // Expiration Information Card
                    if let expiresAt = alert.expiresAt {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.title3)
                                    .foregroundColor(.red)
                                Text("Expiration")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(dateFormatter.string(from: expiresAt))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(timeFormatter.string(from: expiresAt))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }
                    
                    // Created By Information Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.title3)
                                .foregroundColor(.blue)
                            Text("Created By")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "person")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(alert.postedBy)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
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
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Edit Alert")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Text("Update your scheduled alert details")
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
                    VStack(spacing: 16) {
                        // Primary Action Button
                        Button(action: saveAlert) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                }
                                Text(isLoading ? "Saving Changes..." : "Save Changes")
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
                                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
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
