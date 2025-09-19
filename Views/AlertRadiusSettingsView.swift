import SwiftUI

struct AlertRadiusSettingsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var alertRadius: Double = 5.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Alert Radius")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Set how far from your locations you want to receive alerts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 20)
            
            // Radius Display
            VStack(spacing: 8) {
                Text("\(String(format: "%.1f", alertRadius)) miles")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                
                Text("from your locations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            
            // Slider
            VStack(spacing: 16) {
                HStack {
                    Text("1 mile")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("25 miles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $alertRadius, in: 1...25, step: 0.5)
                    .accentColor(.blue)
            }
            .padding(.horizontal, 20)
            
            // Description
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What this means:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("You'll receive alerts for incidents within \(String(format: "%.1f", alertRadius)) miles of your home, work, and school locations.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("A larger radius means more alerts but may include incidents that are less relevant to you.")
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
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alert Radius")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        // Load current settings from user preferences
        if let user = apiService.currentUser {
            alertRadius = user.alertRadius
        }
    }
    
    private func saveSettings() {
        // Save settings to user preferences
        // In production, this would update the backend
        print("✅ Alert radius saved: \(alertRadius) miles")
        
        // Update the user's alert radius
        if var user = apiService.currentUser {
            user.alertRadius = alertRadius
            // In production, you'd update this in the backend
        }
    }
}

#Preview {
    NavigationView {
        AlertRadiusSettingsView()
            .environmentObject(APIService())
    }
}
