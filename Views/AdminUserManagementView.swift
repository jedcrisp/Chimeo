import SwiftUI

struct AdminUserManagementView: View {
    @EnvironmentObject var apiService: APIService
    @State private var newAdminEmail = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Add Organization Admin")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Grant admin access to other users by their email address")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Add Admin Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Admin Email")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter email address", text: $newAdminEmail)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button(action: addOrganizationAdmin) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.white)
                            }
                            Text(isLoading ? "Adding Admin..." : "Add as Organization Admin")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(newAdminEmail.isEmpty || isLoading)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Admin Management")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text(successMessage ?? "Admin added successfully")
        }
    }
    
    private func addOrganizationAdmin() {
        guard !newAdminEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                // Find the user by email first
                if let user = try await apiService.findUserByEmail(newAdminEmail.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    // Add them as an organization admin
                    try await apiService.addOrganizationAdmin(user.id, to: "default_organization")
                    
                    await MainActor.run {
                        successMessage = "Successfully added \(newAdminEmail) as organization admin"
                        showingSuccess = true
                        newAdminEmail = ""
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "User with email \(newAdminEmail) not found. They need to create an account first."
                        showingError = true
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add admin: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AdminUserManagementView()
        .environmentObject(APIService())
}

