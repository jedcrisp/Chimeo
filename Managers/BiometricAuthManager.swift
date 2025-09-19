import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let biometricReEnrollmentNeeded = Notification.Name("biometricReEnrollmentNeeded")
}

class BiometricAuthManager: ObservableObject {
    @Published var biometricType: LABiometryType = .none
    @Published var isBiometricEnabled: Bool = false
    @Published var isAuthenticating: Bool = false
    
    private let context = LAContext()
    
    init() {
        checkBiometricCapability()
        loadBiometricPreference()
    }
    
    // Check what biometric authentication is available
    func checkBiometricCapability() {
        var error: NSError?
        
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                biometricType = context.biometryType
                print("✅ Biometric type detected: \(biometricType == .faceID ? "Face ID" : "Touch ID")")
            } else {
                biometricType = .none
                if let error = error {
                    print("❌ Biometric authentication not available: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ Error checking biometric capability: \(error)")
            biometricType = .none
        }
    }
    
    // Check if biometrics are enabled in user preferences
    private func loadBiometricPreference() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometric_auth_enabled")
    }
    
    // Load biometric enabled state
    func loadBiometricEnabled() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometric_auth_enabled")
    }
    
    // Save biometric enabled state
    func saveBiometricEnabled(_ enabled: Bool) {
        isBiometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "biometric_auth_enabled")
    }
    
    // Enable or disable biometric authentication
    func toggleBiometricAuth() {
        isBiometricEnabled.toggle()
        UserDefaults.standard.set(isBiometricEnabled, forKey: "biometric_auth_enabled")
    }
    
    // Authenticate using biometrics
    func authenticateWithBiometrics() async -> Bool {
        guard isBiometricEnabled && biometricType != .none else {
            return false
        }
        
        await MainActor.run {
            isAuthenticating = true
        }
        
        defer {
            Task { @MainActor in
                isAuthenticating = false
            }
        }
        
        let reason = "Log in to your account"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            return success
        } catch {
            print("❌ Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get the display name for the biometric type
    var biometricTypeName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    // Get the status message for the biometric authentication
    var statusMessage: String {
        if !isBiometricEnabled {
            return "Biometric authentication is disabled"
        }
        
        switch biometricType {
        case .faceID:
            return "Face ID is enabled and ready to use"
        case .touchID:
            return "Touch ID is enabled and ready to use"
        case .opticID:
            return "Optic ID is enabled and ready to use"
        case .none:
            return "No biometric authentication available"
        @unknown default:
            return "Biometric authentication is ready"
        }
    }
    
    // Check if biometrics are available and enabled
    var canUseBiometrics: Bool {
        return isBiometricEnabled && biometricType != .none
    }
    
    // Get the icon for the biometric type
    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "faceid" // Use faceid icon for Optic ID
        case .none:
            return "lock"
        @unknown default:
            return "lock"
        }
    }
    
    // Check if re-enrollment is needed
    var shouldReEnroll: Bool {
        // This would typically check if the user has logged in with credentials
        // and biometrics need to be re-enabled
        return false // For now, always return false
    }
    
    // Re-enroll after credential login
    func reEnrollAfterCredentialLogin() async -> Bool {
        // This would typically re-enable biometric authentication
        // after the user has logged in with credentials
        await MainActor.run {
            isBiometricEnabled = true
            UserDefaults.standard.set(true, forKey: "biometric_auth_enabled")
        }
        return true
    }
    
    // Force re-enrollment
    func forceReEnrollment() async {
        await MainActor.run {
            isBiometricEnabled = false
            UserDefaults.standard.set(false, forKey: "biometric_auth_enabled")
        }
    }
    
    // Check if we should offer biometric setup
    var shouldOfferBiometricSetup: Bool {
        // Offer setup if biometrics are available but not enabled
        return biometricType != .none && !isBiometricEnabled
    }
    
    // Last authentication error
    var lastAuthError: String? {
        // This would store the last authentication error
        // For now, it's a placeholder
        return nil
    }
}
