import SwiftUI
import FirebaseAuth

struct AuthenticationDebugView: View {
    @StateObject private var apiService = APIService()
    @State private var debugInfo = ""
    @State private var isRegisteringFCM = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Authentication Debug")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Debug Information:")
                            .font(.headline)
                        
                        Text(debugInfo)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                VStack(spacing: 15) {
                    Button("Refresh Debug Info") {
                        refreshDebugInfo()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Synchronize Auth State") {
                        Task {
                            await synchronizeAuthState()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Force FCM Registration") {
                        Task {
                            await forceFCMRegistration()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRegisteringFCM)
                    
                    Button("Ensure User Document") {
                        Task {
                            await ensureUserDocument()
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if isRegisteringFCM {
                        ProgressView("Registering FCM Token...")
                    }
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                refreshDebugInfo()
            }
        }
    }
    
    private func refreshDebugInfo() {
        var info = ""
        
        // APIService state
        info += "APIService:\n"
        info += "  - isAuthenticated: \(apiService.isAuthenticated)\n"
        info += "  - currentUser: \(apiService.currentUser?.id ?? "nil")\n"
        info += "  - currentUser name: \(apiService.currentUser?.name ?? "nil")\n"
        info += "  - currentUser email: \(apiService.currentUser?.email ?? "nil")\n\n"
        
        // UserDefaults
        info += "UserDefaults:\n"
        info += "  - currentUserId: \(UserDefaults.standard.string(forKey: "currentUserId") ?? "nil")\n"
        info += "  - authToken: \(UserDefaults.standard.string(forKey: "authToken") ?? "nil")\n\n"
        
        // Firebase Auth
        info += "Firebase Auth:\n"
        if let firebaseUser = Auth.auth().currentUser {
            info += "  - UID: \(firebaseUser.uid)\n"
            info += "  - Email: \(firebaseUser.email ?? "nil")\n"
            info += "  - Display Name: \(firebaseUser.displayName ?? "nil")\n"
        } else {
            info += "  - No Firebase Auth user\n"
        }
        info += "\n"
        
        // FCM Token
        info += "FCM Token:\n"
        info += "  - fcm_token: \(UserDefaults.standard.string(forKey: "fcm_token") ?? "nil")\n"
        info += "  - pending_fcm_token: \(UserDefaults.standard.string(forKey: "pending_fcm_token") ?? "nil")\n"
        
        debugInfo = info
    }
    
    private func synchronizeAuthState() async {
        await apiService.synchronizeAuthenticationState()
        refreshDebugInfo()
    }
    
    private func forceFCMRegistration() async {
        isRegisteringFCM = true
        await apiService.forceFCMTokenRegistration()
        isRegisteringFCM = false
        refreshDebugInfo()
    }
    
    private func ensureUserDocument() async {
        await apiService.ensureUserDocumentWithFCMToken()
        refreshDebugInfo()
    }
}

#Preview {
    AuthenticationDebugView()
}
