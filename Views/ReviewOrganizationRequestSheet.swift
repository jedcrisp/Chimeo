import SwiftUI

// MARK: - Enums for Structured Input
enum InfoRequestType: String, CaseIterable {
    case businessLicense = "Business License"
    case taxExemptStatus = "Tax Exempt Status"
    case insuranceDocumentation = "Insurance Documentation"
    case addressVerification = "Address Verification"
    case contactVerification = "Contact Information Verification"
    case missionStatement = "Mission Statement"
    case operationalDetails = "Operational Details"
    case custom = "Custom Request"
    
    var icon: String {
        switch self {
        case .businessLicense: return "doc.text"
        case .taxExemptStatus: return "checkmark.shield"
        case .insuranceDocumentation: return "shield.lefthalf.filled"
        case .addressVerification: return "location"
        case .contactVerification: return "person.crop.circle"
        case .missionStatement: return "text.quote"
        case .operationalDetails: return "gearshape"
        case .custom: return "pencil"
        }
    }
}

enum RejectionReason: String, CaseIterable {
    case incompleteInformation = "Incomplete Information"
    case invalidAddress = "Invalid Address"
    case unverifiedContact = "Unverified Contact"
    case duplicateOrganization = "Duplicate Organization"
    case outsideServiceArea = "Outside Service Area"
    case inappropriateContent = "Inappropriate Content"
    case verificationFailed = "Verification Failed"
    case custom = "Custom Reason"
    
    var icon: String {
        switch self {
        case .incompleteInformation: return "exclamationmark.triangle"
        case .invalidAddress: return "location.slash"
        case .unverifiedContact: return "person.crop.circle.badge.exclamationmark"
        case .duplicateOrganization: return "doc.on.doc"
        case .outsideServiceArea: return "map"
        case .inappropriateContent: return "hand.raised"
        case .verificationFailed: return "xmark.shield"
        case .custom: return "pencil"
        }
    }
}

struct ReviewOrganizationRequestSheet: View {
    let request: OrganizationRequest
    @Binding var reviewNotes: String
    @Binding var selectedReviewStatus: RequestStatus
    @Binding var nextSteps: [String]
    @Binding var newNextStep: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // New state variables for enhanced functionality
    @State private var selectedInfoTypes: Set<InfoRequestType> = []
    @State private var customInfoRequest: String = ""
    @State private var rejectionReason: String = ""
    @State private var showCustomInfoInput: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Request Summary Card
                    requestSummaryCard
                    
                    // Review Decision Card
                    reviewDecisionCard
                    
                    // Conditional Sections
                    if selectedReviewStatus == .requiresMoreInfo {
                        moreInfoRequestCard
                    }
                    
                    if selectedReviewStatus == .rejected {
                        rejectionReasonCard
                    }
                    
                    // Review Notes Card
                    reviewNotesCard
                    
                    // Next Steps Card (for approved or requires more info)
                    if selectedReviewStatus != .rejected {
                        nextStepsCard
                    }
                    
