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
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            // Organization Logo
                            if let organization = organization {
                                OrganizationLogoView(organization: organization, size: 48, showBorder: false)
                            } else if isLoadingOrganization {
                                // Loading state
                                ProgressView()
                                    .frame(width: 48, height: 48)
                            } else {
                                // Fallback icon if organization failed to load
                                Image(systemName: "building.2.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                    .frame(width: 48, height: 48)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(alert.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                if let organization = organization {
                                    Text(organization.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .fontWeight(.medium)
                                } else {
                                    Text(alert.organizationName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Severity and Type badges
                        HStack(spacing: 12) {
                            SeverityBadge(severity: alert.severity)
                            TypeBadge(type: alert.type)
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                    
                    // Images
                    if !alert.imageURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Images")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(alert.imageURLs, id: \.self) { imageURL in
                                        AsyncImage(url: URL(string: imageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 200, height: 150)
                                                .clipped()
                                                .cornerRadius(12)
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.systemGray6))
                                                .frame(width: 200, height: 150)
                                                .overlay(
                                                    ProgressView()
                                                        .scaleEffect(0.8)
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    
                    // Description
                    if !alert.description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(alert.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    
                    // Group info
                    if let groupName = alert.groupName, !groupName.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Alert Group")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "person.3.sequence")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                
                                Text(groupName)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    
                    // Posted time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Posted")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "clock")
                                .font(.title3)
                                .foregroundColor(.orange)
                            
                            Text(formatTimestamp(alert.postedAt))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .onAppear {
                loadOrganization()
            }
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(severity.color)
        .cornerRadius(12)
        .shadow(color: severity.color.opacity(0.3), radius: 4, x: 0, y: 2)
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
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(type.color)
        .cornerRadius(12)
        .shadow(color: type.color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

