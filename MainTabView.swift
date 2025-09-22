import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @StateObject private var locationManager = LocationManager()
    @StateObject private var calendarService = CalendarService()
    @State private var selectedTab = 1  // Start with Feed tab (tag 1)
    @State private var showingPasswordSetup = false
    @State private var showingPasswordChange = false
    @State private var isOrganizationAdmin = false
    @State private var forceShowCalendar = false
    
    private var isCreatorAccount: Bool {
        authManager.currentUser?.email == "jed@onetrack-consulting.com"
    }
    
    private var tabs: some View {
        Group {
            MapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(0)

            IncidentFeedView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Feed")
                }
                .tag(1)

            MyAlertsView()
                .tabItem {
                    Image(systemName: "bell.badge")
                    Text("My Alerts")
                }
                .tag(2)
        }
    }
    
    private var creatorTabs: some View {
        Group {
            DiscoverOrganizationsView()
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Discover")
                }
                .tag(3)
            
            CreatorRequestsView()
                .tabItem {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Requests")
                }
                .tag(4)
            
            GroupInvitationView()
                .tabItem {
                    Image(systemName: "envelope")
                    Text("Invitations")
                }
                .tag(5)
            
            // Calendar tab for organization admins
            if isOrganizationAdmin || forceShowCalendar {
                CalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(7)
            } else {
                // Debug: Show why calendar tab is not showing
                Text("No Calendar - Admin: \(isOrganizationAdmin)")
                    .tabItem {
                        Image(systemName: "questionmark.circle")
                        Text("Debug")
                    }
                    .tag(99)
            }
            
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(6)
        }
    }
    
    private var regularTabs: some View {
        Group {
            DiscoverOrganizationsView()
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Discover")
                }
                .tag(3)
            
            GroupInvitationView()
                .tabItem {
                    Image(systemName: "envelope")
                    Text("Invitations")
                }
                .tag(4)
            
            // Calendar tab for organization admins
            if isOrganizationAdmin || forceShowCalendar {
                CalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(6)
            } else {
                // Debug: Show why calendar tab is not showing
                Text("No Calendar - Admin: \(isOrganizationAdmin)")
                    .tabItem {
                        Image(systemName: "questionmark.circle")
                        Text("Debug")
                    }
                    .tag(98)
            }
            
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(5)
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            tabs
            if isCreatorAccount {
                creatorTabs
            } else {
                regularTabs
            }
        }
        .environmentObject(locationManager)
        .environmentObject(calendarService)
        .onAppear {
            // Request location permissions when app launches
            locationManager.requestLocationPermission()
            print("🎉 Chimeo app loaded successfully!")
            print("🔍 MainTabView: isCreatorAccount = \(isCreatorAccount)")
            print("🔍 MainTabView: isOrganizationAdmin = \(isOrganizationAdmin)")
            
            // Check if user is an organization admin
            Task {
                await checkAdminStatus()
                // If not admin, try to add user as admin to their organization
                if !isOrganizationAdmin {
                    await addUserAsAdminToOrganization()
                }
            }
        }
        .overlay(
            // Debug overlay to show admin status
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Admin: \(isOrganizationAdmin ? "YES" : "NO")")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isOrganizationAdmin ? Color.green : Color.red)
                            .cornerRadius(8)
                        
                        Text("Creator: \(isCreatorAccount ? "YES" : "NO")")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isCreatorAccount ? Color.blue : Color.gray)
                            .cornerRadius(8)
                        
                        Button("Check Admin") {
                            Task {
                                await checkAdminStatus()
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                        
                        Button("Force Calendar") {
                            forceShowCalendar.toggle()
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(forceShowCalendar ? Color.green : Color.purple)
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100) // Above tab bar
                }
            }
        )
    }
    
    // MARK: - Admin Status Checking
    private func checkAdminStatus() async {
        print("🔐 MainTabView: Starting admin status check...")
        guard let userId = authManager.currentUser?.id else {
            print("🔐 MainTabView: No user ID found, setting admin status to false")
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
            return
        }
        print("🔐 MainTabView: User ID: \(userId)")
        
        do {
            // Check if user is admin of any organization
            let db = Firestore.firestore()
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            
            print("🔐 MainTabView: Found \(orgsSnapshot.documents.count) organizations to check")
            
            var isAdmin = false
            for orgDoc in orgsSnapshot.documents {
                let orgData = orgDoc.data()
                let orgName = orgData["name"] as? String ?? "Unknown"
                if let adminIds = orgData["adminIds"] as? [String: Bool] {
                    print("🔐 MainTabView: Organization '\(orgName)' has admin IDs: \(adminIds)")
                    if adminIds[userId] == true {
                        print("🔐 MainTabView: ✅ User is admin of '\(orgName)'")
                        isAdmin = true
                        break
                    }
                } else {
                    print("🔐 MainTabView: Organization '\(orgName)' has no adminIds field or wrong format")
                }
            }
            
            await MainActor.run {
                self.isOrganizationAdmin = isAdmin
                print("🔐 MainTabView: User admin status: \(isAdmin ? "Admin" : "Not admin")")
                print("🔐 MainTabView: isOrganizationAdmin state updated to: \(self.isOrganizationAdmin)")
            }
        } catch {
            print("❌ MainTabView: Error checking admin status: \(error)")
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
        }
    }
    
    // MARK: - Add User as Admin
    private func addUserAsAdminToOrganization() async {
        guard let userId = authManager.currentUser?.id else {
            print("🔐 MainTabView: No user ID for adding as admin")
            return
        }
        
        print("🔐 MainTabView: Attempting to add user as admin to organization...")
        
        do {
            let db = Firestore.firestore()
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            
            for orgDoc in orgsSnapshot.documents {
                let orgData = orgDoc.data()
                let orgName = orgData["name"] as? String ?? "Unknown"
                
                // Check if this organization has no adminIds or empty adminIds
                let currentAdminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
                
                if currentAdminIds.isEmpty {
                    print("🔐 MainTabView: Adding user as admin to '\(orgName)'")
                    
                    // Add user as admin
                    try await db.collection("organizations").document(orgDoc.documentID).updateData([
                        "adminIds": [userId: true]
                    ])
                    
                    print("🔐 MainTabView: ✅ Successfully added user as admin to '\(orgName)'")
                    
                    // Update local admin status
                    await MainActor.run {
                        self.isOrganizationAdmin = true
                        print("🔐 MainTabView: isOrganizationAdmin set to true after adding user as admin")
                    }
                    
                    break // Only add to one organization
                }
            }
        } catch {
            print("❌ MainTabView: Error adding user as admin: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
