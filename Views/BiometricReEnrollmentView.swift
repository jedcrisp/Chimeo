import SwiftUI
import LocalAuthentication

struct BiometricReEnrollmentView: View {
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isReEnrolling = false
    @State private var reEnrollmentSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: biometricAuthManager.biometricIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    let headerText = biometricAuthManager.shouldReEnroll ? 
                        "Re-enroll \(biometricAuthManager.biometricTypeName)" : 
                        "Set up \(biometricAuthManager.biometricTypeName)"
                    
                    Text(headerText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    let descriptionText = biometricAuthManager.shouldReEnroll ?
                        "After successful login, you can re-enroll \(biometricAuthManager.biometricTypeName) for faster access to your account." :
                        "Set up \(biometricAuthManager.biometricTypeName) for faster access to your account."
                    
                    Text(descriptionText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Status Information
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Current Status:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: biometricAuthManager.shouldReEnroll ? "exclamationmark.triangle" : "checkmark.circle")
                            .foregroundColor(biometricAuthManager.shouldReEnroll ? .orange : .green)
                        Text(biometricAuthManager.statusMessage)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.leading, 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Action Buttons
                VStack(spacing: 16) {
                    if biometricAuthManager.shouldReEnroll || biometricAuthManager.shouldOfferBiometricSetup {
                        Button(action: {
                            Task {
                                await reEnrollBiometrics()
                            }
                        }) {
                            HStack {
                                if isReEnrolling {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: biometricAuthManager.biometricIcon)
                                        .font(.system(size: 18, weight: .medium))
                                }
                                
                                let buttonText = biometricAuthManager.shouldReEnroll ? 
                                    "Re-enroll \(biometricAuthManager.biometricTypeName)" : 
                                    "Set up \(biometricAuthManager.biometricTypeName)"
                                
                                Text(isReEnrolling ? "Setting up..." : buttonText)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isReEnrolling)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Skip for Now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Footer
                Text("You can always re-enroll \(biometricAuthManager.biometricTypeName) later in Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            .navigationTitle("Biometric Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isReEnrolling)
                }
            }
        }
        .alert("Re-enrollment Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check if biometric setup or re-enrollment is actually needed
            if !biometricAuthManager.shouldReEnroll && !biometricAuthManager.shouldOfferBiometricSetup {
                // Biometrics are already working, dismiss this view
                dismiss()
            }
        }
    }
    
    private func reEnrollBiometrics() async {
        isReEnrolling = true
        
        do {
            let success = await biometricAuthManager.reEnrollAfterCredentialLogin()
            
            await MainActor.run {
                isReEnrolling = false
                
                if success {
                    reEnrollmentSuccess = true
                    // Show success message briefly then dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                } else {
                    // Show error from BiometricAuthManager
                    if let error = biometricAuthManager.lastAuthError {
                        errorMessage = error
                        showingError = true
                    }
                }
            }
        }
    }
}

#Preview {
    BiometricReEnrollmentView()
        .environmentObject(BiometricAuthManager())
}
