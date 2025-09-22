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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Sign In")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Enter your email and password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 16) {
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
                    }
                }
                .padding(.horizontal, 20)
                
                // Sign In Button
                Button(action: {
                    isSigningIn = true
                    onSignIn(email, password)
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
                    .background(email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(email.isEmpty || password.isEmpty || isSigningIn)
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
    EmailLoginView(
        email: .constant("test@example.com"),
        password: .constant("password"),
        onSignIn: { _, _ in },
        onDismiss: { }
    )
}
