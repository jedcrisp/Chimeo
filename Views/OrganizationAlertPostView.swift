import SwiftUI
import CoreLocation
import FirebaseAuth

struct OrganizationAlertPostView: View {
    let organization: Organization
    let preSelectedGroup: OrganizationGroup?
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: IncidentType = .weather
    @State private var selectedSeverity: IncidentSeverity = .low
    @State private var selectedGroup: OrganizationGroup?
    @State private var includeAlertType = false
    @State private var includeAlertSeverity = false
    @State private var includeLocation = false
    @State private var customLocation: Location?
    @State private var isSubmitting = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    init(organization: Organization, preSelectedGroup: OrganizationGroup? = nil) {
        self.organization = organization
        self.preSelectedGroup = preSelectedGroup
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Alert Details Section
                Section("Alert Details") {
                    TextField("Alert Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                // Alert Type & Severity Section
                Section("Alert Type & Severity") {
                    // Alert Type Toggle
                    Toggle("Include Alert Type", isOn: $includeAlertType)
                    
                    if includeAlertType {
                        Picker("Type", selection: $selectedType) {
                            ForEach(IncidentType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Alert Severity Toggle
                    Toggle("Include Alert Severity", isOn: $includeAlertSeverity)
                    
                    if includeAlertSeverity {
                        Picker("Severity", selection: $selectedSeverity) {
                            ForEach(IncidentSeverity.allCases, id: \.self) { severity in
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(severity.color)
                                    Text(severity.displayName)
                                }
                                .tag(severity)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Group Selection Section (if organization has groups)
                if let groups = organization.groups, !groups.isEmpty {
                    Section("Target Group (Optional)") {
                        Picker("Group", selection: $selectedGroup) {
                            Text("All Members").tag(nil as OrganizationGroup?)
                            ForEach(groups, id: \.id) { group in
                                Text(group.name).tag(group as OrganizationGroup?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Location Section
                Section("Location") {
                    Toggle("Include Custom Location", isOn: $includeLocation)
                    
                    if includeLocation {
                        SimpleLocationPickerView(location: $customLocation)
                    }
                }
                
                // Preview Section
                if !title.isEmpty || !description.isEmpty {
                    Section("Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(title.isEmpty ? "Alert Title" : title)
                                    .font(.headline)
                                    .foregroundColor(title.isEmpty ? .secondary : .primary)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    if includeAlertType {
                                        Image(systemName: selectedType.icon)
                                            .foregroundColor(selectedType.color)
                                    }
                                    if includeAlertSeverity {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(selectedSeverity.color)
                                    }
                                }
                            }
                            
                            if !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Organization: \(organization.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let group = selectedGroup {
                                    Text("Group: \(group.name)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Post Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        postAlert()
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                    .fontWeight(.semibold)
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
        .onAppear {
            print("🔍 OrganizationAlertPostView appeared")
            print("   preSelectedGroup: \(preSelectedGroup?.name ?? "nil")")
            print("   preSelectedGroup ID: \(preSelectedGroup?.id ?? "nil")")
            
            // Set pre-selected group if provided
            if let preSelectedGroup = preSelectedGroup {
                selectedGroup = preSelectedGroup
                print("   ✅ selectedGroup set to: \(selectedGroup?.name ?? "nil")")
            } else {
                print("   ⚠️ No preSelectedGroup provided")
            }
            
            // Ensure we have the latest organizations loaded when view appears
            Task {
                await apiService.forceRefreshOrganizations()
            }
            
            // Note: Admin permission is already checked in GroupSelectionView
            // before this view is presented, so no need to check again here
        }
    }
    
    private func postAlert() {
        guard !title.isEmpty && !description.isEmpty else { return }
        
        isSubmitting = true
        
        // Ensure we have the latest organizations loaded
        Task {
            await apiService.forceRefreshOrganizations()
        }
        
        // Get current user ID with fallback to Firebase Auth
        let currentUserId: String
        let currentUserName: String
        
        print("🔍 Debugging user ID lookup for alert creation:")
        print("   APIService currentUser: \(apiService.currentUser?.id ?? "nil")")
        print("   Firebase Auth currentUser: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("   UserDefaults currentUserId: \(UserDefaults.standard.string(forKey: "currentUserId") ?? "nil")")
        
        if let apiUserId = apiService.currentUser?.id, !apiUserId.isEmpty {
            currentUserId = apiUserId
            currentUserName = apiService.currentUser?.name ?? "Organization Admin"
            print("   ✅ Using APIService user ID: \(apiUserId)")
        } else if let firebaseUserId = Auth.auth().currentUser?.uid {
            currentUserId = firebaseUserId
            currentUserName = Auth.auth().currentUser?.displayName ?? "Organization Admin"
            print("   ✅ Using Firebase Auth user ID: \(firebaseUserId)")
        } else if let defaultsUserId = UserDefaults.standard.string(forKey: "currentUserId"), !defaultsUserId.isEmpty {
            currentUserId = defaultsUserId
            currentUserName = "Organization Admin"
            print("   ✅ Using UserDefaults user ID: \(defaultsUserId)")
        } else {
            // Generate a temporary user ID for this session
            currentUserId = "temp_\(UUID().uuidString.prefix(8))"
            currentUserName = "Organization Admin"
            print("   ⚠️ No user ID found, using temporary ID: \(currentUserId)")
        }
        
        // Create the alert with conditional type and severity
        let alert = OrganizationAlert(
            title: title,
            description: description,
            organizationId: organization.id, // Use the actual Firestore document ID, not the computed firestoreId
            organizationName: organization.name,
            groupId: selectedGroup?.id,
            groupName: selectedGroup?.name,
            type: includeAlertType ? selectedType : .other,
            severity: includeAlertSeverity ? selectedSeverity : .low,
            location: includeLocation ? customLocation : organization.location,
            postedBy: currentUserName,
            postedByUserId: currentUserId,
            postedAt: Date() // Explicitly set the creation timestamp
        )
        
        Task {
            do {
                try await serviceCoordinator.postOrganizationAlert(alert)
                
                await MainActor.run {
                    alertTitle = "Success"
                    alertMessage = "Alert posted successfully! It will be visible to your organization's followers."
                    showingAlert = true
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = "Failed to post alert: \(error.localizedDescription)"
                    showingAlert = true
                    isSubmitting = false
                }
            }
        }
    }
}



// MARK: - Simple Location Picker View
struct SimpleLocationPickerView: View {
    @Binding var location: Location?
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Address", text: $address)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                TextField("City", text: $city)
                    .textFieldStyle(.roundedBorder)
                
                TextField("State", text: $state)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                
                TextField("ZIP", text: $zipCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            
            Button("Use Current Location") {
                // In a real app, this would get the user's current location
                // For now, we'll use a default location
                location = Location(
                    latitude: 33.2148,
                    longitude: -97.1331,
                    address: address,
                    city: city,
                    state: state,
                    zipCode: zipCode
                )
            }
            .buttonStyle(.bordered)
            .disabled(address.isEmpty || city.isEmpty || state.isEmpty || zipCode.isEmpty)
        }
        .onChange(of: address) { updateLocation() }
        .onChange(of: city) { updateLocation() }
        .onChange(of: state) { updateLocation() }
        .onChange(of: zipCode) { updateLocation() }
    }
    
    private func updateLocation() {
        if !address.isEmpty && !city.isEmpty && !state.isEmpty && !zipCode.isEmpty {
            location = Location(
                latitude: 33.2148, // Default coordinates for Denton
                longitude: -97.1331,
                address: address,
                city: city,
                state: state,
                zipCode: zipCode
            )
        }
    }
}

#Preview {
    let sampleOrg = Organization(
        name: "Sample Organization",
        type: "business",
        description: "A sample organization for testing",
        location: Location(latitude: 33.2148, longitude: -97.1331),
        verified: true,
        groups: [
            OrganizationGroup(
                name: "Emergency Alerts",
                description: "Critical emergency notifications",
                organizationId: "sample"
            )
        ]
    )
    
    return OrganizationAlertPostView(organization: sampleOrg)
        .environmentObject(APIService())
}
