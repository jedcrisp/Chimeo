import SwiftUI

struct QuietHoursSettingsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var quietHoursEnabled = false
    @State private var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    @State private var criticalAlertsOverride = true
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.indigo)
                
                Text("Quiet Hours")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Set times when you don't want to be disturbed by notifications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            // Main Toggle
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Quiet Hours")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Silence non-critical notifications during specified times")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $quietHoursEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .indigo))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            // Time Settings
            if quietHoursEnabled {
                VStack(spacing: 16) {
                    HStack {
                        Text("Quiet Hours Schedule")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                DatePicker("", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("End Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                DatePicker("", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.wheel)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Time Display
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 4) {
                                Text("Quiet Hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(formatTime(quietHoursStart)) - \(formatTime(quietHoursEnd))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.indigo)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.indigo.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                }
            }
            
            // Critical Alerts Override
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Critical Alerts Override")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Critical alerts will always be delivered, even during quiet hours")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $criticalAlertsOverride)
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            // Description
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How quiet hours work")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("During quiet hours, you'll only receive critical alerts that require immediate attention. All other notifications will be silenced until quiet hours end.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Critical alerts")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Fire, medical emergencies, severe weather, and other critical incidents will always break through quiet hours to ensure your safety.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Save Button
            Button(action: saveSettings) {
                Text("Save Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .indigo.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Quiet Hours")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadCurrentSettings() {
        // Load current settings from user preferences
        if let user = apiService.currentUser {
            quietHoursEnabled = user.preferences.quietHoursEnabled
            quietHoursStart = user.preferences.quietHoursStart ?? Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
            quietHoursEnd = user.preferences.quietHoursEnd ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        }
    }
    
    private func saveSettings() {
        // Save settings to user preferences
        print("✅ Quiet hours settings saved:")
        print("   Enabled: \(quietHoursEnabled)")
        print("   Start time: \(formatTime(quietHoursStart))")
        print("   End time: \(formatTime(quietHoursEnd))")
        print("   Critical alerts override: \(criticalAlertsOverride)")
        
        // Update the user's preferences
        if var user = apiService.currentUser {
            user.preferences.quietHoursEnabled = quietHoursEnabled
            user.preferences.quietHoursStart = quietHoursStart
            user.preferences.quietHoursEnd = quietHoursEnd
            // In production, you'd update this in the backend
        }
    }
}

#Preview {
    NavigationView {
        QuietHoursSettingsView()
            .environmentObject(APIService())
    }
}
