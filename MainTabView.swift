import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var apiService = APIService()
    @StateObject private var calendarService = CalendarService()
    @State private var selectedTab = 1  // Start with Feed tab (tag 1)
    @State private var showingPasswordSetup = false
    @State private var showingPasswordChange = false
    
    private var isCreatorAccount: Bool {
        apiService.currentUser?.email == "jed@onetrack-consulting.com"
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
            
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(5)
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
            
            SettingsTabView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
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
        .environmentObject(apiService)
        .environmentObject(calendarService)
        .onAppear {
            // Request location permissions when app launches
            locationManager.requestLocationPermission()
            print("🎉 Chimeo app loaded successfully!")
        }
    }
}

#Preview {
    ContentView()
}
