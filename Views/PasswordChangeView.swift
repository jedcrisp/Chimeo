import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PasswordChangeView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var validationTimer: Timer?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                        .padding(.top, 40)
                    
                    Text("Password Change Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Your organization has been approved! For security reasons, you must change your temporary password before accessing your admin dashboard.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
                
                // Password Form
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        SecureField("Current password", text: $currentPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: newPassword) { _, newValue in
                                // Add minimal validation to prevent excessive updates
                                if newValue.count > 50 {
                                    newPassword = String(newValue.prefix(50))
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm New Password")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: confirmPassword) { _, newValue in
                                // Add minimal validation to prevent excessive updates
                                if newValue.count > 50 {
                                    confirmPassword = String(newValue.prefix(50))
                                }
                            }
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
                                isMet: newPassword.count >= 8
                            )
                            PasswordRequirementRow(
                                text: "Passwords match",
                                isMet: newPassword == confirmPassword && !confirmPassword.isEmpty
                            )
                            PasswordRequirementRow(
                                text: "Different from current password",
                                isMet: newPassword != currentPassword && !newPassword.isEmpty
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Button
                Button(action: changePassword) {
                    HStack {
                        if isChangingPassword {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Change Password")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isPasswordValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isPasswordValid || isChangingPassword)
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
        // Simple validation to prevent freezing
        guard !newPassword.isEmpty else { return false }
        
        let hasMinLength = newPassword.count >= 8
        let passwordsMatch = newPassword == confirmPassword
        let isDifferent = newPassword != currentPassword
        
        return hasMinLength && passwordsMatch && isDifferent
    }
    
    private func changePassword() {
        guard isPasswordValid else { return }
        
        isChangingPassword = true
        
        Task {
            do {
                print("🔐 PasswordChangeView: Starting password change process...")
                print("   Current user in service: \(apiService.currentUser?.email ?? "nil")")
                print("   Firebase Auth current user: \(Auth.auth().currentUser?.email ?? "nil")")
                
                // Change the password using Firebase Auth
                try await apiService.updatePassword(newPassword: newPassword)
                
                print("✅ Password change successful, updating Firestore...")
                
                // Update user document to mark password as changed
                let db = Firestore.firestore()
                if let currentUser = apiService.currentUser {
                    try await db.collection("users").document(currentUser.id).updateData([
                        "needsPasswordChange": false,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                    print("✅ Firestore updated successfully")
                    
                    // Update the local user object to reflect the change
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        name: currentUser.name,
                        phone: currentUser.phone,
                        homeLocation: currentUser.homeLocation,
                        workLocation: currentUser.workLocation,
                        schoolLocation: currentUser.schoolLocation,
                        alertRadius: currentUser.alertRadius,
                        preferences: currentUser.preferences,
                        createdAt: currentUser.createdAt,
                        isAdmin: currentUser.isAdmin,
                        displayName: currentUser.displayName,
                        isOrganizationAdmin: currentUser.isOrganizationAdmin,
                        organizations: currentUser.organizations,
                        updatedAt: Date(),
                        needsPasswordSetup: currentUser.needsPasswordSetup,
                        needsPasswordChange: false, // Update this flag
                        firebaseAuthId: currentUser.firebaseAuthId
                    )
                    
                    await MainActor.run {
                        apiService.currentUser = updatedUser
                    }
                    
                } else {
                    print("⚠️ No current user in service to update Firestore")
                }
                
                await MainActor.run {
                    isChangingPassword = false
                    isSuccess = true
                    alertMessage = "Password changed successfully! You will remain signed in and can continue using the app."
                    showAlert = true
                }
                
            } catch {
                print("❌ PasswordChangeView: Password change failed with error: \(error)")
                print("   Error type: \(type(of: error))")
                print("   Error description: \(error.localizedDescription)")
                
                await MainActor.run {
                    isChangingPassword = false
                    isSuccess = false
                    alertMessage = "Failed to change password: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    PasswordChangeView()
        .environmentObject(APIService())
}
