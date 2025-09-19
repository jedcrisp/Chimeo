import SwiftUI
import FirebaseFirestore
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploadingPhoto = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        // Profile Picture
                        ZStack {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 3)
                                    )
                            } else if let user = apiService.currentUser, let profilePhotoURL = user.profilePhotoURL, !profilePhotoURL.isEmpty {
                                CachedAsyncImage(
                                    url: profilePhotoURL,
                                    size: 100,
                                    fallback: AnyView(
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Image(systemName: "person.circle.fill")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(.blue)
                                            )
                                    )
                                )
                            } else {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.blue)
                                    )
                            }
                            
                            // Upload overlay
                            if isUploadingPhoto {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                        }
                        .onTapGesture {
                            selectedPhoto = nil // Reset selection
                        }
                        .photosPicker(isPresented: .constant(false), selection: $selectedPhoto, matching: .images)
                        .onChange(of: selectedPhoto) { _, newValue in
                            if let newValue = newValue {
                                loadSelectedPhoto(newValue)
                            }
                        }
                        
                        // Photo selection button
                        Button(action: {
                            selectedPhoto = nil // Reset to trigger picker
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                Text(profileImage != nil || (apiService.currentUser?.profilePhotoURL != nil) ? "Change Photo" : "Add Photo")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        }
                        .disabled(isUploadingPhoto)
                        
                        VStack(spacing: 8) {
                            Text("Edit Profile")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let user = apiService.currentUser, let userName = user.name, !userName.isEmpty {
                                Text("Welcome back, \(userName)!")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                            
                            Text("Update your personal information below")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter your full name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(name.isEmpty ? Color.red.opacity(0.5) : Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            
                            if name.isEmpty {
                                Text("Name is required")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email Address")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter your email address", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disabled(true) // Email cannot be changed
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter your phone number", text: $phone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("Optional - for emergency contact purposes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button(action: saveProfile) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            Text(isSaving ? "Saving..." : "Save Changes")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshUserData) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .onReceive(apiService.$currentUser) { user in
                if let user = user {
                    // Update the form fields when the current user changes
                    name = user.name ?? ""
                    email = user.email ?? ""
                    phone = user.phone ?? ""
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCurrentProfile() {
        if let user = apiService.currentUser {
            // Load from current user first
            name = user.name ?? ""
            email = user.email ?? ""
            phone = user.phone ?? ""
        }
        
        // Always try to load fresh data from Firestore
        Task {
            await refreshUserData()
        }
    }
    
    private func loadSelectedPhoto(_ photoItem: PhotosPickerItem) {
        Task {
            do {
                if let data = try await photoItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.profileImage = image
                    }
                }
            } catch {
                print("❌ Failed to load selected photo: \(error)")
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = "Failed to load selected photo"
                    showingAlert = true
                }
            }
        }
    }
    
    private func saveProfile() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please enter your name"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                // Update the user's profile
                if var user = apiService.currentUser {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    user.name = trimmedName
                    user.phone = trimmedPhone
                    
                    // Handle photo upload if a new photo was selected
                    if let profileImage = profileImage {
                        await MainActor.run {
                            isUploadingPhoto = true
                        }
                        
                        do {
                            print("📸 Starting profile photo upload for user: \(user.id)")
                            print("📸 Image size: \(profileImage.size)")
                            print("📸 Image scale: \(profileImage.scale)")
                            
                            let photoURL = try await apiService.uploadUserProfilePhoto(profileImage, userId: user.id)
                            print("✅ Profile photo uploaded successfully: \(photoURL)")
                            
                            // Update the user object with the new photo URL
                            user.profilePhotoURL = photoURL
                            print("✅ Updated user.profilePhotoURL to: \(photoURL)")
                            
                        } catch {
                            print("❌ Failed to upload profile photo: \(error)")
                            await MainActor.run {
                                isUploadingPhoto = false
                                alertTitle = "Error"
                                alertMessage = "Failed to upload profile photo: \(error.localizedDescription)"
                                showingAlert = true
                                return
                            }
                        }
                        
                        await MainActor.run {
                            isUploadingPhoto = false
                        }
                    }
                    
                    // Update the current user in the API service
                    await MainActor.run {
                        apiService.currentUser = user
                    }
                    
                    // Store in UserDefaults for persistence
                    UserDefaults.standard.set(trimmedName, forKey: "user_name")
                    UserDefaults.standard.set(trimmedPhone, forKey: "user_phone")
                    
                    // Update user document in Firestore
                    try await updateUserProfileInFirestore(name: trimmedName, phone: trimmedPhone, profilePhotoURL: user.profilePhotoURL)
                    
                    await MainActor.run {
                        isSaving = false
                        alertTitle = "Success"
                        alertMessage = "Your profile has been updated successfully"
                        showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertTitle = "Error"
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func updateUserProfileInFirestore(name: String, phone: String, profilePhotoURL: String? = nil) async throws {
        guard let userId = apiService.getCurrentUserId() else {
            throw NSError(domain: "EditProfileView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }
        
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = [
            "name": name,
            "phone": phone,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let profilePhotoURL = profilePhotoURL {
            updateData["profilePhotoURL"] = profilePhotoURL
            print("📸 Adding profilePhotoURL to Firestore update: \(profilePhotoURL)")
        } else {
            print("📸 No profilePhotoURL to save to Firestore")
        }
        
        print("📸 Firestore update data: \(updateData)")
        
        try await db.collection("users")
            .document(userId)
            .updateData(updateData)
        
        print("✅ User profile updated in Firestore: \(name)")
    }
    
    private func refreshUserData() {
        Task {
            do {
                // Try to refresh user data from Firestore
                if let userId = apiService.getCurrentUserId() {
                    let db = Firestore.firestore()
                    let userDoc = try await db.collection("users")
                        .document(userId)
                        .getDocument()
                    
                    if let data = userDoc.data() {
                        await MainActor.run {
                            // Update the form fields with data from Firestore
                            // Look for creatorName first, then fall back to name
                            let firestoreName = data["creatorName"] as? String ?? data["name"] as? String ?? ""
                            let firestorePhone = data["phone"] as? String ?? ""
                            let firestoreProfilePhotoURL = data["profilePhotoURL"] as? String
                            
                            print("📸 Firestore data loaded:")
                            print("   - Name: \(firestoreName)")
                            print("   - Phone: \(firestorePhone)")
                            print("   - ProfilePhotoURL: \(firestoreProfilePhotoURL ?? "nil")")
                            
                            // Only update if we found data in Firestore
                            if !firestoreName.isEmpty {
                                name = firestoreName
                            }
                            if !firestorePhone.isEmpty {
                                phone = firestorePhone
                            }
                            
                            // Also update the API service current user
                            if var user = apiService.currentUser {
                                user.name = name
                                user.phone = phone
                                user.profilePhotoURL = firestoreProfilePhotoURL
                                apiService.currentUser = user
                                print("📸 Updated apiService.currentUser.profilePhotoURL to: \(user.profilePhotoURL ?? "nil")")
                            }
                        }
                        
                        print("✅ User data refreshed from Firestore")
                        print("   - Name from Firestore: \(data["creatorName"] as? String ?? "nil")")
                        print("   - Phone from Firestore: \(data["phone"] as? String ?? "nil")")
                    }
                }
            } catch {
                print("❌ Failed to refresh user data: \(error)")
            }
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(APIService())
}
