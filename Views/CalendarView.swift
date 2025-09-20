//
//  CalendarView.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct CalendarView: View {
    @StateObject private var calendarService = CalendarService()
    @State private var selectedDate = Date()
    @State private var currentViewMode: CalendarViewMode = .month
    @State private var showingCreateEvent = false
    @State private var showingCreateAlert = false
    @State private var showingEventDetail: CalendarEvent?
    @State private var showingAlertDetail: ScheduledAlert?
    @State private var showingFilter = false
    @State private var filter = CalendarFilter()
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init() {
        dateFormatter.dateFormat = "MMMM yyyy"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with view mode picker
                headerView
                
                // Calendar content based on view mode
                calendarContentView
                
                // Bottom toolbar
                bottomToolbar
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { showingFilter = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(filter.isFiltered ? .blue : .primary)
                        }
                        
                        Menu {
                            Button(action: { showingCreateEvent = true }) {
                                Label("New Event", systemImage: "calendar.badge.plus")
                            }
                            
                            Button(action: { showingCreateAlert = true }) {
                                Label("Schedule Alert", systemImage: "bell.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    try? await calendarService.fetchCalendarData()
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView(calendarService: calendarService)
            }
            .sheet(isPresented: $showingCreateAlert) {
                CreateScheduledAlertView(calendarService: calendarService)
            }
            .sheet(isPresented: $showingFilter) {
                CalendarFilterView(filter: $filter)
            }
            .sheet(item: $showingEventDetail) { event in
                EventDetailView(event: event, calendarService: calendarService)
            }
            .sheet(item: $showingAlertDetail) { alert in
                ScheduledAlertDetailView(alert: alert, calendarService: calendarService)
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Month/Year title
            HStack {
                Button(action: previousPeriod) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: nextPeriod) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // View mode picker
            Picker("View Mode", selection: $currentViewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Calendar Content View
    private var calendarContentView: some View {
        Group {
            switch currentViewMode {
            case .month:
                MonthCalendarView(
                    selectedDate: $selectedDate,
                    calendarService: calendarService,
                    filter: filter,
                    onEventTap: { event in
                        showingEventDetail = event
                    },
                    onAlertTap: { alert in
                        showingAlertDetail = alert
                    }
                )
            case .week:
                WeekCalendarView(
                    selectedDate: $selectedDate,
                    calendarService: calendarService,
                    filter: filter,
                    onEventTap: { event in
                        showingEventDetail = event
                    },
                    onAlertTap: { alert in
                        showingAlertDetail = alert
                    }
                )
            case .day:
                DayCalendarView(
                    selectedDate: $selectedDate,
                    calendarService: calendarService,
                    filter: filter,
                    onEventTap: { event in
                        showingEventDetail = event
                    },
                    onAlertTap: { alert in
                        showingAlertDetail = alert
                    }
                )
            case .agenda:
                AgendaView(
                    selectedDate: $selectedDate,
                    calendarService: calendarService,
                    filter: filter,
                    onEventTap: { event in
                        showingEventDetail = event
                    },
                    onAlertTap: { alert in
                        showingAlertDetail = alert
                    }
                )
            }
        }
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack {
            Button(action: { selectedDate = Date() }) {
                HStack {
                    Image(systemName: "calendar")
                    Text("Today")
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            if calendarService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    private func previousPeriod() {
        switch currentViewMode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .agenda:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func nextPeriod() {
        switch currentViewMode {
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .agenda:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        }
    }
}

// MARK: - Month Calendar View
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "d"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                ForEach(calendarDays, id: \.self) { date in
                    MonthDayView(
                        date: date,
                        selectedDate: $selectedDate,
                        calendarService: calendarService,
                        filter: filter,
                        onEventTap: onEventTap,
                        onAlertTap: onAlertTap
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        
        let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)
        let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1)
        
        guard let firstWeek = monthFirstWeek, let lastWeek = monthLastWeek else { return [] }
        
        var days: [Date] = []
        var currentDate = firstWeek.start
        
        while currentDate < lastWeek.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
}

// MARK: - Month Day View
struct MonthDayView: View {
    let date: Date
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(date: Date, selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self.date = date
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "d"
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var dayEvents: [CalendarEvent] {
        calendarService.getEventsForDate(date).filter { event in
            filter.showEvents
        }
    }
    
    private var dayAlerts: [ScheduledAlert] {
        calendarService.getScheduledAlertsForDate(date).filter { alert in
            filter.showAlerts &&
            filter.selectedTypes.contains(alert.type) &&
            filter.selectedSeverities.contains(alert.severity)
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Date number
            Text(dateFormatter.string(from: date))
                .font(.system(size: 16, weight: isToday ? .bold : .medium))
                .foregroundColor(isCurrentMonth ? (isToday ? .white : .primary) : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isToday ? Color.blue : (isSelected ? Color.blue.opacity(0.2) : Color.clear))
                )
            
            // Event indicators
            if !dayEvents.isEmpty || !dayAlerts.isEmpty {
                HStack(spacing: 2) {
                    ForEach(dayEvents.prefix(3), id: \.id) { event in
                        Circle()
                            .fill(Color(event.color))
                            .frame(width: 6, height: 6)
                    }
                    
                    ForEach(dayAlerts.prefix(3 - dayEvents.count), id: \.id) { alert in
                        Circle()
                            .fill(alert.severity.color)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .frame(height: 60)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
        .onTapGesture(count: 2) {
            // Double tap to show day view
            // This could be handled by the parent view
        }
    }
}

// MARK: - Week Calendar View
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "E d"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    WeekDayView(
                        date: date,
                        selectedDate: $selectedDate,
                        calendarService: calendarService,
                        filter: filter,
                        onEventTap: onEventTap,
                        onAlertTap: onAlertTap
                    )
                }
            }
        }
    }
    
    private var weekDays: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        
        var days: [Date] = []
        var currentDate = weekInterval.start
        
        while currentDate < weekInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
}

// MARK: - Week Day View
struct WeekDayView: View {
    let date: Date
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(date: Date, selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self.date = date
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "E d"
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var dayEvents: [CalendarEvent] {
        calendarService.getEventsForDate(date).filter { event in
            filter.showEvents
        }
    }
    
    private var dayAlerts: [ScheduledAlert] {
        calendarService.getScheduledAlertsForDate(date).filter { alert in
            filter.showAlerts &&
            filter.selectedTypes.contains(alert.type) &&
            filter.selectedSeverities.contains(alert.severity)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.headline)
                    .foregroundColor(isToday ? .blue : .primary)
                
                Spacer()
                
                if isToday {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            
            // Events and alerts
            VStack(spacing: 4) {
                ForEach(dayEvents, id: \.id) { event in
                    EventRowView(event: event) {
                        onEventTap(event)
                    }
                }
                
                ForEach(dayAlerts, id: \.id) { alert in
                    AlertRowView(alert: alert) {
                        onAlertTap(alert)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .padding(.horizontal)
        .onTapGesture {
            selectedDate = date
        }
    }
}

// MARK: - Day Calendar View
struct DayCalendarView: View {
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Date header
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                // Events and alerts for the day
                VStack(spacing: 8) {
                    ForEach(dayEvents, id: \.id) { event in
                        EventRowView(event: event) {
                            onEventTap(event)
                        }
                    }
                    
                    ForEach(dayAlerts, id: \.id) { alert in
                        AlertRowView(alert: alert) {
                            onAlertTap(alert)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var dayEvents: [CalendarEvent] {
        calendarService.getEventsForDate(selectedDate).filter { event in
            filter.showEvents
        }
    }
    
    private var dayAlerts: [ScheduledAlert] {
        calendarService.getScheduledAlertsForDate(selectedDate).filter { alert in
            filter.showAlerts &&
            filter.selectedTypes.contains(alert.type) &&
            filter.selectedSeverities.contains(alert.severity)
        }
    }
}

// MARK: - Agenda View
struct AgendaView: View {
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "EEEE, MMMM d"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(agendaDays, id: \.self) { date in
                    AgendaDayView(
                        date: date,
                        selectedDate: $selectedDate,
                        calendarService: calendarService,
                        filter: filter,
                        onEventTap: onEventTap,
                        onAlertTap: onAlertTap
                    )
                }
            }
        }
    }
    
    private var agendaDays: [Date] {
        let startDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
        let endDate = calendar.date(byAdding: .day, value: 30, to: selectedDate) ?? selectedDate
        
        var days: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
}

// MARK: - Agenda Day View
struct AgendaDayView: View {
    let date: Date
    @Binding var selectedDate: Date
    let calendarService: CalendarService
    let filter: CalendarFilter
    let onEventTap: (CalendarEvent) -> Void
    let onAlertTap: (ScheduledAlert) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(date: Date, selectedDate: Binding<Date>, calendarService: CalendarService, filter: CalendarFilter, onEventTap: @escaping (CalendarEvent) -> Void, onAlertTap: @escaping (ScheduledAlert) -> Void) {
        self.date = date
        self._selectedDate = selectedDate
        self.calendarService = calendarService
        self.filter = filter
        self.onEventTap = onEventTap
        self.onAlertTap = onAlertTap
        dateFormatter.dateFormat = "EEEE, MMMM d"
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var dayEvents: [CalendarEvent] {
        calendarService.getEventsForDate(date).filter { event in
            filter.showEvents
        }
    }
    
    private var dayAlerts: [ScheduledAlert] {
        calendarService.getScheduledAlertsForDate(date).filter { alert in
            filter.showAlerts &&
            filter.selectedTypes.contains(alert.type) &&
            filter.selectedSeverities.contains(alert.severity)
        }
    }
    
    private var hasContent: Bool {
        !dayEvents.isEmpty || !dayAlerts.isEmpty
    }
    
    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 8) {
                // Date header
                HStack {
                    Text(dateFormatter.string(from: date))
                        .font(.headline)
                        .foregroundColor(isToday ? .blue : .primary)
                    
                    Spacer()
                    
                    if isToday {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal)
                
                // Events and alerts
                VStack(spacing: 4) {
                    ForEach(dayEvents, id: \.id) { event in
                        EventRowView(event: event) {
                            onEventTap(event)
                        }
                    }
                    
                    ForEach(dayAlerts, id: \.id) { alert in
                        AlertRowView(alert: alert) {
                            onAlertTap(alert)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Event Row View
struct EventRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    private let timeFormatter = DateFormatter()
    
    init(event: CalendarEvent, onTap: @escaping () -> Void) {
        self.event = event
        self.onTap = onTap
        timeFormatter.dateFormat = "h:mm a"
    }
    
    var body: some View {
        HStack {
            // Color indicator
            Circle()
                .fill(Color(event.color))
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let description = event.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if !event.isAllDay {
                        Text(timeFormatter.string(from: event.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("All Day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        Text("• \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Alert Row View
struct AlertRowView: View {
    let alert: ScheduledAlert
    let onTap: () -> Void
    
    private let timeFormatter = DateFormatter()
    
    init(alert: ScheduledAlert, onTap: @escaping () -> Void) {
        self.alert = alert
        self.onTap = onTap
        timeFormatter.dateFormat = "h:mm a"
    }
    
    var body: some View {
        HStack {
            // Severity indicator
            Circle()
                .fill(alert.severity.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(alert.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(timeFormatter.string(from: alert.scheduledDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• \(alert.type.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• \(alert.severity.displayName)")
                        .font(.caption)
                        .foregroundColor(alert.severity.color)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    CalendarView()
}
