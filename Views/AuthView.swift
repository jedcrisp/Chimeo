import SwiftUI
import MapKit
import LocalAuthentication
import Foundation

struct AuthView: View {
    @State private var showingOnboarding = false
    @State private var showingOrganizationRegistration = false
    @State private var isSigningIn = false
    @State private var signInError: String?
    @State private var showingEmailLogin = false
    @State private var showingSignUp = false
    @State private var emailInput = ""
    @State private var passwordInput = ""
    @State private var biometricType: LABiometryType = .none
    @State private var isBiometricEnabled = false
    @State private var showingBiometricAlert = false
    @State private var biometricAlertMessage = ""
    @EnvironmentObject var authManager: SimpleAuthManager

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Status Bar Spacing
                Spacer()
                
                // App Branding Section
                VStack(spacing: 16) {
                    // App Logo
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                    
                    // App Name
                    Text("Chimeo")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundColor(.black)
                    
                    // Tagline
                    Text("Stay informed about your community")
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(2)
                }
                .padding(.bottom, 40)
                
                // Main Login Form
                VStack(spacing: 20) {
                    // Email and Password Fields
                    VStack(spacing: 16) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $emailInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $passwordInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Sign In Button
                    Button(action: {
                        Task {
                            await handleSignInWithEmail(email: emailInput, password: passwordInput)
                        }
                    }) {
                        HStack {
                            if isSigningIn {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "envelope")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            Text(isSigningIn ? "Signing In..." : "Sign In")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(emailInput.isEmpty || passwordInput.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(emailInput.isEmpty || passwordInput.isEmpty || isSigningIn)
                    .padding(.horizontal, 40)
                    
                    // Face ID / Touch ID Button (if available)
                    if biometricType != .none {
                        biometricButton
                            .padding(.horizontal, 40)
                    }
                    
                    // Google Sign In Button
                    Button(action: {
                        Task {
                            await handleSignInWithGoogle()
                        }
                    }) {
                        HStack {
                            Text("G")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn)
                    .padding(.horizontal, 40)
                }
                
                // Bottom Options
                VStack(spacing: 16) {
                    // Create Account Button
                    Button(action: {
                        showingSignUp = true
                    }) {
                        Text("Don't have an account? Create one")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .disabled(isSigningIn)
                    
                    // Request Organization Button
                    Button(action: {
                        showingOrganizationRegistration = true
                    }) {
                        Text("Request an Organization Page")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .disabled(isSigningIn)
                }
                .padding(.top, 20)
                
                // Bottom Spacing
                Spacer()
            }
        }
        .onAppear {
            checkBiometricCapability()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showingOrganizationRegistration) {
            OrganizationRequestView()
        }
        .sheet(isPresented: $showingEmailLogin) {
            EmailLoginView(
                email: $emailInput,
                password: $passwordInput,
                onSignIn: { email, password in
                    Task {
                        await handleSignInWithEmail(email: email, password: password)
                    }
                },
                onDismiss: { showingEmailLogin = false }
            )
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView(
                onSignUp: { email, password, name in
                    Task {
                        await handleSignUpWithEmail(email: email, password: password, name: name)
                    }
                },
                onDismiss: { showingSignUp = false }
            )
        }
        .alert("Biometric Authentication", isPresented: $showingBiometricAlert) {
            Button("OK") { }
        } message: {
            Text(biometricAlertMessage)
        }
    }
    
    // MARK: - Biometric Button
    private var biometricButton: some View {
        Button(action: authenticateWithBiometrics) {
            HStack {
                Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 20, weight: .medium))
                Text("Sign in with \(biometricType == .faceID ? "Face ID" : "Touch ID")")
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(isSigningIn)
    }
    
    // MARK: - Authentication Functions
    private func handleSignInWithGoogle() async {
        print("🔐 Google Sign In started...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            print("🔄 Starting Google sign in process...")
            // TODO: Add Google sign-in to SimpleAuthManager
            await authManager.signInWithGoogle()
            
            await MainActor.run {
                isSigningIn = false
                if let user = authManager.currentUser {
                    print("🎉 Successfully signed in with Google: \(user.name ?? "Unknown")")
                }
                print("🔐 AuthView: Checking authentication state - isAuthenticated: \(authManager.isAuthenticated), currentUser: \(authManager.currentUser?.email ?? "nil")")
                print("🔍 DEBUG: AuthView after Google sign-in - isAuthenticated: \(authManager.isAuthenticated)")
                print("🔍 DEBUG: AuthView after Google sign-in - currentUser: \(authManager.currentUser?.id ?? "nil")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Google sign in failed: \(error.localizedDescription)"
                print("❌ Google sign in error: \(error)")
                print("🔍 DEBUG: AuthView Google sign-in error - isAuthenticated: \(authManager.isAuthenticated)")
            }
        }
    }
    
    private func handleSignInWithEmail(email: String, password: String) async {
        print("🔐 Email Sign In started...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            print("🔄 Starting email sign in process...")
            // TODO: Add email sign-in to SimpleAuthManager
            await authManager.signInWithEmail(email: email, password: password)
            
            // Store credentials for biometric login
            do {
                try KeychainService.savePassword(password, for: email)
                UserDefaults.standard.set(email, forKey: "biometric_login_email")
                print("🔑 Credentials stored for biometric login")
            } catch {
                print("⚠️ Failed to store credentials for biometric login: \(error)")
            }
            
            await MainActor.run {
                isSigningIn = false
                if let user = authManager.currentUser {
                    print("🎉 Successfully signed in with Email: \(user.name ?? "Unknown")")
                }
                print("🔍 DEBUG: AuthView after email sign-in - isAuthenticated: \(authManager.isAuthenticated)")
                print("🔍 DEBUG: AuthView after email sign-in - currentUser: \(authManager.currentUser?.id ?? "nil")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Email sign in failed: \(error.localizedDescription)"
                print("❌ Email sign in error: \(error)")
                print("🔍 DEBUG: AuthView email sign-in error - isAuthenticated: \(authManager.isAuthenticated)")
            }
        }
    }
    
    private func handleSignUpWithEmail(email: String, password: String, name: String) async {
        print("🔐 Email Sign Up started...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            print("🔄 Starting email sign up process...")
            // TODO: Add email sign-up to SimpleAuthManager
            await authManager.signInWithEmail(email: email, password: password) // Using signIn for now
            
            // Store credentials for biometric login
            do {
                try KeychainService.savePassword(password, for: email)
                UserDefaults.standard.set(email, forKey: "biometric_login_email")
                print("🔑 Credentials stored for biometric login")
            } catch {
                print("⚠️ Failed to store credentials for biometric login: \(error)")
            }
            
            await MainActor.run {
                isSigningIn = false
                if let user = authManager.currentUser {
                    print("🎉 Successfully created account: \(user.name ?? "Unknown")")
                }
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Account creation failed: \(error.localizedDescription)"
                print("❌ Email sign up error: \(error)")
            }
        }
    }
    
    // MARK: - Biometric Authentication
    private func authenticateWithBiometrics() {
        let context = LAContext()
        let reason = "Log in to your account"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Biometric authentication successful
                    print("✅ Biometric authentication successful")
                    
                    // Now authenticate the user with stored credentials
                    Task {
                        await self.handleBiometricLogin()
                    }
                } else {
                    // Biometric authentication failed
                    if let error = error {
                        print("❌ Biometric authentication failed: \(error.localizedDescription)")
                        biometricAlertMessage = "Biometric authentication failed: \(error.localizedDescription)"
                    } else {
                        biometricAlertMessage = "Biometric authentication failed"
                    }
                    showingBiometricAlert = true
                }
            }
        }
    }
    
    private func handleBiometricLogin() async {
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        // Check if we have stored credentials
        if let storedEmail = UserDefaults.standard.string(forKey: "biometric_login_email"),
           let storedPassword = KeychainService.getPassword(for: storedEmail) {
            
            print("🔑 Found stored credentials, attempting login...")
            
            // Attempt to sign in with stored credentials
            // TODO: Add email sign-in to SimpleAuthManager
            await authManager.signInWithEmail(email: storedEmail, password: storedPassword)
            
            await MainActor.run {
                isSigningIn = false
                if let user = authManager.currentUser {
                    print("🎉 Successfully signed in with biometrics: \(user.name ?? "Unknown")")
                }
            }
            
        } else {
            // No stored credentials, need to set up biometric login
            await MainActor.run {
                isSigningIn = false
                biometricAlertMessage = "Please sign in with email first to enable biometric login"
                showingBiometricAlert = true
            }
        }
    }
    
    // MARK: - Biometric Capability Check
    private func checkBiometricCapability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
            // Enable biometrics by default if available
            isBiometricEnabled = UserDefaults.standard.bool(forKey: "biometric_auth_enabled") || true
            print("✅ Biometric type available: \(biometricType == .faceID ? "Face ID" : "Touch ID")")
        } else {
            biometricType = .none
            isBiometricEnabled = false
            if let error = error {
                print("❌ Biometric authentication not available: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(SimpleAuthManager())
}