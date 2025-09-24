import SwiftUI

struct OrganizationLogoView: View {
    let organization: Organization
    let size: CGFloat
    let showBorder: Bool
    
    var body: some View {
        Group {
            if let logoURL = organization.logoURL, !logoURL.isEmpty {
                AsyncImage(url: URL(string: logoURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(showBorder ? Color.blue : Color.clear, lineWidth: showBorder ? 2 : 0)
                        )
                        .onAppear {
                            print("🖼️ OrganizationLogoView: Successfully loaded logo for \(organization.name) - \(logoURL)")
                        }
                } placeholder: {
                    // Placeholder while loading
                    Image(systemName: "building.2.fill")
                        .font(.system(size: size * 0.6, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: size, height: size)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(showBorder ? Color.blue : Color.clear, lineWidth: showBorder ? 2 : 0)
                        )
                        .onAppear {
                            print("⏳ OrganizationLogoView: Loading logo for \(organization.name) - \(logoURL)")
                        }
                }
                .onAppear {
                    print("🖼️ OrganizationLogoView: Attempting to load logo for \(organization.name) - \(logoURL)")
                }
            } else {
                // Fallback when no logo URL
                Image(systemName: "building.2.fill")
                    .font(.system(size: size * 0.6, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(showBorder ? Color.blue : Color.clear, lineWidth: showBorder ? 2 : 0)
                    )
                    .onAppear {
                        print("🏢 OrganizationLogoView: No logo URL for \(organization.name), using fallback icon")
                    }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        OrganizationLogoView(
            organization: Organization(
                id: "test",
                name: "Test Organization",
                type: "business",
                description: "Test description",
                location: Location(latitude: 0, longitude: 0),
                verified: true,
                followerCount: 100,
                logoURL: "https://example.com/logo.png",
                website: "https://example.com",
                phone: "555-0123",
                email: "test@example.com",
                groups: nil,
                adminIds: [:],
                createdAt: Date(),
                updatedAt: Date(),
                groupsArePrivate: false,
                allowPublicGroupJoin: true,
                address: "123 Test St",
                city: "Test City",
                state: "TS",
                zipCode: "12345"
            ),
            size: 50,
            showBorder: true
        )
        
        OrganizationLogoView(
            organization: Organization(
                id: "test2",
                name: "Test Organization 2",
                type: "business",
                description: "Test description",
                location: Location(latitude: 0, longitude: 0),
                verified: false,
                followerCount: 50,
                logoURL: nil,
                website: nil,
                phone: nil,
                email: nil,
                groups: nil,
                adminIds: [:],
                createdAt: Date(),
                updatedAt: Date(),
                groupsArePrivate: false,
                allowPublicGroupJoin: true,
                address: nil,
                city: nil,
                state: nil,
                zipCode: nil
            ),
            size: 30,
            showBorder: false
        )
    }
    .padding()
}
