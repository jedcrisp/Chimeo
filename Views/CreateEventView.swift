import SwiftUI

struct CreateEventView: View {
    let calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var isAllDay = false
    @State private var location = ""
    @State private var selectedColor = CalendarEventColor.blue
    @State private var isRecurring = false
    @State private var recurrenceFrequency = RecurrenceFrequency.weekly
    @State private var recurrenceInterval = 1
    @State private var recurrenceEndDate = Date().addingTimeInterval(86400 * 30) // 30 days later
    @State private var recurrenceOccurrences = 5
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
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
            .navigationTitle("New Event")
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
                let currentUser = try await getCurrentUser()
                
                let recurrencePattern: RecurrencePattern? = isRecurring ? RecurrencePattern(
                    frequency: recurrenceFrequency,
                    interval: recurrenceInterval,
                    endDate: recurrenceEndDate
                ) : nil
                
                let event = CalendarEvent(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    startDate: startDate,
                    endDate: isAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate : endDate,
                    isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location,
                    createdBy: currentUser.name ?? "Unknown",
                    createdByUserId: currentUser.id,
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

#Preview {
    CreateEventView(calendarService: CalendarService())
}
