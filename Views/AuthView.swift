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
    @EnvironmentObject var apiService: APIService

    var body: some View {
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
            .padding(.bottom, 20)
            
            // Sign-in Options Section - Better spacing
            VStack(spacing: 12) {
                // Sign in with Google
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
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isSigningIn)
                
                // Sign in with Email
                Button(action: {
                    showingEmailLogin = true
                }) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                        Text("Sign in with Email")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray)
                    .cornerRadius(8)
                }
                .disabled(isSigningIn)
                
                // Face ID / Touch ID Button (if available) - nested under email
                if biometricType != .none {
                    biometricButton
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 12)
            
            // Separator - Better spacing
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                Text("OR")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            
            // Account Creation Options
            VStack(spacing: 14) {
                // Create Account
                Button(action: {
                    showingSignUp = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                        Text("Create Account")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .disabled(isSigningIn)
                
                // Request Organization Page
                Button(action: {
                    showingOrganizationRegistration = true
                }) {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                        Text("Request an Organization Page")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 8)
            
            // Organization request info
            Text("No account required for organization requests.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
                .padding(.top, 8)
            
            // Error message
            if let error = signInError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
            }
            
            // Loading indicator
            if isSigningIn {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Signing in...")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            Spacer()
            
            // Terms and Privacy
            VStack(spacing: 6) {
                Text("By continuing, you agree to our")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Button("Terms of Service") {
                        // Terms of Service action
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.blue)
                    
                    Text("and")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    
                    Button("Privacy Policy") {
                        // Privacy Policy action
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 20)
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
        print("🔄 Starting biometric login process...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            // Check if we have stored credentials for biometric login
            if let storedEmail = UserDefaults.standard.string(forKey: "biometric_login_email"),
               let storedPassword = KeychainService.getPassword(for: storedEmail) {
                
                print("🔑 Found stored credentials, attempting login...")
                
                // Attempt to sign in with stored credentials
                let user = try await apiService.signInWithEmail(email: storedEmail, password: storedPassword)
                
                await MainActor.run {
                    isSigningIn = false
                    print("🎉 Successfully signed in with biometrics: \(user.name ?? "Unknown")")
                }
                
            } else {
                // No stored credentials, need to set up biometric login
                await MainActor.run {
                    isSigningIn = false
                    biometricAlertMessage = "Please sign in with email first to enable biometric login"
                    showingBiometricAlert = true
                }
            }
            
        } catch {
            await MainActor.run {
                isSigningIn = false
                biometricAlertMessage = "Biometric login failed: \(error.localizedDescription)"
                showingBiometricAlert = true
            }
        }
    }
    
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
    

    
    private func handleSignInWithGoogle() async {
        print("🔐 Google Sign In started...")
        await MainActor.run {
            isSigningIn = true
            signInError = nil
        }
        
        do {
            print("🔄 Starting Google sign in process...")
            let user = try await apiService.signInWithGoogle()
            
            await MainActor.run {
                isSigningIn = false
                print("🎉 Successfully signed in with Google: \(user.name ?? "Unknown")")
                print("🔐 AuthView: Checking authentication state - isAuthenticated: \(apiService.isAuthenticated), currentUser: \(apiService.currentUser?.email ?? "nil")")
                print("🔍 DEBUG: AuthView after Google sign-in - isAuthenticated: \(apiService.isAuthenticated)")
                print("🔍 DEBUG: AuthView after Google sign-in - currentUser: \(apiService.currentUser?.id ?? "nil")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Google sign in failed: \(error.localizedDescription)"
                print("❌ Google sign in error: \(error)")
                print("🔍 DEBUG: AuthView Google sign-in error - isAuthenticated: \(apiService.isAuthenticated)")
                print("🔍 DEBUG: AuthView Google sign-in error - currentUser: \(apiService.currentUser?.id ?? "nil")")
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
            let user = try await apiService.signInWithEmail(email: email, password: password)
            
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
                print("🎉 Successfully signed in with Email: \(user.name ?? "Unknown")")
                print("🔍 DEBUG: AuthView after email sign-in - isAuthenticated: \(apiService.isAuthenticated)")
                print("🔍 DEBUG: AuthView after email sign-in - currentUser: \(apiService.currentUser?.id ?? "nil")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Email sign in failed: \(error.localizedDescription)"
                print("❌ Email sign in error: \(error)")
                print("🔍 DEBUG: AuthView email sign-in error - isAuthenticated: \(apiService.isAuthenticated)")
                print("🔍 DEBUG: AuthView email sign-in error - currentUser: \(apiService.currentUser?.id ?? "nil")")
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
            let user = try await apiService.signUpWithEmail(email: email, password: password, name: name)
            
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
                print("🎉 Successfully created account: \(user.name ?? "Unknown")")
            }
        } catch {
            await MainActor.run {
                isSigningIn = false
                signInError = "Account creation failed: \(error.localizedDescription)"
                print("❌ Email sign up error: \(error)")
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var currentStep = 0
    @State private var homeAddress = ""
    @State private var workAddress = ""
    @State private var schoolAddress = ""
    @State private var alertRadius: Double = 5.0
    @State private var selectedIncidentTypes: Set<IncidentType> = Set(IncidentType.allCases)
    
    private let steps = ["Welcome", "Locations", "Alert Preferences", "Complete"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                    .padding(.horizontal)
                
                // Step content
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    locationsStep
                case 2:
                    preferencesStep
                case 3:
                    completeStep
                default:
                    EmptyView()
                }
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button("Next") {
                            currentStep += 1
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle(steps[currentStep])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to LocalAlert!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Let's set up your account to get personalized local alerts and incident reports.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var locationsStep: some View {
        VStack(spacing: 20) {
            Text("Set your key locations")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                LocationInputField(title: "Home Address", text: $homeAddress, placeholder: "Enter your home address")
                LocationInputField(title: "Work Address", text: $workAddress, placeholder: "Enter your work address")
                LocationInputField(title: "School Address", text: $schoolAddress, placeholder: "Enter your school address")
            }
            .padding(.horizontal)
        }
    }
    
    private var preferencesStep: some View {
        VStack(spacing: 20) {
            Text("Alert Preferences")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Alert Radius: \(String(format: "%.1f", alertRadius)) miles")
                    .font(.subheadline)
                
                Slider(value: $alertRadius, in: 1...25, step: 0.5)
                
                Text("Incident Types")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(IncidentType.allCases, id: \.self) { type in
                        IncidentTypeToggle(type: type, isSelected: selectedIncidentTypes.contains(type)) {
                            if selectedIncidentTypes.contains(type) {
                                selectedIncidentTypes.remove(type)
                            } else {
                                selectedIncidentTypes.insert(type)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var completeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("You're all set!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("LocalAlert will now send you notifications about incidents in your area based on your preferences.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private func completeOnboarding() {
        Task {
            do {
                let _ = try await apiService.updateUserProfile(
                    name: "LocalAlert User",
                    homeAddress: homeAddress,
                    workAddress: workAddress,
                    schoolAddress: schoolAddress,
                    alertRadius: alertRadius
                )
                
                let updatedPreferences = UserPreferences(
                    incidentTypes: Array(selectedIncidentTypes),
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                )
                
                let _ = try await apiService.updateUserPreferences(updatedPreferences)
                
                // Mark onboarding as completed
                apiService.markOnboardingCompleted()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to save user profile: \(error)")
            }
        }
    }
}

struct LocationInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct IncidentTypeToggle: View {
    let type: IncidentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                Text(type.displayName)
                    .font(.caption)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthView()
        .environmentObject(APIService())
}

// MARK: - EmailLoginView
struct EmailLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @Binding var password: String
    let onSignIn: (String, String) async -> Void
    let onDismiss: () -> Void
    
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with Branding
                    VStack(spacing: 16) {
                        // App Logo - Chimeo Branding
                        ZStack {
                            // Background circle with gradient
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            // Actual App Icon
                            Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            
                            // Subtle inner glow
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .blur(radius: 2)
                        }
                        .padding(.top, 20)
                        
                        // Welcome Text
                        VStack(spacing: 8) {
                            Text("Welcome Back")
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            
                            Text("Sign in to your Chimeo account")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // Form Section
                    VStack(spacing: 24) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email Address")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Sign In Button
                        Button(action: {
                            Task {
                                isSigningIn = true
                                await onSignIn(email, password)
                                isSigningIn = false
                            }
                        }) {
                            HStack {
                                if isSigningIn {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Text(isSigningIn ? "Signing In..." : "Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSigningIn || email.isEmpty || password.isEmpty)
                        
                        // Forgot Password Link
                        Button(action: {
                            // TODO: Implement forgot password
                        }) {
                            Text("Forgot your password?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - SignUpView
struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isSigningUp = false
    
    let onSignUp: (String, String, String) async -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section with Branding
                    VStack(spacing: 16) {
                        // App Logo
                        ZStack {
                            // Background circle with gradient
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            // Actual App Icon
                            Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            
                            // Subtle inner glow
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .blur(radius: 2)
                        }
                        .padding(.top, 20)
                        
                        // Welcome Text
                        VStack(spacing: 8) {
                            Text("Join Chimeo")
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            
                            Text("Create your account to get started")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                    
                    // Form Section
                    VStack(spacing: 24) {
                        // Full Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                TextField("Enter your full name", text: $name)
                                    .textFieldStyle(.plain)
                                    .autocapitalization(.words)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email Address")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                SecureField("Create a password", text: $password)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Create Account Button
                        Button(action: {
                            Task {
                                isSigningUp = true
                                await onSignUp(email, password, name)
                                isSigningUp = false
                            }
                        }) {
                            HStack {
                                if isSigningUp {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Text(isSigningUp ? "Creating Account..." : "Create Account")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSigningUp || !isFormValid)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                    
                    // Footer Section
                    VStack(spacing: 12) {
                        Text("Already have an account?")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            // TODO: Navigate to sign in
                        }) {
                            Text("Sign In")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(.green)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !name.isEmpty && password == confirmPassword
    }
}

// MARK: - Custom Components
struct FormSection<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var isMultiline: Bool = false
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(3...6)
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                        .keyboardType(keyboardType)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct CustomPickerField: View {
    let title: String
    @Binding var selection: OrganizationType
    let icon: String
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Picker("", selection: $selection) {
                    ForEach(OrganizationType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct RequirementRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}



