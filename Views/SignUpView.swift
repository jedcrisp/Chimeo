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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Join Chimeo to stay informed about your community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 16) {
                    // Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your full name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your email", text: $email)
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
                        
                        HStack {
                            if showPassword {
                                TextField("Enter your password", text: $password)
                            } else {
                                SecureField("Enter your password", text: $password)
                            }
                            
                            Button(action: {
                                showPassword.toggle()
                            }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if password.count > 0 && password.count < 6 {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Confirm Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            if showConfirmPassword {
                                TextField("Confirm your password", text: $confirmPassword)
                            } else {
                                SecureField("Confirm your password", text: $confirmPassword)
                            }
                            
                            Button(action: {
                                showConfirmPassword.toggle()
                            }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
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
                    HStack {
                        if isCreatingAccount {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        Text(isCreatingAccount ? "Creating Account..." : "Create Account")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isFormValid ? Color.green : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(!isFormValid || isCreatingAccount)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView(
        onSignUp: { _, _, _ in },
        onDismiss: { }
    )
}
