import SwiftUI
import LocalAuthentication

struct ModernAuthView: View {
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
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Status Bar Spacing
                Spacer()
                    .frame(height: 20)
                
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
                .padding(.bottom, 50)
                
                // Main Authentication Buttons
                VStack(spacing: 16) {
                    // Google Sign In Button
                    Button(action: {
                        Task {
                            await handleSignInWithGoogle()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("G")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                            
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn)
                    .padding(.horizontal, 40)
                    
                    // Email Sign In Button
                    Button(action: {
                        showingEmailLogin = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            
                            Text("Sign in with Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray)
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn)
                    .padding(.horizontal, 40)
                    
                    // Face ID / Touch ID Button (only show if biometric is available and enabled)
                    if isBiometricEnabled && biometricType != .none {
                        Button(action: {
                            Task {
                                await handleBiometricSignIn()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                
                                Text("Sign in with \(biometricType == .faceID ? "Face ID" : "Touch ID")")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.purple)
                            .cornerRadius(8)
                        }
                        .disabled(isSigningIn)
                        .padding(.horizontal, 40)
                    }
                    
                    // OR Separator
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)
                    
                    // Create Account Button
                    Button(action: {
                        showingSignUp = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            
                            Text("Create Account")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn)
                    .padding(.horizontal, 40)
                    
                    // Request Organization Button
                    Button(action: {
                        showingOrganizationRegistration = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                            
                            Text("Request an Organization Page")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                    .disabled(isSigningIn)
                    .padding(.horizontal, 40)
                    
                    // Organization request note
                    Text("No account required for organization requests.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                
                // Bottom Legal Text
                VStack(spacing: 8) {
                    Spacer()
                        .frame(height: 40)
                    
                    HStack(spacing: 4) {
                        Text("By continuing, you agree to our")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                        
                        Button("Terms of Service") {
                            if let url = URL(string: "https://chimeo.app/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        
                        Text("and")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                        
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://chimeo.app/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                        .frame(height: 20)
                }
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
    
    // MARK: - Authentication Functions
    private func handleSignInWithGoogle() async {
        print("🔐 Google Sign In started...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            print("🔄 Starting Google sign in process...")
            await authManager.signInWithGoogle()
            
            // ServiceCoordinator will automatically sync with SimpleAuthManager changes
            
            await MainActor.run {
                isSigningIn = false
                if let user = authManager.currentUser {
                    print("🎉 Successfully signed in with Google: \(user.name ?? "Unknown")")
                }
                print("🔐 ModernAuthView: Checking authentication state - isAuthenticated: \(authManager.isAuthenticated), currentUser: \(authManager.currentUser?.email ?? "nil")")
                print("🔐 ServiceCoordinator: isAuthenticated: \(serviceCoordinator.isAuthenticated), currentUser: \(serviceCoordinator.currentUser?.email ?? "nil")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Google sign in failed: \(error.localizedDescription)"
                print("❌ Google sign in error: \(error)")
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
            await authManager.signInWithEmail(email: email, password: password)
            
            // Store credentials for biometric login
            do {
                try KeychainService.savePassword(password, for: email)
                UserDefaults.standard.set(email, forKey: "biometric_login_email")
                print("🔑 Credentials stored for biometric login")
            } catch {
                print("⚠️ Failed to store credentials for biometric login: \(error)")
            }
            
            // ServiceCoordinator will automatically sync with SimpleAuthManager changes
            
            await MainActor.run {
                isSigningIn = false
                if let user = authManager.currentUser {
                    print("🎉 Successfully signed in with Email: \(user.name ?? "Unknown")")
                }
                print("🔐 ServiceCoordinator: isAuthenticated: \(serviceCoordinator.isAuthenticated), currentUser: \(serviceCoordinator.currentUser?.email ?? "nil")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Email sign in failed: \(error.localizedDescription)"
                print("❌ Email sign in error: \(error)")
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
    
    private func handleBiometricSignIn() async {
        print("🔐 Biometric Sign In started...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            print("🔄 Starting biometric authentication...")
            
            // Get stored email for biometric login
            guard let storedEmail = UserDefaults.standard.string(forKey: "biometric_login_email"),
                  !storedEmail.isEmpty else {
                await MainActor.run {
                    isSigningIn = false
                    biometricAlertMessage = "No saved credentials found. Please sign in with email first to enable biometric authentication."
                    showingBiometricAlert = true
                }
                return
            }
            
            // Get stored password from keychain
            guard let storedPassword = try? KeychainService.getPassword(for: storedEmail) else {
                await MainActor.run {
                    isSigningIn = false
                    biometricAlertMessage = "No saved credentials found. Please sign in with email first to enable biometric authentication."
                    showingBiometricAlert = true
                }
                return
            }
            
            // Perform biometric authentication
            let context = LAContext()
            let reason = "Use \(biometricType == .faceID ? "Face ID" : "Touch ID") to sign in to Chimeo"
            
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            
            if success {
                // Use stored credentials to sign in
                await authManager.signInWithEmail(email: storedEmail, password: storedPassword)
                
                // ServiceCoordinator will automatically sync with SimpleAuthManager changes
                
                await MainActor.run {
                    isSigningIn = false
                    if let user = authManager.currentUser {
                        print("🎉 Successfully signed in with \(biometricType == .faceID ? "Face ID" : "Touch ID"): \(user.name ?? "Unknown")")
                    }
                    print("🔐 ServiceCoordinator: isAuthenticated: \(serviceCoordinator.isAuthenticated), currentUser: \(serviceCoordinator.currentUser?.email ?? "nil")")
                }
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                biometricAlertMessage = "Biometric authentication failed: \(error.localizedDescription)"
                showingBiometricAlert = true
                print("❌ Biometric sign in error: \(error)")
            }
        }
    }
    
    // MARK: - Biometric Capability Check
    private func checkBiometricCapability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
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
    ModernAuthView()
        .environmentObject(SimpleAuthManager())
}
