import SwiftUI

struct CriticalAlertsSettingsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var criticalAlertsOnly = false
    @State private var selectedCriticalTypes: Set<IncidentType> = Set([.fire, .medical, .police, .weather])
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            mainToggleSection
            if criticalAlertsOnly {
                criticalTypesSection
            }
            Spacer()
            saveButton
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Critical Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Critical Alerts")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Configure which types of alerts are considered critical")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    private var mainToggleSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Critical Alerts Only")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Only receive notifications for critical incidents")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $criticalAlertsOnly)
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
    }
    
    private var criticalTypesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Critical Incident Types")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                ForEach(IncidentType.allCases, id: \.self) { type in
                    criticalTypeRow(type: type)
                    
                    if type != IncidentType.allCases.last {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
        }
    }
    
    private func criticalTypeRow(type: IncidentType) -> some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
            
            if selectedCriticalTypes.contains(type) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedCriticalTypes.contains(type) {
                selectedCriticalTypes.remove(type)
            } else {
                selectedCriticalTypes.insert(type)
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: saveSettings) {
            Text("Save Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func loadCurrentSettings() {
        // Load current settings from user preferences
        if let user = apiService.currentUser {
            criticalAlertsOnly = user.preferences.criticalAlertsOnly
            // In production, you'd load the selected critical types
        }
    }
    
    private func saveSettings() {
        // Save settings to user preferences
        print("✅ Critical alerts settings saved: \(criticalAlertsOnly)")
        
        // Update the user's preferences
        if var user = apiService.currentUser {
            user.preferences.criticalAlertsOnly = criticalAlertsOnly
            // In production, you'd update this in the backend
        }
    }
}

#Preview {
    NavigationView {
        CriticalAlertsSettingsView()
            .environmentObject(APIService())
    }
}
