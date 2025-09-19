import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject var apiService: APIService
    @State private var pushNotifications = true
    @State private var emailNotifications = true
    @State private var quietHoursEnabled = false
    @State private var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Notification Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Customize how and when you receive alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            // Notification Channels
            VStack(spacing: 16) {
                HStack {
                    Text("Notification Channels")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    NotificationToggleRow(
                        title: "Push Notifications",
                        subtitle: "Receive alerts on your device",
                        icon: "bell.fill",
                        iconColor: .blue,
                        isOn: $pushNotifications
                    )
                    
                    NotificationToggleRow(
                        title: "Email Notifications",
                        subtitle: "Get alerts in your inbox",
                        icon: "envelope.fill",
                        iconColor: .green,
                        isOn: $emailNotifications
                    )
                }
            }
            
            // Quiet Hours
            VStack(spacing: 16) {
                HStack {
                    Text("Quiet Hours")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Toggle("", isOn: $quietHoursEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                }
                .padding(.horizontal, 20)
                
                if quietHoursEnabled {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                DatePicker("", selection: $quietHoursStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                DatePicker("", selection: $quietHoursEnd, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Quiet Hours")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("During quiet hours, you'll only receive critical alerts that override this setting.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
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
            
            // Description
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How notifications work")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("LocalAlert will send you notifications based on your preferences. Critical alerts will always be delivered, even during quiet hours.")
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
                            colors: [.purple, .purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        // Load current settings from user preferences
        if let user = apiService.currentUser {
            pushNotifications = user.preferences.pushNotifications
            quietHoursEnabled = user.preferences.quietHoursEnabled
            quietHoursStart = user.preferences.quietHoursStart ?? Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
            quietHoursEnd = user.preferences.quietHoursEnd ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        }
    }
    
    private func saveSettings() {
        // Save settings to user preferences
        print("✅ Notification preferences saved:")
        print("   Push notifications: \(pushNotifications)")
        print("   Email notifications: \(emailNotifications)")
        print("   Quiet hours enabled: \(quietHoursEnabled)")
        print("   Quiet hours: \(quietHoursStart) to \(quietHoursEnd)")
        
        // Update the user's preferences
        if var user = apiService.currentUser {
            user.preferences.pushNotifications = pushNotifications
            user.preferences.quietHoursEnabled = quietHoursEnabled
            user.preferences.quietHoursStart = quietHoursStart
            user.preferences.quietHoursEnd = quietHoursEnd
            // In production, you'd update this in the backend
        }
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: iconColor))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    NavigationView {
        NotificationPreferencesView()
            .environmentObject(APIService())
    }
}
