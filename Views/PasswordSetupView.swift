import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PasswordSetupView: View {
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSettingPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    let email: String
    let organizationName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .padding(.top, 40)
                    
                    Text("Welcome to \(organizationName)!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Your organization has been approved. Please set up your password to access your admin dashboard.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
                
                // Password Form
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(email)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    
                    // Password Requirements
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password Requirements")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirementRow(
                                text: "At least 8 characters",
                                isMet: password.count >= 8
                            )
                            PasswordRequirementRow(
                                text: "Contains a number",
                                isMet: password.rangeOfCharacter(from: .decimalDigits) != nil
                            )
                            PasswordRequirementRow(
                                text: "Contains an uppercase letter",
                                isMet: password.rangeOfCharacter(from: .uppercaseLetters) != nil
                            )
                            PasswordRequirementRow(
                                text: "Contains a lowercase letter",
                                isMet: password.rangeOfCharacter(from: .lowercaseLetters) != nil
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: setupPassword) {
                        HStack {
                            if isSettingPassword {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Set Password & Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isPasswordValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isPasswordValid || isSettingPassword)
                    
                    Button("I'll do this later") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .alert(isSuccess ? "Success!" : "Error", isPresented: $showAlert) {
            Button("OK") {
                if isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8 &&
        password.rangeOfCharacter(from: .decimalDigits) != nil &&
        password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
        password.rangeOfCharacter(from: .lowercaseLetters) != nil &&
        password == confirmPassword
    }
    
    private func setupPassword() {
        guard isPasswordValid else { return }
        
        isSettingPassword = true
        
        Task {
            do {
                // Create Firebase Auth account
                let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
                
                // Update user document to mark password as set
                let db = Firestore.firestore()
                try await db.collection("users").document(authResult.user.uid).updateData([
                    "needsPasswordSetup": false,
                    "firebaseAuthId": authResult.user.uid,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
                
                await MainActor.run {
                    isSettingPassword = false
                    isSuccess = true
                    alertMessage = "Password set successfully! You can now sign in with your email and password."
                    showAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isSettingPassword = false
                    isSuccess = false
                    alertMessage = "Failed to set password: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    PasswordSetupView(
        email: "admin@example.com",
        organizationName: "Example Organization"
    )
}
