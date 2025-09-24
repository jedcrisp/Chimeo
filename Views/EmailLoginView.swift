import SwiftUI

struct EmailLoginView: View {
    @Binding var email: String
    @Binding var password: String
    let onSignIn: (String, String) -> Void
    let onDismiss: () -> Void
    
    @State private var isSigningIn = false
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundColor(.blue)
                            .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Text("Sign In")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible filler for symmetry
                    Text("Cancel")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .opacity(0)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer().frame(height: 40)
                
                // Card container
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.blue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "bell.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    // Welcome text
                    VStack(spacing: 4) {
                        Text("Welcome Back")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Sign in to your Chimeo account")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email Address")
                            .font(.footnote)
                            .fontWeight(.semibold)
                        
                        TextField("Enter your email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.footnote)
                            .fontWeight(.semibold)
                        
                        HStack {
                            if showPassword {
                                TextField("Enter your password", text: $password)
                            } else {
                                SecureField("Enter your password", text: $password)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Sign In button
                    Button(action: {
                        isSigningIn = true
                        onSignIn(email, password)
                    }) {
                        Text(isSigningIn ? "Signing In..." : "Sign In")
                            .foregroundColor(.white)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                    
                    // Forgot password
                    Button("Forgot your password?") {
                        // TODO: Forgot password flow
                    }
                    .foregroundColor(.blue)
                    .font(.subheadline)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}

#Preview {
    EmailLoginView(
        email: .constant(""),
        password: .constant(""),
        onSignIn: { _, _ in },
        onDismiss: {}
    )
}
