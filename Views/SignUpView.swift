import SwiftUI

struct SignUpView: View {
    let onSignUp: (String, String, String) -> Void
    let onDismiss: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isCreatingAccount = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var passwordMismatch = false
    
    private var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        !confirmPassword.isEmpty && 
        !name.isEmpty && 
        password == confirmPassword &&
        password.count >= 6
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Cancel Button
                HStack {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.leading, 20)
                    
                    Spacer()
                    
                    Text("Create Account")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible spacer for symmetry
                    Color.clear
                        .frame(width: 60)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
                
                // App Icon
                VStack(spacing: 20) {
                    // Bell Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "bell.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    // Welcome Text
                    VStack(spacing: 8) {
                        Text("Join Chimeo")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Create your account to get started")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 40)
                
                // Form Fields
                VStack(spacing: 20) {
                    // Full Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "person")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            TextField("Enter your full name", text: $name)
                                .font(.system(size: 16))
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "envelope")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            TextField("Enter your email", text: $email)
                                .font(.system(size: 16))
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField("Create a password", text: $password)
                                    .font(.system(size: 16))
                            } else {
                                SecureField("Create a password", text: $password)
                                    .font(.system(size: 16))
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
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
                        
                        if password.count > 0 && password.count < 6 {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            if showConfirmPassword {
                                TextField("Confirm your password", text: $confirmPassword)
                                    .font(.system(size: 16))
                            } else {
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .font(.system(size: 16))
                            }
                            
                            Button(action: {
                                showConfirmPassword.toggle()
                            }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
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
                        
                        if passwordMismatch && !confirmPassword.isEmpty {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .onChange(of: confirmPassword) { _, newValue in
                    passwordMismatch = !newValue.isEmpty && password != newValue
                }
                
                // Create Account Button
                Button(action: {
                    if password == confirmPassword {
                        isCreatingAccount = true
                        onSignUp(email, password, name)
                    } else {
                        passwordMismatch = true
                    }
                }) {
                    HStack(spacing: 8) {
                        if isCreatingAccount {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(isCreatingAccount ? "Creating Account..." : "Create Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isFormValid ? Color.green : Color.gray)
                    )
                }
                .disabled(!isFormValid || isCreatingAccount)
                .padding(.horizontal, 20)
                .padding(.top, 32)
                
                // Sign In Link
                HStack {
                    Text("Already have an account?")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        onDismiss()
                    }) {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 16)
                
                Spacer()
            }
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    SignUpView(
        onSignUp: { _, _, _ in },
        onDismiss: { }
    )
}
