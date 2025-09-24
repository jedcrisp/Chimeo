import SwiftUI

struct CalendarFilterView: View {
    @Binding var filter: CalendarFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Content Types") {
                    Toggle("Show Events", isOn: $filter.showEvents)
                    Toggle("Show Alerts", isOn: $filter.showAlerts)
                }
                
                if filter.showAlerts {
                    Section("Alert Types") {
                        ForEach(IncidentType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.displayName)
                                Spacer()
                                if filter.selectedTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if filter.selectedTypes.contains(type) {
                                    filter.selectedTypes.remove(type)
                                } else {
                                    filter.selectedTypes.insert(type)
                                }
                            }
                        }
                    }
                    
                    Section("Alert Severities") {
                        ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                            HStack {
                                Text(severity.displayName)
                                Spacer()
                                if filter.selectedSeverities.contains(severity) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if filter.selectedSeverities.contains(severity) {
                                    filter.selectedSeverities.remove(severity)
                                } else {
                                    filter.selectedSeverities.insert(severity)
                                }
                            }
                        }
                    }
                }
                
                Section("Date Range") {
                    DatePicker("Start Date", selection: Binding(
                        get: { filter.dateRange?.start ?? Date() },
                        set: { newValue in
                            if let endDate = filter.dateRange?.end {
                                filter.dateRange = DateInterval(start: newValue, end: endDate)
                            } else {
                                filter.dateRange = DateInterval(start: newValue, end: newValue)
                            }
                        }
                    ), displayedComponents: .date)
                    
                    DatePicker("End Date", selection: Binding(
                        get: { filter.dateRange?.end ?? Date() },
                        set: { newValue in
                            if let startDate = filter.dateRange?.start {
                                filter.dateRange = DateInterval(start: startDate, end: newValue)
                            } else {
                                filter.dateRange = DateInterval(start: newValue, end: newValue)
                            }
                        }
                    ), displayedComponents: .date)
                    
                    Button("Clear Date Range") {
                        filter.dateRange = nil
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        filter = CalendarFilter()
                    }
                }
            }
        }
    }
}

#Preview {
    CalendarFilterView(filter: .constant(CalendarFilter()))
}
