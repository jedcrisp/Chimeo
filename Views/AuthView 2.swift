import SwiftUI
import AuthenticationServices
import MapKit

struct AuthView: View {
    @EnvironmentObject var apiService: APIService
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo and Title
            VStack(spacing: 20) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("LocalAlert")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Stay informed about what's happening in your community")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Sign In Button
            Button(action: signIn) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.title2)
                    Text("Sign in with Apple")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(isLoading)
            
            // Guest Mode Button
            Button(action: enableGuestMode) {
                Text("Continue as Guest")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .disabled(isLoading)
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("By continuing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Button("Privacy Policy") {
                        // Show privacy policy
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Text("and")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Terms of Service") {
                        // Show terms of service
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("Signing in...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
            }
        )
    }
    
    private func signIn() {
        isLoading = true
        
        // Simulate Apple Sign In
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task {
                do {
                    _ = try await apiService.signInWithApple(
                        identityToken: "mock_token",
                        authorizationCode: "mock_code"
                    )
                } catch {
                    print("Sign in error: \(error)")
                }
                
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func enableGuestMode() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            apiService.enableGuestMode()
            isLoading = false
        }
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var currentStep = 0
    @State private var homeAddress = ""
    @State private var workAddress = ""
    @State private var schoolAddress = ""
    @State private var alertRadius: Double = 5.0
    @State private var selectedIncidentTypes: Set<IncidentType> = Set(IncidentType.allCases)
    
    private let steps = ["Welcome", "Locations", "Alert Preferences", "Complete"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                    .padding(.horizontal)
                
                // Step content
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    locationsStep
                case 2:
                    preferencesStep
                case 3:
                    completeStep
                default:
                    EmptyView()
                }
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button("Next") {
                            currentStep += 1
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle(steps[currentStep])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to LocalAlert!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Let's set up your account to get personalized local alerts and incident reports.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var locationsStep: some View {
        VStack(spacing: 20) {
            Text("Set your key locations")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                LocationInputField(title: "Home Address", text: $homeAddress, placeholder: "Enter your home address")
                LocationInputField(title: "Work Address", text: $workAddress, placeholder: "Enter your work address")
                LocationInputField(title: "School Address", text: $schoolAddress, placeholder: "Enter your school address")
            }
            .padding(.horizontal)
        }
    }
    
    private var preferencesStep: some View {
        VStack(spacing: 20) {
            Text("Alert Preferences")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Alert Radius: \(String(format: "%.1f", alertRadius)) miles")
                    .font(.subheadline)
                
                Slider(value: $alertRadius, in: 1...25, step: 0.5)
                
                Text("Incident Types")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(IncidentType.allCases, id: \.self) { type in
                        IncidentTypeToggle(type: type, isSelected: selectedIncidentTypes.contains(type)) {
                            if selectedIncidentTypes.contains(type) {
                                selectedIncidentTypes.remove(type)
                            } else {
                                selectedIncidentTypes.insert(type)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var completeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("You're all set!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("LocalAlert will now send you notifications about incidents in your area based on your preferences.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private func completeOnboarding() {
        Task {
            do {
                let _ = try await apiService.updateUserProfile(
                    name: "LocalAlert User",
                    homeAddress: homeAddress,
                    workAddress: workAddress,
                    schoolAddress: schoolAddress,
                    alertRadius: alertRadius
                )
                
                let updatedPreferences = UserPreferences(
                    incidentTypes: Array(selectedIncidentTypes),
                    criticalAlertsOnly: false,
                    pushNotifications: true,
                    quietHoursEnabled: false,
                    quietHoursStart: nil,
                    quietHoursEnd: nil
                )
                
                let _ = try await apiService.updateUserPreferences(updatedPreferences)
                
                // Mark onboarding as completed
                apiService.markOnboardingCompleted()
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to save user profile: \(error)")
            }
        }
    }
}

struct LocationInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct IncidentTypeToggle: View {
    let type: IncidentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                Text(type.displayName)
                    .font(.caption)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthView()
        .environmentObject(APIService())
}

// MARK: - Organization Registration View
struct OrganizationRegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var organizationName = ""
    @State private var organizationType = OrganizationType.business
    @State private var description = ""
    @State private var website = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var contactPersonName = ""
    @State private var contactPersonTitle = ""
    @State private var contactPersonPhone = ""
    @State private var contactPersonEmail = ""
    @State private var isSubmitting = false
    @State private var submissionMessage = ""
    @State private var showingAddressAutocomplete = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Organization Information") {
                    HStack {
                        TextField("Organization Name", text: $organizationName)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    Picker("Type", selection: $organizationType) {
                        ForEach(OrganizationType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Contact Information") {
                    TextField("Website (Optional)", text: $website)
                    
                    HStack {
                        TextField("Phone", text: $phone)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    HStack {
                        TextField("Email", text: $email)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                }
                
                Section("Address") {
                    HStack {
                        TextField("Street Address", text: $address)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    .onTapGesture {
                        showingAddressAutocomplete = true
                    }
                    
                    HStack {
                        TextField("City", text: $city)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    HStack {
                        TextField("State", text: $state)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    HStack {
                        TextField("ZIP Code", text: $zipCode)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                }
                
                Section("Primary Contact Person") {
                    HStack {
                        TextField("Contact Name", text: $contactPersonName)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    TextField("Title/Role", text: $contactPersonTitle)
                    
                    HStack {
                        TextField("Contact Phone", text: $contactPersonPhone)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    HStack {
                        TextField("Contact Email", text: $contactPersonEmail)
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                }
                
                Section("Important Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📋 Your registration request will be reviewed by Jed Crisp, the creator of LocalAlert.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("🔍 We'll verify your organization and contact you within 2-3 business days.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("✅ Once approved, you'll be able to send alerts to your community.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("* Required fields")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Register Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitRegistration()
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    VStack {
                        ProgressView("Submitting...")
                            .padding()
                        Text("Sending request to Jed Crisp for review")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
            }
            .alert("Registration Submitted", isPresented: .constant(!submissionMessage.isEmpty)) {
                Button("OK") {
                    if submissionMessage.contains("success") {
                        dismiss()
                    }
                    submissionMessage = ""
                }
            } message: {
                Text(submissionMessage)
            }
            .sheet(isPresented: $showingAddressAutocomplete) {
                AddressAutocompleteSheet(
                    address: $address,
                    city: $city,
                    state: $state,
                    zipCode: $zipCode
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        !organizationName.isEmpty &&
        !email.isEmpty &&
        !address.isEmpty &&
        !city.isEmpty &&
        !state.isEmpty &&
        !zipCode.isEmpty &&
        !contactPersonName.isEmpty &&
        !contactPersonPhone.isEmpty &&
        !contactPersonEmail.isEmpty
    }
    
    private func submitRegistration() {
        // Validate required fields
        var missingFields: [String] = []
        
        if organizationName.isEmpty { missingFields.append("Organization Name") }
        if email.isEmpty { missingFields.append("Email") }
        if address.isEmpty { missingFields.append("Street Address") }
        if city.isEmpty { missingFields.append("City") }
        if state.isEmpty { missingFields.append("State") }
        if zipCode.isEmpty { missingFields.append("ZIP Code") }
        if contactPersonName.isEmpty { missingFields.append("Contact Name") }
        if contactPersonPhone.isEmpty { missingFields.append("Contact Phone") }
        if contactPersonEmail.isEmpty { missingFields.append("Contact Email") }
        
        if !missingFields.isEmpty {
            submissionMessage = "❌ Please fill in the following required fields:\n• \(missingFields.joined(separator: "\n• "))"
            return
        }
        
        // Validate email format
        if !isValidEmail(email) {
            submissionMessage = "❌ Please enter a valid email address"
            return
        }
        
        if !isValidEmail(contactPersonEmail) {
            submissionMessage = "❌ Please enter a valid contact person email address"
            return
        }
        
        // Validate phone format (basic validation)
        if !isValidPhone(phone) {
            submissionMessage = "❌ Please enter a valid phone number"
            return
        }
        
        if !isValidPhone(contactPersonPhone) {
            submissionMessage = "❌ Please enter a valid contact person phone number"
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                let request = OrganizationRequest(
                    name: organizationName,
                    type: organizationType,
                    description: description,
                    website: website.isEmpty ? nil : website,
                    phone: phone,
                    email: email,
                    address: address,
                    city: city,
                    state: state,
                    zipCode: zipCode,
                    contactPersonName: contactPersonName,
                    contactPersonTitle: contactPersonTitle,
                    contactPersonPhone: contactPersonPhone,
                    contactPersonEmail: contactPersonEmail,
                    status: .pending
                )
                
                let _ = try await apiService.submitOrganizationRequest(request)
                
                await MainActor.run {
                    isSubmitting = false
                    submissionMessage = "✅ Registration submitted successfully! Jed Crisp will review your request and contact you within 2-3 business days."
                }
                
                // Send notification to Jed Crisp (creator)
                await notifyCreator(request)
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submissionMessage = "❌ Registration failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPhone(_ phone: String) -> Bool {
        let phoneRegex = "^[0-9\\+\\-\\(\\)\\s]{10,}$"
        let phonePredicate = NSPredicate(format:"SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    private func notifyCreator(_ request: OrganizationRequest) async {
        // In a real app, this would send a push notification or email to Jed Crisp
        // For now, we'll just print to console
        print("🚨 NEW ORGANIZATION REGISTRATION REQUEST")
        print("   Organization: \(request.name)")
        print("   Type: \(request.type.displayName)")
        print("   Contact: \(request.contactPersonName) (\(request.contactPersonEmail))")
        print("   Phone: \(request.contactPersonPhone)")
        print("   Address: \(request.fullAddress)")
        print("   Description: \(request.description)")
        print("   Request ID: \(request.id)")
        print("   Submitted: \(request.submittedAt)")
        print("   Status: \(request.status.displayName)")
        print("   Email: \(request.email)")
        print("   Phone: \(request.phone ?? "Not provided")")
        print("   Website: \(request.website ?? "Not provided")")
        print("   Contact Title: \(request.contactPersonTitle)")
        print("   Submitted at: \(request.submittedAt)")
        print("   Request ID: \(request.id)")
        print("   Status: \(request.status.displayName)")
        print("")
        print("📧 ADMIN EMAIL: jed@localalert.com")
        print("🔗 ADMIN PANEL: https://admin.localalert.com/requests/\(request.id)")
        print("")
        print("📋 NEXT STEPS:")
        print("   1. Review the organization details above")
        print("   2. Check their website and contact information")
        print("   3. Verify the address and contact person")
        print("   4. Approve, reject, or request more information")
        print("")
        print("⏰ RESPONSE TIME: Please respond within 2-3 business days")
        print("")
        print(String(repeating: "=", count: 60))
    }
}

// MARK: - Address Autocomplete Sheet
struct AddressAutocompleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var address: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zipCode: String
    
    @State private var searchText = ""
    @State private var searchResults: [AddressSuggestion] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for address...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { oldValue, newValue in
                            performSearch(query: newValue)
                        }
                }
                .padding()
                
                // Search results
                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No addresses found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(searchResults, id: \.id) { result in
                        Button(action: {
                            selectAddress(result)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.fullAddress)
                                    .font(.headline)
                                Text(result.cityStateZip)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Address Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSearching = false
            
            // Generate sample address suggestions based on the search query
            searchResults = generateAddressSuggestions(for: query)
        }
    }
    
    private func generateAddressSuggestions(for query: String) -> [AddressSuggestion] {
        let suggestions = [
            AddressSuggestion(
                streetAddress: "123 \(query) Street",
                city: "Allen",
                state: "TX",
                zipCode: "75013"
            ),
            AddressSuggestion(
                streetAddress: "456 \(query) Avenue",
                city: "Plano",
                state: "TX",
                zipCode: "75023"
            ),
            AddressSuggestion(
                streetAddress: "789 \(query) Road",
                city: "McKinney",
                state: "TX",
                zipCode: "75070"
            ),
            AddressSuggestion(
                streetAddress: "321 \(query) Boulevard",
                city: "Frisco",
                state: "TX",
                zipCode: "75034"
            ),
            AddressSuggestion(
                streetAddress: "654 \(query) Drive",
                city: "Denton",
                state: "TX",
                zipCode: "76201"
            )
        ]
        
        return suggestions
    }
    
    private func selectAddress(_ result: AddressSuggestion) {
        address = result.streetAddress
        city = result.city
        state = result.state
        zipCode = result.zipCode
        
        dismiss()
    }
}

// MARK: - Address Suggestion Model
struct AddressSuggestion: Identifiable {
    let id = UUID()
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
    
    var fullAddress: String {
        streetAddress
    }
    
    var cityStateZip: String {
        "\(city), \(state) \(zipCode)"
    }
}

// MARK: - Admin Panel View
struct AdminPanelView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var pendingRequests: [OrganizationRequest] = []
    @State private var isLoading = false
    @State private var selectedRequest: OrganizationRequest?
    @State private var showingRequestDetail = false
    @State private var approvalNotes = ""
    @State private var rejectionReason = ""
    @State private var rejectionNotes = ""
    @State private var moreInfoRequest = ""
    @State private var moreInfoNotes = ""
    @State private var emailNotificationsEnabled = false
    @State private var adminEmail = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading requests...")
                        .padding()
                } else if pendingRequests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Pending Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("All organization registration requests have been reviewed.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        emailSettingsSection
                        
                        Section("📊 Summary") {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                Text("Pending Review")
                                Spacer()
                                Text("\(pendingRequests.count)")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("Approved Today")
                                Spacer()
                                Text("0")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("Rejected Today")
                                Spacer()
                                Text("0")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Section("📋 Pending Requests") {
                            ForEach(pendingRequests) { request in
                                OrganizationRequestRow(request: request) {
                                    selectedRequest = request
                                    showingRequestDetail = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadPendingRequests()
                    }
                }
            }
            .sheet(isPresented: $showingRequestDetail) {
                if let request = selectedRequest {
                    RequestDetailView(
                        request: request,
                        onApprove: { notes in
                            approveRequest(request, notes: notes)
                        },
                        onReject: { reason, notes in
                            rejectRequest(request, reason: reason, notes: notes)
                        },
                        onRequestMoreInfo: { info, notes in
                            requestMoreInfo(request, info: info, notes: notes)
                        }
                    )
                }
            }
            .onAppear {
                loadPendingRequests()
                loadEmailSettings()
            }
        }
    }
    
    private var emailSettingsSection: some View {
        Section("📧 Email Notifications") {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.blue)
                Text("Email Notifications")
                Spacer()
                Toggle("", isOn: $emailNotificationsEnabled)
                    .onChange(of: emailNotificationsEnabled) { oldValue, newValue in
                        updateEmailSettings(enabled: newValue)
                    }
            }
            
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.green)
                Text("Admin Email")
                Spacer()
                Text(adminEmail)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Text("You'll receive email notifications at \(adminEmail) when:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• New organization registration requests")
                Text("• Request status changes")
                Text("• System updates and alerts")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading)
        }
    }
    
    private func loadEmailSettings() {
        let (enabled, email) = apiService.getEmailNotificationSettings()
        emailNotificationsEnabled = enabled
        adminEmail = email
    }
    
    private func updateEmailSettings(enabled: Bool) {
        apiService.updateEmailNotificationSettings(enabled: enabled, email: adminEmail)
    }
    
    private func loadPendingRequests() {
        isLoading = true
        
        Task {
            do {
                let requests = try await apiService.getPendingOrganizationRequests()
                await MainActor.run {
                    self.pendingRequests = requests
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to load requests: \(error)")
                }
            }
        }
    }
    
    private func approveRequest(_ request: OrganizationRequest, notes: String) {
        Task {
            do {
                let _ = try await apiService.approveOrganizationRequest(request.id, notes: notes)
                await MainActor.run {
                    pendingRequests.removeAll { $0.id == request.id }
                    showingRequestDetail = false
                }
            } catch {
                print("Failed to approve request: \(error)")
            }
        }
    }
    
    private func rejectRequest(_ request: OrganizationRequest, reason: String, notes: String) {
        Task {
            do {
                let _ = try await apiService.rejectOrganizationRequest(request.id, reason: reason, notes: notes)
                await MainActor.run {
                    pendingRequests.removeAll { $0.id == request.id }
                    showingRequestDetail = false
                }
            } catch {
                print("Failed to reject request: \(error)")
            }
        }
    }
    
    private func requestMoreInfo(_ request: OrganizationRequest, info: String, notes: String) {
        Task {
            do {
                let _ = try await apiService.requestMoreInfo(request.id, infoNeeded: info, notes: notes)
                await MainActor.run {
                    showingRequestDetail = false
                }
            } catch {
                print("Failed to request more info: \(error)")
            }
        }
    }
}

// MARK: - Organization Request Row
struct OrganizationRequestRow: View {
    let request: OrganizationRequest
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(request.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(request.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(request.status.color.opacity(0.2))
                        .foregroundColor(request.status.color)
                        .cornerRadius(8)
                }
                
                Text(request.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(request.contactPersonName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(request.fullAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Request Detail View
struct RequestDetailView: View {
    let request: OrganizationRequest
    let onApprove: (String) -> Void
    let onReject: (String, String) -> Void
    let onRequestMoreInfo: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var approvalNotes = ""
    @State private var rejectionReason = ""
    @State private var rejectionNotes = ""
    @State private var moreInfoRequest = ""
    @State private var moreInfoNotes = ""
    @State private var showingActionSheet = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Organization Information") {
                    LabeledContent("Name", value: request.name)
                    LabeledContent("Type", value: request.type.displayName)
                    LabeledContent("Description", value: request.description)
                    LabeledContent("Website", value: request.website ?? "Not provided")
                }
                
                Section("Contact Information") {
                    LabeledContent("Phone", value: request.phone ?? "Not provided")
                    LabeledContent("Email", value: request.email)
                }
                
                Section("Address") {
                    LabeledContent("Address", value: request.fullAddress)
                }
                
                Section("Primary Contact") {
                    LabeledContent("Name", value: request.contactPersonName)
                    LabeledContent("Title", value: request.contactPersonTitle)
                    LabeledContent("Phone", value: request.contactPersonPhone)
                    LabeledContent("Email", value: request.contactPersonEmail)
                }
                
                Section("Request Details") {
                    LabeledContent("Status", value: request.status.displayName)
                    LabeledContent("Submitted", value: request.submittedAt, format: .dateTime)
                    LabeledContent("Request ID", value: request.id)
                }
                
                Section("Actions") {
                    Button("✅ Approve Request") {
                        showingActionSheet = true
                    }
                    .foregroundColor(.green)
                    
                    Button("❌ Reject Request") {
                        showingActionSheet = true
                    }
                    .foregroundColor(.red)
                    
                    Button("❓ Request More Info") {
                        showingActionSheet = true
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Select Action"),
                    message: Text("What would you like to do with this request?"),
                    buttons: [
                        .default(Text("Approve")) {
                            // Show approval dialog
                            onApprove(approvalNotes)
                        },
                        .destructive(Text("Reject")) {
                            // Show rejection dialog
                            onReject(rejectionReason, rejectionNotes)
                        },
                        .default(Text("Request More Info")) {
                            // Show more info dialog
                            onRequestMoreInfo(moreInfoRequest, moreInfoNotes)
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
} 