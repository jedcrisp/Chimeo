import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Service")
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
                        
                        Text("These Terms of Service (\"Terms\") govern your use of the LocalAlert mobile application and related services. By using our service, you agree to be bound by these Terms.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Acceptance of Terms
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Acceptance of Terms")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("By downloading, installing, or using the LocalAlert application, you acknowledge that you have read, understood, and agree to be bound by these Terms. If you do not agree to these Terms, you should not use our service.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description of Service
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Description of Service")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("LocalAlert is a community safety application that provides:\n\n• Real-time incident alerts and notifications\n• Location-based safety information\n• Community organization updates\n• Emergency response coordination\n• Public safety resources and information")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // User Responsibilities
                    VStack(alignment: .leading, spacing: 16) {
                        Text("User Responsibilities")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("As a user of LocalAlert, you agree to:\n\n• Provide accurate and truthful information\n• Use the service responsibly and lawfully\n• Respect the privacy and rights of others\n• Not misuse or abuse the platform\n• Report any suspicious or inappropriate activity\n• Follow local laws and regulations")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Privacy and Data
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy and Data")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your privacy is important to us. Our collection and use of your information is governed by our Privacy Policy, which is incorporated into these Terms by reference.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Prohibited Uses
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Prohibited Uses")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("You may not use LocalAlert to:\n\n• Violate any applicable laws or regulations\n• Harass, threaten, or harm others\n• Spread false or misleading information\n• Interfere with the service's operation\n• Attempt to gain unauthorized access\n• Use for commercial purposes without permission")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Disclaimers
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Disclaimers")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("LocalAlert is provided \"as is\" without warranties of any kind. We do not guarantee the accuracy, completeness, or timeliness of information provided through the service. Users should always verify information through official sources.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Limitation of Liability
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Limitation of Liability")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("LocalAlert and OneTrack Consulting shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the service.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Changes to Terms
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Changes to Terms")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("We reserve the right to modify these Terms at any time. We will notify users of significant changes through the application or email. Continued use of the service after changes constitutes acceptance of the new Terms.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Contact Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Information")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("If you have questions about these Terms of Service, please contact us at:\n\nEmail: legal@localalert.com\n\nAddress: OneTrack Consulting\nAttn: Legal Department\n[Address]")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Terms of Service")
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
    TermsOfServiceView()
}
