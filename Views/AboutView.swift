import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // App Icon and Name
                    VStack(spacing: 20) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("LocalAlert")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // App Description
                    VStack(spacing: 16) {
                        Text("About LocalAlert")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("LocalAlert is your trusted companion for staying informed about incidents and emergencies in your community. We provide real-time alerts, safety information, and community updates to help keep you and your loved ones safe.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Features
                    VStack(spacing: 16) {
                        Text("Key Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            FeatureRow(
                                icon: "exclamationmark.triangle.fill",
                                iconColor: .red,
                                title: "Real-time Alerts",
                                description: "Get instant notifications about incidents in your area"
                            )
                            
                            FeatureRow(
                                icon: "location.circle.fill",
                                iconColor: .blue,
                                title: "Location-based",
                                description: "Receive alerts relevant to your home, work, and school"
                            )
                            
                            FeatureRow(
                                icon: "bell.badge.fill",
                                iconColor: .orange,
                                title: "Customizable Notifications",
                                description: "Choose which types of alerts you want to receive"
                            )
                            
                            FeatureRow(
                                icon: "building.2.fill",
                                iconColor: .green,
                                title: "Organization Updates",
                                description: "Stay connected with local organizations and community groups"
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Development Info
                    VStack(spacing: 16) {
                        Text("Development")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            InfoRow(
                                label: "Developer",
                                value: "Jed Crisp"
                            )
                            
                            InfoRow(
                                label: "Company",
                                value: "OneTrack Consulting"
                            )
                            
                            InfoRow(
                                label: "Contact",
                                value: "jed@chimeo.app"
                            )
                            
                            InfoRow(
                                label: "Website",
                                value: "https://www.chimeo.app"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Copyright
                    VStack(spacing: 8) {
                        Text("© 2024 OneTrack Consulting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("All rights reserved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// InfoRow is defined in ContentView.swift

#Preview {
    AboutView()
}
