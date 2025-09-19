import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User")
                                .font(.headline)
                            Text("user@localalert.com")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Alert Preferences
                Section("Alert Preferences") {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.blue)
                        Text("Push Notifications")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.green)
                        Text("Location Access")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Organizations
                Section("Organizations") {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.blue)
                        Text("Followed Organizations")
                        Spacer()
                        Text("0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        Text("Discover Organizations")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                
                // App Settings
                Section("App Settings") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("About LocalAlert")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Account Actions
                Section("Account Actions") {
                    Button("Sign Out") {
                        // Handle sign out
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Settings")
        }
    }
} 