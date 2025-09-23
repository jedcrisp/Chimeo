import SwiftUI
import PhotosUI
import FirebaseFirestore
import CoreLocation

struct OrganizationEditView: View {
    let organization: Organization
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var website = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var currentLogoURL: String?
    
    // MARK: - Computed Properties
    private var combinedAddress: String {
        var components: [String] = []
        
        if !address.isEmpty { components.append(address) }
        if !city.isEmpty && !state.isEmpty { components.append("\(city), \(state)") }
        if !zipCode.isEmpty { components.append(zipCode) }
        
        return components.isEmpty ? "No address entered" : components.joined(separator: " ")
    }
    
    // MARK: - Helper Functions
    private func isPlaceholderURL(_ urlString: String) -> Bool {
        let placeholderDomains = [
            "example.com",
            "placeholder.com", 
            "dummy.com",
            "test.com"
        ]
        
        for domain in placeholderDomains {
            if urlString.contains(domain) {
                return true
            }
        }
        
        return false
    }
    
    private func geocodeAddress(_ fullAddress: String) async -> Location? {
        let geocoder = CLGeocoder()
        
        print("🌍 Geocoding address: \(fullAddress)")
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(fullAddress)
            
            if let placemark = placemarks.first,
               let location = placemark.location {
                let result = Location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    address: fullAddress, // Use the original address the user entered
                    city: placemark.locality,
                    state: placemark.administrativeArea,
                    zipCode: placemark.postalCode
                )
                print("✅ Geocoding successful: \(result.coordinate.latitude), \(result.coordinate.longitude)")
                return result
            }
        } catch {
            print("⚠️ Geocoding failed: \(error)")
        }
        
        print("❌ Geocoding failed for address: \(fullAddress)")
        return nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Logo
                    VStack(spacing: 16) {
                        // Logo Section
                        VStack(spacing: 12) {
                            Button(action: { showingImagePicker = true }) {
                                ZStack {
                                    if let selectedImage = selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 4)
                                                    .shadow(radius: 4)
                                            )
                                            .onAppear {
                                                print("🖼️ UI: Showing selectedImage in edit view")
                                            }
                    } else if let logoURL = currentLogoURL, !logoURL.isEmpty, !isPlaceholderURL(logoURL), logoURL.contains("firebasestorage") {
                        AsyncImage(url: URL(string: logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .onAppear {
                                    print("🖼️ OrganizationEditView: Successfully loaded logo from URL: \(logoURL)")
                                }
                        } placeholder: {
                            Image(systemName: "building.2.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.blue)
                                .onAppear {
                                    print("🖼️ OrganizationEditView: Loading logo from URL: \(logoURL)")
                                }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 4)
                                                .shadow(radius: 4)
                                        )
                                    } else {
                                        Image(systemName: "building.2.circle.fill")
                                            .font(.system(size: 100))
                                            .foregroundColor(.blue)
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 4)
                                                    .shadow(radius: 4)
                                            )
                                    }
                                    
                                    // Camera icon overlay
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Image(systemName: "camera.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(.white)
                                                .background(Color.blue)
                                                .clipShape(Circle())
                                                .shadow(radius: 2)
                                        }
                                    }
                                    .padding(.trailing, 6)
                                    .padding(.bottom, 6)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Text("Tap to change logo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Edit Organization")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Update your organization's information and logo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Organization Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter organization name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter organization description", text: $description, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Website")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter website URL", text: $website)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phone Number")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter phone number", text: $phone)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.phonePad)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter email address", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Combined Address Display (Read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Address")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(combinedAddress)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Address")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter street address", text: $address)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("City")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter city", text: $city)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("State")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter state", text: $state)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ZIP Code")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("Enter ZIP code", text: $zipCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .autocapitalization(.none)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button(action: saveOrganization) {
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
            .navigationTitle("Edit Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOrganization()
                    }
                    .disabled(isSaving)
                }
            }
                    .onAppear {
            loadCurrentOrganization()
            // Don't override selectedImage with old logoURL
            if selectedImage == nil {
                currentLogoURL = organization.logoURL
            }
            print("🖼️ OrganizationEditView onAppear:")
            print("   - Organization logoURL: \(organization.logoURL ?? "nil")")
            print("   - Current logoURL: \(currentLogoURL ?? "nil")")
            print("   - Selected image: \(selectedImage != nil ? "exists" : "nil")")
        }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                print("🖼️ Photo picker selection changed: \(newItem != nil ? "photo selected" : "no photo")")
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        print("🖼️ Photo data loaded successfully, size: \(data.count) bytes")
                        if let image = UIImage(data: data) {
                            print("🖼️ UIImage created successfully: \(image.size)")
                            await MainActor.run {
                                selectedImage = image
                                print("✅ selectedImage set to: \(image.size)")
                                print("✅ selectedImage is now: \(selectedImage != nil ? "NOT NIL" : "NIL")")
                            }
                        } else {
                            print("❌ Failed to create UIImage from data")
                        }
                    } else {
                        print("❌ Failed to load photo data")
                    }
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
    
    private func loadCurrentOrganization() {
        name = organization.name
        description = organization.description ?? ""
        website = organization.website ?? ""
        phone = organization.phone ?? ""
        email = organization.email ?? ""
        address = organization.location.address ?? ""
        city = organization.location.city ?? ""
        state = organization.location.state ?? ""
        zipCode = organization.location.zipCode ?? ""
    }
    
    private func saveOrganization() {
        print("🔄 saveOrganization called")
        print("   - selectedImage: \(selectedImage != nil ? "exists" : "nil")")
        print("   - organization ID: \(organization.id)")
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please enter an organization name"
            showingAlert = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                // Handle logo upload if a new image was selected
                var newLogoURL: String?
                if let selectedImage = selectedImage {
                    print("🖼️ Starting logo upload for image: \(selectedImage.size)")
                    print("🖼️ Organization ID: \(organization.id)")
                    print("🖼️ Organization name: \(organization.name)")
                    
                    // Clear the old logo URL first
                    await MainActor.run {
                        self.currentLogoURL = nil
                        print("🖼️ Cleared old logo URL")
                    }
                    
                    do {
                        newLogoURL = try await apiService.uploadOrganizationLogo(selectedImage, organizationId: organization.id, organizationName: organization.name)
                        print("✅ Organization logo uploaded successfully: \(newLogoURL ?? "nil")")
                        print("✅ newLogoURL type: \(type(of: newLogoURL))")
                        print("✅ newLogoURL is nil: \(newLogoURL == nil)")
                        if let url = newLogoURL {
                            print("✅ newLogoURL length: \(url.count)")
                            print("✅ newLogoURL first 100 chars: \(String(url.prefix(100)))")
                        }
                    } catch {
                        print("❌ Failed to upload organization logo: \(error)")
                        // Continue with organization update even if logo upload fails
                    }
                } else {
                    print("⚠️ No selectedImage to upload")
                }
                
                // Update organization in Firestore
                let db = Firestore.firestore()
                var updateData: [String: Any] = [
                    "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
                    "website": website.trimmingCharacters(in: .whitespacesAndNewlines),
                    "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                // Only clear the logo URL if we have a new image to upload
                if selectedImage != nil {
                    updateData["logoURL"] = ""
                    print("📝 Clearing old logo URL because new image is being uploaded")
                } else {
                    // Keep the existing logo URL if no new image is selected
                    if let existingLogoURL = organization.logoURL, !existingLogoURL.isEmpty {
                        updateData["logoURL"] = existingLogoURL
                        print("📝 Preserving existing logo URL: \(existingLogoURL)")
                    }
                }
                
                // If we have a selected image, don't let it get overridden
                if selectedImage != nil {
                    print("📝 Selected image exists - will keep it visible")
                }
                
                // Update location data
                var locationData: [String: Any] = [:]
                if !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    locationData["address"] = address.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    locationData["city"] = city.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    locationData["state"] = state.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !zipCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    locationData["zipCode"] = zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Geocode the new address to update coordinates
                if !locationData.isEmpty {
                    let fullAddress = "\(address.trimmingCharacters(in: .whitespacesAndNewlines)) \(city.trimmingCharacters(in: .whitespacesAndNewlines)), \(state.trimmingCharacters(in: .whitespacesAndNewlines)) \(zipCode.trimmingCharacters(in: .whitespacesAndNewlines))"
                    
                    if let geocodedLocation = await geocodeAddress(fullAddress) {
                        locationData["latitude"] = geocodedLocation.coordinate.latitude
                        locationData["longitude"] = geocodedLocation.coordinate.longitude
                        print("📍 Updated coordinates for new address: \(geocodedLocation.coordinate.latitude), \(geocodedLocation.coordinate.longitude)")
                    } else {
                        print("⚠️ Failed to geocode new address, keeping existing coordinates")
                    }
                    
                    updateData["location"] = locationData
                }
                
                // Add logo URL if we have one
                if let logoURL = newLogoURL {
                    updateData["logoURL"] = logoURL
                    print("📝 Adding logoURL to Firestore update: \(logoURL)")
                    print("📝 This will replace the old placeholder URL with the real photo URL")
                    print("📝 URL domain: \(logoURL.contains(".appspot.com") ? "✅ .appspot.com" : "❌ .firebasestorage.app")")
                } else {
                    print("⚠️ No logoURL to add to Firestore update - this means upload failed")
                    // Even if upload failed, we can still show the selected image
                    print("📝 Will show selected image directly instead of URL")
                }
                
                print("📝 Firestore update data: \(updateData)")
                print("📝 About to update organization document: \(organization.id)")
                
                try await db.collection("organizations")
                    .document(organization.id)
                    .updateData(updateData)
                
                print("✅ Firestore update completed successfully")
                
                print("✅ Organization updated successfully")
                
                // Update the local state with the new logo URL
                if let logoURL = newLogoURL {
                    await MainActor.run {
                        self.currentLogoURL = logoURL
                    }
                } else if let selectedImage = selectedImage {
                    // If upload failed, keep the selected image visible
                    print("📢 Keeping selected image visible even though upload failed")
                }
                
                // Post notification that organization was updated
                await MainActor.run {
                    NotificationCenter.default.post(name: .organizationUpdated, object: organization.id)
                    print("📢 Posted organizationUpdated notification for: \(organization.id)")
                    
                    // Also update the current logo URL immediately so it shows
                    if let logoURL = newLogoURL {
                        self.currentLogoURL = logoURL
                        print("📢 Updated currentLogoURL immediately to: \(logoURL)")
                    } else if let selectedImage = selectedImage {
                        // If upload failed, at least show the selected image
                        print("📢 Upload failed, but selected image is available")
                    }
                }
                
                // Refresh the organizations in APIService to ensure UI updates
                await apiService.refreshOrganizations()
                
                // Force a refresh of the current organization data
                if let updatedOrg = try await apiService.getOrganizationById(organization.id) {
                    print("🔄 Got updated organization data:")
                    print("   - Old logoURL: \(organization.logoURL ?? "nil")")
                    print("   - New logoURL: \(updatedOrg.logoURL ?? "nil")")
                    await MainActor.run {
                        self.currentLogoURL = updatedOrg.logoURL
                        print("🔄 Updated currentLogoURL to: \(self.currentLogoURL ?? "nil")")
                    }
                } else {
                    print("❌ Failed to get updated organization data")
                }
                
                // Also update the organization in the APIService's organizations list
                await apiService.refreshOrganizations()
                print("🔄 Refreshed organizations list to include new logo")
                
                await MainActor.run {
                    isSaving = false
                    alertTitle = "Success"
                    alertMessage = "Your organization has been updated successfully"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertTitle = "Error"
                    alertMessage = "Failed to update organization: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    let sampleOrg = Organization(
        name: "Sample Organization",
        type: "business",
        description: "A sample organization for testing",
        location: Location(latitude: 33.2148, longitude: -97.1331),
        verified: true
    )
    
    return OrganizationEditView(organization: sampleOrg)
        .environmentObject(APIService())
}
