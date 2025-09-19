import SwiftUI

struct AdminPlatformStatsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var stats = PlatformStats()
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Overview Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        AdminStatCard(
                            title: "Total Users",
                            value: "\(stats.totalUsers)",
                            icon: "person.3",
                            color: .blue
                        )
                        
                        AdminStatCard(
                            title: "Organizations",
                            value: "\(stats.totalOrganizations)",
                            icon: "building.2",
                            color: .green
                        )
                        
                        AdminStatCard(
                            title: "Pending Requests",
                            value: "\(stats.pendingRequests)",
                            icon: "clock",
                            color: .orange
                        )
                        
                        AdminStatCard(
                            title: "Total Incidents",
                            value: "\(stats.totalIncidents)",
                            icon: "exclamationmark.triangle",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Detailed Statistics
                    VStack(spacing: 16) {
                        // Organization Requests by Status
                        StatSection(title: "Organization Requests by Status") {
                            ForEach(RequestStatus.allCases, id: \.self) { status in
                                HStack {
                                    HStack {
                                        Image(systemName: status.icon)
                                            .foregroundColor(status.color)
                                        Text(status.displayName)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(stats.requestsByStatus[status] ?? 0)")
                                        .font(.headline)
                                        .foregroundColor(status.color)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Organizations by Type
                        StatSection(title: "Organizations by Type") {
                            ForEach(OrganizationType.allCases, id: \.self) { type in
                                HStack {
                                    Text(type.displayName)
                                    
                                    Spacer()
                                    
                                    Text("\(stats.organizationsByType[type] ?? 0)")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Recent Activity
                        StatSection(title: "Recent Activity") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(stats.recentActivity.prefix(5), id: \.id) { activity in
                                    HStack {
                                        Image(systemName: activity.icon)
                                            .foregroundColor(activity.color)
                                            .frame(width: 20)
                                        
                                        Text(activity.description)
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text(activity.timestamp, style: .relative)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Platform Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: loadStats) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadStats()
        }
    }
    
    private func loadStats() {
        isLoading = true
        
        // Simulate loading stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            stats = PlatformStats.sample()
            isLoading = false
        }
    }
}

// MARK: - Admin Stat Card
struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Stat Section
struct StatSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Platform Stats Model
struct PlatformStats {
    var totalUsers: Int = 0
    var totalOrganizations: Int = 0
    var pendingRequests: Int = 0
    var totalIncidents: Int = 0
    var requestsByStatus: [RequestStatus: Int] = [:]
    var organizationsByType: [OrganizationType: Int] = [:]
    var recentActivity: [ActivityItem] = []
    
    static func sample() -> PlatformStats {
        var stats = PlatformStats()
        stats.totalUsers = 1247
        stats.totalOrganizations = 89
        stats.pendingRequests = 12
        stats.totalIncidents = 456
        
        stats.requestsByStatus = [
            .pending: 12,
            .underReview: 5,
            .approved: 67,
            .rejected: 8,
            .requiresMoreInfo: 3
        ]
        
        stats.organizationsByType = [
            .business: 23,
            .church: 18,
            .school: 15,
            .pto: 12,
            .government: 8,
            .nonprofit: 7,
            .emergency: 4,
            .other: 2
        ]
        
        stats.recentActivity = [
            ActivityItem(description: "New organization request from First Baptist Church", icon: "building.2", color: .blue, timestamp: Date().addingTimeInterval(-3600)),
            ActivityItem(description: "Incident reported in Downtown area", icon: "exclamationmark.triangle", color: .red, timestamp: Date().addingTimeInterval(-7200)),
            ActivityItem(description: "Organization 'City PTO' verified", icon: "checkmark.seal.fill", color: .green, timestamp: Date().addingTimeInterval(-10800)),
            ActivityItem(description: "New user registered", icon: "person.badge.plus", color: .blue, timestamp: Date().addingTimeInterval(-14400)),
            ActivityItem(description: "Emergency alert sent by Fire Department", icon: "bell.badge", color: .orange, timestamp: Date().addingTimeInterval(-18000))
        ]
        
        return stats
    }
}

// MARK: - Activity Item
struct ActivityItem: Identifiable {
    let id = UUID()
    let description: String
    let icon: String
    let color: Color
    let timestamp: Date
}

#Preview {
    AdminPlatformStatsView()
        .environmentObject(APIService())
} 