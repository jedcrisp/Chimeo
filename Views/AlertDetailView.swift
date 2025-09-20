import SwiftUI
import FirebaseFirestore

struct AlertDetailView: View {
    let alert: OrganizationAlert
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var apiService: APIService
    @State private var organization: Organization?
    @State private var isLoadingOrganization = true
    @State private var organizationLoadError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero Header with gradient background
                    heroHeader
                    
                    // Content sections
                    VStack(alignment: .leading, spacing: 32) {
                        // Posted time
                        postedTimeSection
                            .padding(.top, 24)
                        
                        // Images section
                        if !alert.imageURLs.isEmpty {
                            imagesSection
                        }
                        
                        // Description section
                        if !alert.description.isEmpty {
                            descriptionSection
                        }
                        
                        // Group info section
                        if let groupName = alert.groupName, !groupName.isEmpty {
                            groupInfoSection(groupName: groupName)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                loadOrganization()
            }
        }
    }
    
    // MARK: - Hero Header
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    alert.severity.color.opacity(0.8),
                    alert.severity.color.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
            .overlay(
                VStack(alignment: .leading, spacing: 12) {
                    Spacer()
                    
                    // Organization info
                    HStack(spacing: 12) {
                        // Organization Logo
                        if let organization = organization {
                            OrganizationLogoView(organization: organization, size: 40, showBorder: true)
                        } else if isLoadingOrganization {
                            ProgressView()
                                .frame(width: 40, height: 40)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "building.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let organization = organization {
                                Text(organization.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            } else {
                                Text(alert.organizationName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            
                            // Severity and Type badges
                            HStack(spacing: 8) {
                                SeverityBadge(severity: alert.severity)
                                TypeBadge(type: alert.type)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Alert title
                    Text(alert.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            )
        }
    }
    
    // MARK: - Posted Time Section
    private var postedTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Posted")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
            }
            
            Text(formatTimestamp(alert.postedAt))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Images Section
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Attached Images")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(alert.imageURLs, id: \.self) { imageURL in
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 280, height: 200)
                                .clipped()
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .frame(width: 280, height: 200)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(1.4)
                                        Text("Loading...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Description")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
            }
            
            Text(alert.description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Group Info Section
    private func groupInfoSection(groupName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Alert Group")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
            }
            
            Text(groupName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    
    // MARK: - Organization Loading
    private func loadOrganization() {
        guard organization == nil else { return }
        
        isLoadingOrganization = true
        organizationLoadError = false
        
        Task {
            do {
                if let org = try await apiService.getOrganizationById(alert.organizationId) {
                    await MainActor.run {
                        self.organization = org
                        self.isLoadingOrganization = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingOrganization = false
                        self.organizationLoadError = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingOrganization = false
                    self.organizationLoadError = true
                }
            }
        }
    }
    
    // MARK: - Timestamp Formatting
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Severity Badge
struct SeverityBadge: View {
    let severity: IncidentSeverity
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.white)
            
            Text(severity.displayName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(severity.color)
        )
        .shadow(color: severity.color.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Type Badge
struct TypeBadge: View {
    let type: IncidentType
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.icon)
                .font(.caption2)
                .foregroundColor(.white)
            
            Text(type.displayName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(type.color)
        )
        .shadow(color: type.color.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

