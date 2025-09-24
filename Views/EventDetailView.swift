import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    
    init(event: CalendarEvent, calendarService: CalendarService) {
        self.event = event
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
                                .fill(Color(event.color))
                                .frame(width: 16, height: 16)
                            
                            Text(event.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                        }
                        
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Date & Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date & Time")
                            .font(.headline)
                        
                        if event.isAllDay {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("All Day")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(dateFormatter.string(from: event.startDate))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dateFormatter.string(from: event.startDate))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Location
                    if let location = event.location, !location.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location")
                                .font(.headline)
                            
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Recurrence
                    if event.isRecurring, let pattern = event.recurrencePattern {
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
                    
                    // Created By
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Created By")
                            .font(.headline)
                        
                        Text(event.createdBy)
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
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Event") {
                            showingEditView = true
                        }
                        
                        Button("Delete Event", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditEventView(event: event, calendarService: calendarService)
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete this event? This action cannot be undone.")
            }
        }
    }
    
    private func deleteEvent() {
        isDeleting = true
        
        Task {
            do {
                // Calendar events are no longer supported - only scheduled alerts
                print("⚠️ Calendar events are no longer supported. Please use scheduled alerts instead.")
                
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

// MARK: - Edit Event View
struct EditEventView: View {
    let event: CalendarEvent
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var selectedColor: CalendarEventColor
    @State private var isRecurring: Bool
    @State private var recurrenceFrequency: RecurrenceFrequency
    @State private var recurrenceInterval: Int
    @State private var recurrenceEndDate: Date
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init(event: CalendarEvent, calendarService: CalendarService) {
        self.event = event
        self.calendarService = calendarService
        
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description ?? "")
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _isAllDay = State(initialValue: event.isAllDay)
        _location = State(initialValue: event.location ?? "")
        _selectedColor = State(initialValue: CalendarEventColor(rawValue: event.color) ?? .blue)
        _isRecurring = State(initialValue: event.isRecurring)
        _recurrenceFrequency = State(initialValue: event.recurrencePattern?.frequency ?? .weekly)
        _recurrenceInterval = State(initialValue: event.recurrencePattern?.interval ?? 1)
        _recurrenceEndDate = State(initialValue: event.recurrencePattern?.endDate ?? Date().addingTimeInterval(86400 * 30))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Location (Optional)", text: $location)
                }
                
                Section("Date & Time") {
                    Toggle("All Day", isOn: $isAllDay)
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    
                    if !isAllDay {
                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section("Appearance") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(CalendarEventColor.allCases, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 20, height: 20)
                                Text(color.displayName)
                            }
                            .tag(color)
                        }
                    }
                }
                
                Section("Recurrence") {
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
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty || isLoading)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
        }
    }
    
    private func saveEvent() {
        guard !title.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let recurrencePattern: RecurrencePattern? = isRecurring ? RecurrencePattern(
                    frequency: recurrenceFrequency,
                    interval: recurrenceInterval,
                    endDate: recurrenceEndDate
                ) : nil
                
                let updatedEvent = CalendarEvent(
                    id: event.id,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    startDate: startDate,
                    endDate: isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate : endDate,
                    isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location,
                    alertId: event.alertId,
                    createdBy: event.createdBy,
                    createdByUserId: event.createdByUserId,
                    createdAt: event.createdAt,
                    updatedAt: Date(),
                    isRecurring: isRecurring,
                    recurrencePattern: recurrencePattern,
                    color: selectedColor.rawValue
                )
                
                // Calendar events are no longer supported - only scheduled alerts
                print("⚠️ Calendar events are no longer supported. Please use scheduled alerts instead.")
                
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
    EventDetailView(
        event: CalendarEvent(
            title: "Sample Event",
            description: "This is a sample event description",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            location: "Sample Location",
            createdBy: "John Doe",
            createdByUserId: "user123"
        ),
        calendarService: CalendarService()
    )
}
