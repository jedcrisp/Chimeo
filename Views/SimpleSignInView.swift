import SwiftUI
import GoogleSignIn

struct SimpleSignInView: View {
    @StateObject private var authManager = SimpleAuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Logo/Title
            VStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Chimeo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Local Alert System")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            
            // Sign In Form
            VStack(spacing: 16) {
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Sign In Button
                Button(action: signInWithEmail) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                
                // Google Sign In Button
                Button(action: signInWithGoogle) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                .disabled(authManager.isLoading)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(authManager.errorMessage ?? "An error occurred")
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            showingAlert = newValue != nil
        }
    }
    
    // MARK: - Sign In Methods
    private func signInWithEmail() {
        Task {
            await authManager.signInWithEmail(email: email, password: password)
        }
    }
    
    private func signInWithGoogle() {
        Task {
            await authManager.signInWithGoogle()
        }
    }
}

#Preview {
    SimpleSignInView()
}