                    // Action Button
                    actionButton
                }
                .padding()
            }
            .navigationTitle("Review Request")
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
    
    // MARK: - View Components
    
    private var requestSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Request Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(request.type.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text(request.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text(request.contactPersonEmail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var reviewDecisionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Decision")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Status Picker
                Picker("Status", selection: $selectedReviewStatus) {
                    ForEach([RequestStatus.approved, RequestStatus.rejected, RequestStatus.requiresMoreInfo], id: \.self) { status in
                        HStack {
                            Image(systemName: status.icon)
                                .foregroundColor(status.color)
                            Text(status.displayName)
                        }
                        .tag(status)
                    }
                }
                .pickerStyle(.segmented)
                
                // Status Description
                if selectedReviewStatus == .requiresMoreInfo {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("This will request additional information from the organization before approval.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if selectedReviewStatus == .rejected {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Please provide clear reasons for rejection.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var moreInfoRequestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information Requested")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Info Type Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(InfoRequestType.allCases, id: \.self) { infoType in
                        Button(action: {
                            if selectedInfoTypes.contains(infoType) {
                                selectedInfoTypes.remove(infoType)
                            } else {
                                selectedInfoTypes.insert(infoType)
                            }
                        }) {
                            HStack {
                                Image(systemName: infoType.icon)
                                    .foregroundColor(selectedInfoTypes.contains(infoType) ? .white : .blue)
                                Text(infoType.rawValue)
                                    .font(.caption)
                                    .foregroundColor(selectedInfoTypes.contains(infoType) ? .white : .primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedInfoTypes.contains(infoType) ? Color.blue : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                }
                
                // Custom Info Request
                if selectedInfoTypes.contains(.custom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Describe what additional information you need...", text: $customInfoRequest, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var rejectionReasonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rejection Reason")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Reason Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(RejectionReason.allCases, id: \.self) { reason in
                        Button(action: {
                            if rejectionReason == reason.rawValue {
                                rejectionReason = ""
                            } else {
                                rejectionReason = reason.rawValue
                            }
                        }) {
                            HStack {
                                Image(systemName: reason.icon)
                                    .foregroundColor(rejectionReason == reason.rawValue ? .white : .red)
                                Text(reason.rawValue)
                                    .font(.caption)
                                    .foregroundColor(rejectionReason == reason.rawValue ? .white : .primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(rejectionReason == reason.rawValue ? Color.red : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                        }
                    }
                }
                
                // Custom Rejection Reason
                if rejectionReason == RejectionReason.custom.rawValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Specific Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Please provide specific reasons for rejection...", text: $customInfoRequest, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var reviewNotesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Notes")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your review notes...", text: $reviewNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if selectedReviewStatus == .rejected {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.red)
                        Text("Please provide clear reasons for rejection to help the organization understand what needs to be addressed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var nextStepsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Next Steps")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if nextSteps.isEmpty {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("No next steps defined")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(nextSteps.indices, id: \.self) { index in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text(nextSteps[index])
                            Spacer()
                            Button(action: { nextSteps.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                HStack {
                    TextField("Add next step", text: $newNextStep)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if !newNextStep.isEmpty {
                            nextSteps.append(newNextStep)
                            newNextStep = ""
                        }
                    }
                    .disabled(newNextStep.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var actionButton: some View {
        Button(action: submitReview) {
            HStack {
                Image(systemName: submitButtonIcon)
                Text(submitButtonText)
            }
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(submitButtonColor)
            .cornerRadius(12)
        }
        .disabled(!canSubmit)
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    
    private var submitButtonIcon: String {
        switch selectedReviewStatus {
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .requiresMoreInfo: return "questionmark.circle"
        default: return "questionmark.circle"
        }
    }
    
    private var submitButtonText: String {
        switch selectedReviewStatus {
        case .approved: return "Approve Organization"
        case .rejected: return "Reject Request"
        case .requiresMoreInfo: return "Request More Info"
        default: return "Submit Review"
        }
    }
    
    private var submitButtonColor: Color {
        switch selectedReviewStatus {
        case .approved: return .green
        case .rejected: return .red
        case .requiresMoreInfo: return .orange
        default: return .blue
        }
    }
    
    private var canSubmit: Bool {
        switch selectedReviewStatus {
        case .approved:
            return true
        case .rejected:
            return !reviewNotes.isEmpty && !rejectionReason.isEmpty
        case .requiresMoreInfo:
            return !reviewNotes.isEmpty && !selectedInfoTypes.isEmpty
        default:
            return false
        }
    }
    
    // MARK: - Methods
    
    private func submitReview() {
        // Format review notes based on selected status
        var formattedNotes = reviewNotes
        
        if selectedReviewStatus == .approved {
            if formattedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                formattedNotes = "Approved"
            }
        } else if selectedReviewStatus == .requiresMoreInfo {
            let selectedTypes = selectedInfoTypes.map { $0.rawValue }
            let infoRequest = selectedTypes.joined(separator: ", ")
            formattedNotes = "Information requested: \(infoRequest)"
            
            if !customInfoRequest.isEmpty {
                formattedNotes += "\n\nAdditional details: \(customInfoRequest)"
            }
            
            if !reviewNotes.isEmpty {
                formattedNotes += "\n\nReview notes: \(reviewNotes)"
            }
        } else if selectedReviewStatus == .rejected {
            if !rejectionReason.isEmpty {
                formattedNotes = "Rejection reason: \(rejectionReason)"
                
                if !customInfoRequest.isEmpty {
                    formattedNotes += "\n\nSpecific details: \(customInfoRequest)"
                }
                
                if !reviewNotes.isEmpty {
                    formattedNotes += "\n\nReview notes: \(reviewNotes)"
                }
            }
        }
        
        // Update the review notes with formatted content
        reviewNotes = formattedNotes
        
        onSubmit()
        dismiss()
    }
}

#Preview {
    let sampleRequest = OrganizationRequest(
        name: "Sample Church",
        type: .church,
        description: "A local community church",
        website: nil,
        phone: nil,
        email: "pastor@samplechurch.com",
        address: "123 Main St",
        city: "Sample City",
        state: "TX",
        zipCode: "75000",
        contactPersonName: "John Pastor",
        contactPersonTitle: "Senior Pastor",
        contactPersonPhone: "555-1234",
        contactPersonEmail: "pastor@samplechurch.com",
        adminPassword: "SecurePassword123!",
        status: .pending
    )
    
    ReviewOrganizationRequestSheet(
        request: sampleRequest,
        reviewNotes: .constant(""),
        selectedReviewStatus: .constant(.pending),
        nextSteps: .constant([]),
        newNextStep: .constant(""),
        onSubmit: {}
    )
} 