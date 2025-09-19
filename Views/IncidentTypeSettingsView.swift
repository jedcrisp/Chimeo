import SwiftUI

struct IncidentTypeSettingsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var selectedTypes: [IncidentType] = IncidentType.allCases
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            incidentTypesList
            descriptionSection
            Spacer()
            saveButton
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Incident Types")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Incident Types")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Choose which types of incidents you want to be notified about")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    private var incidentTypesList: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Selected Types")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(selectedTypes.count) of \(IncidentType.allCases.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                ForEach(IncidentType.allCases, id: \.self) { type in
                    incidentTypeRow(type: type)
                    
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
    
    private func incidentTypeRow(type: IncidentType) -> some View {
        HStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.system(size: 16, weight: .medium))
            }
            
            Spacer()
            
            if selectedTypes.contains(type) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
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
            if selectedTypes.contains(type) {
                selectedTypes.removeAll { $0 == type }
            } else {
                selectedTypes.append(type)
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("How this works")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("You'll only receive notifications for the incident types you select. Choose all types to stay fully informed, or select only the ones most relevant to you.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
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
            selectedTypes = user.preferences.incidentTypes
        }
    }
    
    private func saveSettings() {
        // Save settings to user preferences
        print("✅ Incident types saved: \(selectedTypes.map { $0.displayName })")
        
        // Update the user's preferences
        if var user = apiService.currentUser {
            user.preferences.incidentTypes = selectedTypes
            // In production, you'd update this in the backend
        }
    }
}

#Preview {
    NavigationView {
        IncidentTypeSettingsView()
            .environmentObject(APIService())
    }
}
