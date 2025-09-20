import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var apiService = APIService()
    @StateObject private var calendarService = CalendarService()
    
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
            
            IncidentFeedView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Feed")
                }
            
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            MyAlertsView()
                .tabItem {
                    Image(systemName: "bell.badge")
                    Text("My Alerts")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
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
