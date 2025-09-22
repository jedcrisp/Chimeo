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
            if isOrganizationAdmin {
                CalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(7)
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
            if isOrganizationAdmin {
                CalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(6)
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
            
            // Check if user is an organization admin
            Task {
                await checkAdminStatus()
            }
        }
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
                if let adminIds = orgData["adminIds"] as? [String] {
                    print("🔐 MainTabView: Organization '\(orgName)' has admin IDs: \(adminIds)")
                    if adminIds.contains(userId) {
                        print("🔐 MainTabView: ✅ User is admin of '\(orgName)'")
                        isAdmin = true
                        break
                    }
                } else {
                    print("🔐 MainTabView: Organization '\(orgName)' has no adminIds field")
                }
            }
            
            await MainActor.run {
                self.isOrganizationAdmin = isAdmin
                print("🔐 MainTabView: User admin status: \(isAdmin ? "Admin" : "Not admin")")
            }
        } catch {
            print("❌ MainTabView: Error checking admin status: \(error)")
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
        }
    }
}

#Preview {
    ContentView()
}
