import SwiftUI

struct OrganizationRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    @State private var organizationName = ""
    @State private var organizationType = OrganizationType.business
    @State private var description = ""
    @State private var website = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var contactPersonName = ""
    @State private var contactPersonTitle = ""
    @State private var contactPersonPhone = ""
    @State private var contactPersonEmail = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var verificationDocuments: [String] = []
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Enhanced Header Section
                    VStack(spacing: 20) {
                        // Professional logo and branding
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue.opacity(0.1), .blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            Text("Organization Verification")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Complete the form below to request verification. We'll review your submission within 2-3 business days.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .lineLimit(nil)
                        }
                    }
                    .padding(.bottom, 40)
                    
                    // Form Content with enhanced styling
                    VStack(spacing: 32) {
                        // Organization Information
                        EnhancedFormSection(
                            title: "Organization Details",
                            subtitle: "Tell us about your organization and location",
                            icon: "building.2",
                            iconColor: .blue,
                            content: {
                                VStack(spacing: 24) {
                                    CustomTextField(
                                        title: "Organization Name",
                                        placeholder: "Enter your organization name",
                                        text: $organizationName,
                                        icon: "building.2.fill",
                                        isRequired: true
                                    )
                                    
                                    CustomPickerField(
                                        title: "Organization Type",
                                        selection: $organizationType,
                                        icon: "tag.fill",
                                        isRequired: true
                                    )
                                    
                                    CustomTextField(
                                        title: "Description",
                                        placeholder: "Describe your organization's purpose and activities (optional)",
                                        text: $description,
                                        icon: "text.quote",
                                        isMultiline: true,
                                        isRequired: false
                                    )
                                    
                                    CustomTextField(
                                        title: "Website",
                                        placeholder: "https://yourwebsite.com (optional)",
                                        text: $website,
                                        icon: "globe",
                                        keyboardType: .URL
                                    )
                                    
                                    CustomTextField(
                                        title: "Main Office Phone",
                                        placeholder: "(555) 123-4567 (optional)",
                                        text: $phone,
                                        icon: "phone.fill",
                                        keyboardType: .phonePad
                                    )
                                    
                                    // Location fields moved here
                                    CustomTextField(
                                        title: "Street Address",
                                        placeholder: "Enter your street address",
                                        text: $address,
                                        icon: "house.fill",
                                        isRequired: true
                                    )
                                    
                                    HStack(spacing: 16) {
                                        CustomTextField(
                                            title: "City",
                                            placeholder: "City",
                                            text: $city,
                                            icon: "building.fill",
                                            isRequired: true
                                        )
                                        
                                        CustomTextField(
                                            title: "State",
                                            placeholder: "State",
                                            text: $state,
                                            icon: "building.2.fill",
                                            isRequired: true
                                        )
                                    }
                                    
                                    CustomTextField(
                                        title: "ZIP Code",
                                        placeholder: "12345",
                                        text: $zipCode,
                                        icon: "mappin.circle.fill",
                                        isRequired: true
                                    )
                                }
                            }
                        )
                        
                        // Contact Information
                        EnhancedFormSection(
                            title: "Contact Information",
                            subtitle: "Primary contact for verification",
                            icon: "person.crop.circle",
                            iconColor: .green,
                            content: {
                                VStack(spacing: 24) {
                                    CustomTextField(
                                        title: "Contact Person Name",
                                        placeholder: "Full name of primary contact",
                                        text: $contactPersonName,
                                        icon: "person.fill",
                                        isRequired: true
                                    )
                                    
                                    CustomTextField(
                                        title: "Contact Person Title",
                                        placeholder: "e.g., Manager, Director, Owner",
                                        text: $contactPersonTitle,
                                        icon: "briefcase.fill",
                                        isRequired: true
                                    )
                                    
                                    CustomTextField(
                                        title: "Contact Phone",
                                        placeholder: "(555) 123-4567",
                                        text: $contactPersonPhone,
                                        icon: "phone.fill",
                                        keyboardType: .phonePad,
                                        isRequired: true
                                    )
                                    
                                    CustomTextField(
                                        title: "Contact Email",
                                        placeholder: "contact@organization.com",
                                        text: $contactPersonEmail,
                                        icon: "envelope.fill",
                                        keyboardType: .emailAddress,
                                        isRequired: true
                                    )
                                }
                            }
                        )
                        
                        // Admin Account Setup
                        EnhancedFormSection(
                            title: "Admin Account Setup",
                            subtitle: "Create your administrator account",
                            icon: "lock.shield",
                            iconColor: .purple,
                            content: {
                                VStack(spacing: 24) {
                                    // Password field with show/hide toggle
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Admin Password")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            Text("*")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                        
                                        HStack(spacing: 12) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 20)
                                            
                                            if showPassword {
                                                TextField("Create a secure password", text: $password)
                                                    .textFieldStyle(PlainTextFieldStyle())
                                            } else {
                                                SecureField("Create a secure password", text: $password)
                                            }
                                            
                                            Button(action: { showPassword.toggle() }) {
                                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                                    .foregroundColor(.secondary)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        
                                        // Password requirements
                                        PasswordRequirementsView(password: password)
                                    }
                                    
                                    // Confirm password field
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Confirm Password")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            Text("*")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                        
                                        HStack(spacing: 12) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 20)
                                            
                                            if showConfirmPassword {
                                                TextField("Confirm your password", text: $confirmPassword)
                                                    .textFieldStyle(PlainTextFieldStyle())
                                            } else {
                                                SecureField("Confirm your password", text: $confirmPassword)
                                            }
                                            
                                            Button(action: { showConfirmPassword.toggle() }) {
                                                Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                                    .foregroundColor(.secondary)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        )
                        

                        

                        
                        // Enhanced Submit Button
                        VStack(spacing: 20) {
                            Button(action: submitRequest) {
                                HStack(spacing: 12) {
                                    if isSubmitting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 18, weight: .medium))
                                    }
                                    
                                    Text(isSubmitting ? "Submitting Request..." : "Submit Verification Request")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isSubmitting || !isFormValid)
                            
                            VStack(spacing: 8) {
                                Text("We'll review your request within 2-3 business days")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("You'll receive email updates throughout the process")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Request Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !organizationName.isEmpty &&
        !contactPersonName.isEmpty &&
        !contactPersonPhone.isEmpty &&
        !contactPersonEmail.isEmpty &&
        !password.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword &&
        !address.isEmpty &&
        !city.isEmpty &&
        !state.isEmpty &&
        !zipCode.isEmpty &&
        contactPersonEmail.contains("@")
    }
    
    private func submitRequest() {
        guard isFormValid else { return }
        
        isSubmitting = true
        
        // Create the organization request
        let organizationRequest = OrganizationRequest(
            name: organizationName,
            type: organizationType,
            description: description,
            website: website.isEmpty ? nil : website,
            phone: phone.isEmpty ? nil : phone,
            email: contactPersonEmail, // Use contact person's email for organization email
            address: address,
            city: city,
            state: state,
            zipCode: zipCode,
            contactPersonName: contactPersonName,
            contactPersonTitle: contactPersonTitle,
            contactPersonPhone: contactPersonPhone,
            contactPersonEmail: contactPersonEmail,
            adminPassword: password,
            status: .pending
        )
        
        Task {
            print("📝 Submitting organization request: \(organizationRequest.name)")
            do {
                let result = try await apiService.submitOrganizationRequest(organizationRequest)
                print("✅ Organization request submitted successfully: \(result.id)")
                
                await MainActor.run {
                    print("🎉 Showing success alert to user")
                    alertTitle = "Success"
                    alertMessage = "Your verification request has been submitted successfully! We'll review it and contact you within 2-3 business days. Check your email for updates."
                    showingAlert = true
                    isSubmitting = false
                }
            } catch {
                print("❌ Failed to submit organization request: \(error)")
                
                await MainActor.run {
                    print("⚠️ Showing error alert to user")
                    alertTitle = "Error"
                    alertMessage = "Failed to submit request: \(error.localizedDescription). Please try again or contact support if the problem persists."
                    showingAlert = true
                    isSubmitting = false
                }
            }
        }
    }
}

// MARK: - Enhanced Form Section
struct EnhancedFormSection<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, subtitle: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Section content
            content
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}



// MARK: - Password Requirements View
struct PasswordRequirementsView: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password Requirements:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                PasswordRequirementRow(
                    text: "At least 8 characters",
                    isMet: password.count >= 8,
                    icon: "checkmark.circle.fill"
                )
                PasswordRequirementRow(
                    text: "Contains uppercase letter",
                    isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil,
                    icon: "checkmark.circle.fill"
                )
                PasswordRequirementRow(
                    text: "Contains lowercase letter",
                    isMet: password.range(of: "[a-z]", options: .regularExpression) != nil,
                    icon: "checkmark.circle.fill"
                )
                PasswordRequirementRow(
                    text: "Contains number",
                    isMet: password.range(of: "[0-9]", options: .regularExpression) != nil,
                    icon: "checkmark.circle.fill"
                )
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Password Requirement Row
// Using existing PasswordRequirementRow from ChangePasswordView.swift

#Preview {
    OrganizationRequestView()
        .environmentObject(APIService())
        .environmentObject(LocationManager())
} 
