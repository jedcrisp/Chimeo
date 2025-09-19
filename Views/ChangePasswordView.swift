import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChanging = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Change Password")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Update your account password")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Enter your current password", text: $currentPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Enter your new password", text: $newPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            SecureField("Confirm your new password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Password Requirements
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            
                            Text("Password Requirements")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            PasswordRequirementRow(
                                text: "At least 8 characters long",
                                isMet: newPassword.count >= 8
                            )
                            
                            PasswordRequirementRow(
                                text: "Contains at least one uppercase letter",
                                isMet: newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
                            )
                            
                            PasswordRequirementRow(
                                text: "Contains at least one lowercase letter",
                                isMet: newPassword.range(of: "[a-z]", options: .regularExpression) != nil
                            )
                            
                            PasswordRequirementRow(
                                text: "Contains at least one number",
                                isMet: newPassword.range(of: "[0-9]", options: .regularExpression) != nil
                            )
                            
                            PasswordRequirementRow(
                                text: "Contains at least one special character",
                                isMet: newPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
                    .padding(.horizontal, 20)
                    
                    // Change Password Button
                    Button(action: changePassword) {
                        HStack {
                            if isChanging {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.shield")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            Text(isChanging ? "Changing..." : "Change Password")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        .disabled(isChanging || !isFormValid)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8 &&
        newPassword.range(of: "[A-Z]", options: .regularExpression) != nil &&
        newPassword.range(of: "[a-z]", options: .regularExpression) != nil &&
        newPassword.range(of: "[0-9]", options: .regularExpression) != nil &&
        newPassword.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
    }
    
    private func changePassword() {
        guard !currentPassword.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please enter your current password"
            showingAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            alertTitle = "Error"
            alertMessage = "New passwords do not match"
            showingAlert = true
            return
        }
        
        guard isFormValid else {
            alertTitle = "Error"
            alertMessage = "Please ensure your new password meets all requirements"
            showingAlert = true
            return
        }
        
        isChanging = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isChanging = false
            alertTitle = "Success"
            alertMessage = "Your password has been changed successfully"
            showingAlert = true
            
            // Clear form
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        }
    }
}

// MARK: - Password Requirement Row
struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool
    let icon: String?
    
    init(text: String, isMet: Bool, icon: String? = nil) {
        self.text = text
        self.isMet = isMet
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(isMet ? .green : .secondary)
                    .font(.caption)
            } else {
                Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isMet ? .green : .secondary)
                    .font(.caption)
            }
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(APIService())
}
