import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Last updated: January 2024")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Introduction
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Introduction")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("LocalAlert (\"we,\" \"our,\" or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and related services.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Information We Collect
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Information We Collect")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Personal Information:")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text("• Name and contact information\n• Location data (with your consent)\n• Device information\n• Usage analytics")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Data:")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text("We collect location information to provide you with relevant alerts and notifications. This data is used solely for the purpose of delivering location-based services and is not shared with third parties.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // How We Use Your Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How We Use Your Information")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("We use the information we collect to:\n\n• Provide and maintain our services\n• Send you relevant alerts and notifications\n• Improve our application and services\n• Respond to your requests and support needs\n• Ensure the security and integrity of our platform")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Information Sharing
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Information Sharing")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("We do not sell, trade, or otherwise transfer your personal information to third parties. We may share information only in the following circumstances:\n\n• With your explicit consent\n• To comply with legal obligations\n• To protect our rights and safety\n• In emergency situations where public safety is at risk")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Data Security
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Security")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Your Rights
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Rights")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You have the right to:\n\n• Access your personal information\n• Correct inaccurate information\n• Request deletion of your data\n• Opt out of certain communications\n• Withdraw consent for location services")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Contact Us
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Us")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("If you have any questions about this Privacy Policy or our data practices, please contact us at:\n\nEmail: privacy@chimeo.app\n\nAddress: OneTrack Consulting\nAttn: Privacy Officer\n[Address]")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy Policy")
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

#Preview {
    PrivacyPolicyView()
}
