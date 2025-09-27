import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    @EnvironmentObject var authManager: SimpleAuthManager
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var serviceCoordinator: ServiceCoordinator
    @StateObject private var locationManager = LocationManager()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var scheduledAlertService = ScheduledAlertExecutionService()
    @State private var selectedTab = 1  // Start with Feed tab (tag 1)
    @State private var showingPasswordSetup = false
    @State private var showingPasswordChange = false
    @State private var isOrganizationAdmin = false
    @State private var forceShowCalendar = false
    
    private var isCreatorAccount: Bool {
        authManager.currentUser?.email == "jed@chimeo.app"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Map Tab
            MapView()
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(0)

            // Feed Tab
            IncidentFeedView()
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Feed")
                }
                .tag(1)

            // My Alerts Tab
            MyAlertsView()
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: "bell.badge")
                    Text("My Alerts")
                }
                .tag(2)
            
            // Discover Tab
            DiscoverOrganizationsView()
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Discover")
                }
                .tag(3)
            
            // Creator-specific tabs
            if isCreatorAccount {
                CreatorRequestsView()
                    .tabItem {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Requests")
                    }
                    .tag(4)
            }
            
            // Invitations Tab
            GroupInvitationView()
                .environmentObject(authManager)
                .tabItem {
                    Image(systemName: "envelope")
                    Text("Invitations")
                }
                .tag(isCreatorAccount ? 5 : 4)
            
            // Settings Tab
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(isCreatorAccount ? 6 : 5)
            
            // Calendar Tab (for admins and creator)
            if isOrganizationAdmin || forceShowCalendar || isCreatorAccount {
                CalendarView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(7)
            }
        }
        .environmentObject(locationManager)
        .environmentObject(calendarService)
        .onAppear {
            // Request location permissions when app launches
            locationManager.requestLocationPermission()
            
            // Check if user is an organization admin
            Task {
                await checkAdminStatus()
                // If not admin, try to add user as admin to their organization
                if !isOrganizationAdmin {
                    await addUserAsAdminToOrganization()
                }
            }
            
            // Start scheduled alert execution service
            scheduledAlertService.startBackgroundExecution()
        }
    }
    
    // MARK: - Admin Status Checking
    private func checkAdminStatus() async {
        guard let userId = authManager.currentUser?.id else {
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
            return
        }
        
        do {
            // Check if user is admin of any organization
            let db = Firestore.firestore()
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            
            var isAdmin = false
            for orgDoc in orgsSnapshot.documents {
                let orgData = orgDoc.data()
                if let adminIds = orgData["adminIds"] as? [String: Bool] {
                    if adminIds[userId] == true {
                        isAdmin = true
                        break
                    }
                }
            }
            
            await MainActor.run {
                self.isOrganizationAdmin = isAdmin
            }
        } catch {
            await MainActor.run {
                self.isOrganizationAdmin = false
            }
        }
    }
    
    // MARK: - Add User as Admin
    private func addUserAsAdminToOrganization() async {
        guard let userId = authManager.currentUser?.id else {
            return
        }
        
        do {
            let db = Firestore.firestore()
            let orgsSnapshot = try await db.collection("organizations").getDocuments()
            
            for orgDoc in orgsSnapshot.documents {
                let orgData = orgDoc.data()
                
                // Check if this organization has no adminIds or empty adminIds
                let currentAdminIds = orgData["adminIds"] as? [String: Bool] ?? [:]
                
                if currentAdminIds.isEmpty {
                    // Add user as admin
                    try await db.collection("organizations").document(orgDoc.documentID).updateData([
                        "adminIds": [userId: true]
                    ])
                    
                    // Update local admin status
                    await MainActor.run {
                        self.isOrganizationAdmin = true
                    }
                    
                    break // Only add to one organization
                }
            }
        } catch {
            // Silently handle error
        }
    }
}

#Preview {
    ContentView()
}
