import SwiftUI
import FirebaseFirestore
import FirebaseCore

struct AdminOrganizationReviewView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
    @State private var organizationRequests: [OrganizationRequest] = []
    @State private var selectedStatus: RequestStatus? = nil
    @State private var isLoading = false
    @State private var showingRequestDetail = false
    @State private var selectedRequest: OrganizationRequest?
    @State private var showingReviewSheet = false
    @State private var reviewNotes = ""
    @State private var selectedReviewStatus: RequestStatus = .pending
    @State private var nextSteps: [String] = []
    @State private var newNextStep = ""
    @State private var listener: ListenerRegistration?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Stats
                headerSection
                
                // Filter Picker
                filterSection
                
                // Content
                if isLoading {
                    loadingView
                } else if organizationRequests.isEmpty {
                    emptyStateView
                } else {
                    requestsList
                }
            }
            .navigationTitle("Organization Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadRequests) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                setupRealtimeListener()
            }
            .onDisappear {
                removeRealtimeListener()
            }
            .sheet(isPresented: $showingRequestDetail) {
                if let request = selectedRequest {
                    OrganizationRequestDetailView(request: request) { status in
                        selectedRequest = request
                        selectedReviewStatus = status
                        showingReviewSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingReviewSheet) {
                ReviewOrganizationRequestSheet(
                    request: selectedRequest!,
                    reviewNotes: $reviewNotes,
                    selectedReviewStatus: $selectedReviewStatus,
                    nextSteps: $nextSteps,
                    newNextStep: $newNextStep,
                    onSubmit: submitReview
                )
            }

        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title and Description
            VStack(spacing: 8) {
                Text("Review Organization Requests")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Approve, deny, or request more information from pending organization verification requests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Stats Cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Pending",
                    value: "\(pendingCount)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Under Review",
                    value: "\(underReviewCount)",
                    icon: "magnifyingglass",
                    color: .blue
                )
                
                StatCard(
                    title: "Total",
                    value: "\(organizationRequests.count)",
                    icon: "doc.text.fill",
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Filter Picker
            Picker("Filter by Status", selection: $selectedStatus) {
                Text("All Requests").tag(nil as RequestStatus?)
                ForEach(RequestStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status as RequestStatus?)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedStatus) { _, _ in
                loadRequests()
            }
            
            // Quick Action Buttons
            if selectedStatus == .pending {
                HStack(spacing: 12) {
                    Button(action: { selectedStatus = .approved }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("View Approved")
                        }
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button(action: { selectedStatus = .rejected }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("View Rejected")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading requests...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No organization requests found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("When organizations submit verification requests, they'll appear here for review.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var requestsList: some View {
        List(organizationRequests) { request in
            OrganizationRequestRow(request: request) {
                selectedRequest = request
                showingRequestDetail = true
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var pendingCount: Int {
        organizationRequests.filter { $0.status == .pending }.count
    }
    
    private var underReviewCount: Int {
        organizationRequests.filter { $0.status == .underReview }.count
    }
    
    private func loadRequests() {
        // This method is now handled by the real-time listener
        // Keeping it for the refresh button functionality
        setupRealtimeListener()
    }
    
    // MARK: - Real-time Listener Methods
    private func setupRealtimeListener() {
        print("🔄 Setting up real-time listener for organization requests...")
        
        let db = Firestore.firestore()
        var query: Query = db.collection("organizationRequests")
        
        // Apply status filter if selected
        if let status = selectedStatus {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        // Set up real-time listener
        listener = query.addSnapshotListener { [self] snapshot, error in
            if let error = error {
                print("❌ Error listening to organization requests: \(error)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("⚠️ No snapshot received from organization requests listener")
                return
            }
            
            print("📡 Received \(snapshot.documentChanges.count) changes for organization requests")
            
            var requests: [OrganizationRequest] = []
            
            for document in snapshot.documents {
                do {
                    let data = document.data()
                    print("📄 Processing real-time request: \(document.documentID)")
                    print("   - Status: \(data["status"] as? String ?? "nil")")
                    print("   - Name: \(data["name"] as? String ?? "nil")")
                    
                    let request = try parseOrganizationRequestFromFirestore(document: document, data: data)
                    requests.append(request)
                    print("✅ Successfully parsed real-time request: \(request.name)")
                } catch {
                    print("⚠️ Error parsing real-time organization request \(document.documentID): \(error)")
                    continue
                }
            }
            
            // Sort by submission date (newest first)
            requests.sort { request1, request2 in
                request1.submittedAt > request2.submittedAt
            }
            
            DispatchQueue.main.async {
                self.organizationRequests = requests
                self.isLoading = false
                print("✅ Updated organization requests list with \(requests.count) requests")
            }
        }
        
        print("✅ Real-time listener set up successfully")
    }
    
    private func removeRealtimeListener() {
        print("🔄 Removing real-time listener for organization requests...")
        listener?.remove()
        listener = nil
        print("✅ Real-time listener removed")
    }
    
    private func parseOrganizationRequestFromFirestore(document: QueryDocumentSnapshot, data: [String: Any]) throws -> OrganizationRequest {
        print("🔍 Parsing organization request document: \(document.documentID)")
        print("   - Available fields: \(data.keys.sorted())")
        
        let id = data["id"] as? String ?? document.documentID
        let name = data["name"] as? String ?? data["organizationName"] as? String ?? "Unknown Organization"
        print("   - Parsed name: \(name)")
        let typeString = data["type"] as? String ?? data["organizationType"] as? String ?? "other"
        let organizationType = OrganizationType(rawValue: typeString) ?? .other
        let description = data["description"] as? String ?? ""
        let website = data["website"] as? String
        let phone = data["phone"] as? String
        let email = data["email"] as? String ?? data["officeEmail"] as? String ?? ""
        
        // Parse location
        let locationData = data["location"] as? [String: Any] ?? [:]
        let location = Location(
            latitude: locationData["latitude"] as? Double ?? 0.0,
            longitude: locationData["longitude"] as? Double ?? 0.0,
            address: locationData["address"] as? String ?? data["address"] as? String ?? "",
            city: locationData["city"] as? String ?? data["city"] as? String ?? "",
            state: locationData["state"] as? String ?? data["state"] as? String ?? "",
            zipCode: locationData["zipCode"] as? String ?? data["zipCode"] as? String ?? ""
        )
        
        // Parse timestamps
        let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse status
        let statusString = data["status"] as? String ?? "pending"
        let status = RequestStatus(rawValue: statusString) ?? .pending
        
        // Parse admin info - handle both web form field names and app field names
        let adminFirstName = data["adminFirstName"] as? String ?? ""
        let adminLastName = data["adminLastName"] as? String ?? ""
        let adminEmail = data["adminEmail"] as? String ?? ""
        
        // Build contact person name from admin fields if contact fields are empty
        let contactPersonName = data["contactPersonName"] as? String ?? 
            (adminFirstName.isEmpty && adminLastName.isEmpty ? "" : "\(adminFirstName) \(adminLastName)".trimmingCharacters(in: .whitespaces))
        
        return OrganizationRequest(
            name: name,
            type: organizationType,
            description: description,
            website: website,
            phone: phone,
            email: email,
            address: location.address ?? "",
            city: location.city ?? "",
            state: location.state ?? "",
            zipCode: location.zipCode ?? "",
            contactPersonName: contactPersonName,
            contactPersonTitle: data["contactPersonTitle"] as? String ?? "",
            contactPersonPhone: data["contactPersonPhone"] as? String ?? data["phone"] as? String ?? "",
            contactPersonEmail: data["contactPersonEmail"] as? String ?? data["contactEmail"] as? String ?? adminEmail,
            adminPassword: data["adminPassword"] as? String ?? "",
            status: status
        )
    }
    
    private func submitReview() {
        guard let request = selectedRequest else { return }
        
        let review = AdminReview(
            requestId: request.id,
            adminId: "admin-123", // This would come from the authenticated admin
            adminName: "Admin User", // This would come from the authenticated admin
            status: selectedReviewStatus,
            notes: reviewNotes,
            nextSteps: nextSteps.isEmpty ? nil : nextSteps
        )
        
        Task {
            do {
                // TODO: Add organization request review to SimpleAuthManager
                print("Organization request review not implemented in SimpleAuthManager")
                
                // If approved, approve the organization request (unrestricted)
                if selectedReviewStatus == .approved {
                    // TODO: Add organization request approval to SimpleAuthManager
                    print("Organization request approval not implemented in SimpleAuthManager")
                }
                
                await MainActor.run {
                    showingReviewSheet = false
                    showingRequestDetail = false
                    loadRequests() // Refresh the list
                }
            } catch {
                print("Error submitting review: \(error)")
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
            VStack(spacing: 0) {
                // Main Content
                HStack(spacing: 12) {
                    // Organization Icon
                    // Note: We need the organization object to use OrganizationLogoView
                    // For now, using a placeholder icon
                    Image(systemName: organizationIcon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(organizationColor)
                        .clipShape(Circle())
                    
                    // Organization Info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(request.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Status Badge
                            HStack(spacing: 4) {
                                Image(systemName: request.status.icon)
                                    .font(.caption)
                                Text(request.status.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(request.status.color)
                            .cornerRadius(12)
                        }
                        
                        // Type and Description
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            
                            Text(request.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // Contact and Date
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contact: \(request.contactPersonName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(request.contactPersonTitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(request.submittedAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                
                // Separator
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.systemGray5))
                    .padding(.horizontal, 16)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var organizationIcon: String {
        switch request.type {
        case .church: return "building.2.fill"
        case .pto: return "graduationcap.fill"
        case .school: return "building.columns.fill"
        case .business: return "building.2.fill"
        case .government: return "building.columns.fill"
        case .nonprofit: return "heart.fill"
        case .emergency: return "cross.fill"
        default: return "building.2.fill"
        }
    }
    
    private var organizationColor: Color {
        switch request.type {
        case .church: return .purple
        case .pto: return .green
        case .school: return .blue
        case .business: return .orange
        case .government: return .red
        case .nonprofit: return .pink
        case .emergency: return .red
        default: return .gray
        }
    }
}

// MARK: - Organization Request Detail View
struct OrganizationRequestDetailView: View {
    let request: OrganizationRequest
    let onReview: (RequestStatus) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: SimpleAuthManager
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isProcessing = false
    @State private var organization: Organization?
    @State private var isLoadingOrganization = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerCard
                    
                    // Description Card
                    infoCard(title: "Description", content: request.description)
                    
                    // Contact Information Card
                    contactCard
                    
                    // Location Card
                    locationCard
                    
                    // Additional Details Card
                    additionalDetailsCard
                    
                    // Submission Info Card
                    submissionCard
                    
                }
                .padding()
            }
            .navigationTitle("Review Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadOrganizationData()
            }
        }
    }
    
    // MARK: - Load Organization Data
    private func loadOrganizationData() {
        guard organization == nil else { return }
        
        isLoadingOrganization = true
        Task {
            do {
                // Try to find existing organization by name and type
                let db = Firestore.firestore()
                let query = try await db.collection("organizations")
                    .whereField("name", isEqualTo: request.name)
                    .whereField("type", isEqualTo: request.type.rawValue)
                    .getDocuments()
                
                if let doc = query.documents.first {
                    // Use the public getOrganizationById method
                    // TODO: Add organization fetching to SimpleAuthManager
                    let org = nil as Organization?
                    await MainActor.run {
                        self.organization = org
                        self.isLoadingOrganization = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingOrganization = false
                    }
                }
            } catch {
                print("❌ Error loading organization data: \(error)")
                await MainActor.run {
                    self.isLoadingOrganization = false
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Organization Logo/Icon
            if let organization = organization {
                OrganizationLogoView(organization: organization, size: 80, showBorder: true)
            } else if isLoadingOrganization {
                ProgressView()
                    .frame(width: 80, height: 80)
            } else {
                // Fallback to placeholder icon
                Image(systemName: organizationIcon)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(organizationColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
            }
            
            // Organization Info
            VStack(spacing: 8) {
                Text(request.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 12) {
                    // Type Badge
                    Text(request.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(organizationColor.opacity(0.1))
                        .foregroundColor(organizationColor)
                        .cornerRadius(20)
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: request.status.icon)
                            .font(.caption)
                        Text(request.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(request.status.color)
                    .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    private func infoCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ContactRow(
                    icon: "person.circle.fill",
                    title: "Contact Person",
                    value: request.contactPersonName,
                    subtitle: request.contactPersonTitle
                )
                
                ContactRow(
                    icon: "phone.fill",
                    title: "Phone",
                    value: request.contactPersonPhone
                )
                
                ContactRow(
                    icon: "envelope.fill",
                    title: "Email",
                    value: request.contactPersonEmail
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(request.fullAddress)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var additionalDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let website = request.website, !website.isEmpty {
                    DetailRow(
                        icon: "globe",
                        title: "Website",
                        value: website,
                        isLink: true
                    )
                }
                
                if let phone = request.phone, !phone.isEmpty {
                    DetailRow(
                        icon: "phone",
                        title: "Organization Phone",
                        value: phone
                    )
                }
                
                DetailRow(
                    icon: "envelope",
                    title: "Organization Email",
                    value: request.email
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var submissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Submission Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Submitted")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(request.submittedAt, style: .date)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    
    // MARK: - Helper Properties
    
    private var organizationIcon: String {
        switch request.type {
        case .church: return "building.2.fill"
        case .pto: return "graduationcap.fill"
        case .school: return "building.columns.fill"
        case .business: return "building.2.fill"
        case .government: return "building.columns.fill"
        case .nonprofit: return "heart.fill"
        case .emergency: return "cross.fill"
        default: return "building.2.fill"
        }
    }
    
    private var organizationColor: Color {
        switch request.type {
        case .church: return .purple
        case .pto: return .green
        case .school: return .blue
        case .business: return .orange
        case .government: return .red
        case .nonprofit: return .pink
        case .emergency: return .red
        default: return .gray
        }
    }
    
}




#Preview {
    AdminOrganizationReviewView()
        .environmentObject(SimpleAuthManager())
} 