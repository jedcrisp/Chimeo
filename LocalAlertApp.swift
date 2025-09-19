import SwiftUI
import CoreLocation
import UserNotifications
import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseDatabase
import FirebaseMessaging
import FirebaseFirestore
import UIKit

// Weather Notification Manager - temporarily inline to resolve compilation issues
class WeatherNotificationManager: ObservableObject {
    @Published var hasPermission = false
    @Published var criticalAlertsEnabled = false
    @Published var weatherAlertsEnabled = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init() {
        checkPermissionStatus()
        loadSettings()
    }
    
    func requestPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.hasPermission = granted
                if granted {
                    self.setupNotificationCategories()
                }
            }
            
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }
    
    private func checkPermissionStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func setupNotificationCategories() {
        // Weather alert categories
        let criticalWeatherCategory = UNNotificationCategory(
            identifier: "CRITICAL_WEATHER",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_DETAILS",
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "SHARE_ALERT",
                    title: "Share",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let weatherAlertCategory = UNNotificationCategory(
            identifier: "WEATHER_ALERT",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_DETAILS",
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        notificationCenter.setNotificationCategories([
            criticalWeatherCategory,
            weatherAlertCategory
        ])
    }
    
    // Simplified methods for now - will be enhanced when weather models are added
    func scheduleWeatherAlert(_ alert: String) {
        guard weatherAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weather Alert"
        content.body = alert
        content.sound = .default
        content.categoryIdentifier = "WEATHER_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "weather_alert_\(UUID().uuidString)", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling weather alert: \(error)")
            } else {
                print("Weather alert scheduled: \(alert)")
            }
        }
    }
    
    func sendImmediateNotification(for alert: String) {
        guard weatherAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Severe Weather Alert"
        content.body = alert
        content.sound = .defaultCritical
        content.categoryIdentifier = "CRITICAL_WEATHER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "immediate_weather_alert_\(UUID().uuidString)", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending immediate weather alert: \(error)")
            } else {
                print("Immediate weather alert sent: \(alert)")
            }
        }
    }
    
    func cancelWeatherAlert(_ alertId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [
            "weather_alert_\(alertId)",
            "immediate_weather_alert_\(alertId)"
        ])
    }
    
    func cancelAllWeatherAlerts() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    private func loadSettings() {
        // Load saved settings from UserDefaults with defaults (DISABLED by default)
        weatherAlertsEnabled = UserDefaults.standard.object(forKey: "weatherAlertsEnabled") as? Bool ?? false
        criticalAlertsEnabled = UserDefaults.standard.object(forKey: "criticalAlertsEnabled") as? Bool ?? false
    }
    
    func monitorWeatherAlerts(_ alerts: [String]) {
        guard weatherAlertsEnabled else { return }
        
        // Cancel existing notifications
        cancelAllWeatherAlerts()
        
        // Schedule new notifications for each alert
        for alert in alerts {
            if alert.lowercased().contains("warning") || alert.lowercased().contains("emergency") {
                sendImmediateNotification(for: alert)
            } else {
                scheduleWeatherAlert(alert)
            }
        }
    }
    
    func updateSettings() {
        // Save current settings to UserDefaults
        UserDefaults.standard.set(weatherAlertsEnabled, forKey: "weatherAlertsEnabled")
        UserDefaults.standard.set(criticalAlertsEnabled, forKey: "criticalAlertsEnabled")
        print("Weather settings updated: weather=\(weatherAlertsEnabled), critical=\(criticalAlertsEnabled)")
    }
}

// Weather Service - temporarily inline to resolve compilation issues
class WeatherService: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourlyForecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var weatherAlerts: [String] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    
    let locationManager: LocationManager
    let weatherNotificationManager: WeatherNotificationManager
    // DISABLED: Automatic weather updates disabled
    // private let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    
    // OpenWeatherMap API key (you'll need to get a free one)
    private let openWeatherAPIKey = "YOUR_API_KEY_HERE" // Replace with your actual API key
    
    init(locationManager: LocationManager, weatherNotificationManager: WeatherNotificationManager) {
        self.locationManager = locationManager
        self.weatherNotificationManager = weatherNotificationManager
        // setupTimer() // DISABLED: No automatic weather updates
    }
    
    private func setupTimer() {
        // DISABLED: Automatic weather notifications disabled
        // timer
        //     .sink { [weak self] _ in
        //         self?.refreshWeatherData()
        //     }
        //     .store(in: &cancellables)
    }
    
    func refreshWeatherData() {
        print("Weather data refresh triggered")
        lastUpdated = Date()
        
        // Fetch real weather data and alerts
        Task {
            await fetchCurrentWeather()
            await fetchWeatherForecast()
            await fetchWeatherAlerts()
        }
    }
    
    private func fetchCurrentWeather() async {
        guard let location = locationManager.currentLocation else {
            print("No location available for current weather")
            return
        }
        
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&appid=\(openWeatherAPIKey)&units=imperial"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL for current weather")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            
            await MainActor.run {
                self.currentWeather = weatherResponse.main
                print("Fetched current weather: \(weatherResponse.main.temperature)°F")
            }
        } catch {
            print("Error fetching current weather: \(error)")
        }
    }
    
    private func fetchWeatherForecast() async {
        guard let location = locationManager.currentLocation else {
            print("No location available for weather forecast")
            return
        }
        
        let urlString = "https://api.openweathermap.org/data/2.5/onecall?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&appid=\(openWeatherAPIKey)&units=imperial&exclude=minutely"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL for weather forecast")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let forecastResponse = try JSONDecoder().decode(OpenWeatherForecastResponse.self, from: data)
            
            await MainActor.run {
                self.hourlyForecast = forecastResponse.hourly
                self.dailyForecast = forecastResponse.daily
                print("Fetched weather forecast: \(forecastResponse.hourly.count) hourly, \(forecastResponse.daily.count) daily")
            }
        } catch {
            print("Error fetching weather forecast: \(error)")
        }
    }
    
    private func fetchWeatherAlerts() async {
        // First, fetch alerts for current location
        var currentLocationAlerts: [String] = []
        if let location = locationManager.currentLocation {
            currentLocationAlerts = await fetchAlertsForLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: "Current Location"
            )
        }
        
        // Then, fetch alerts for followed locations
        var followedLocationAlerts: [String] = []
        let followedLocations = getFollowedLocations()
        for location in followedLocations where location.isEnabled {
            let (lat, lon) = getCoordinatesForLocation(location)
            let locationAlerts = await fetchAlertsForLocation(
                latitude: lat,
                longitude: lon,
                locationName: location.name
            )
            followedLocationAlerts.append(contentsOf: locationAlerts)
        }
        
        // Capture the values before the async context
        let finalAlerts = currentLocationAlerts + followedLocationAlerts
        
        await MainActor.run {
            // Use the captured values
            self.weatherAlerts = Array(Set(finalAlerts))
            self.lastUpdated = Date()
            print("Fetched \(self.weatherAlerts.count) weather alerts from all locations")
            
            // DISABLED: Weather notifications disabled
            // weatherNotificationManager.monitorWeatherAlerts(self.weatherAlerts)
        }
    }
    
    private func fetchAlertsForLocation(latitude: Double, longitude: Double, locationName: String) async -> [String] {
        let urlString = "https://api.weather.gov/alerts/active?point=\(latitude),\(longitude)"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL for weather alerts for \(locationName)")
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let alertResponse = try JSONDecoder().decode(NOAAAlertResponse.self, from: data)
            
            // Convert NOAA alerts to our format with location prefix
            return alertResponse.features.map { feature in
                "[\(locationName)] \(feature.properties.event) - \(feature.properties.areaDesc)"
            }
        } catch {
            print("Error fetching weather alerts for \(locationName): \(error)")
            return []
        }
    }
    
    private func getFollowedLocations() -> [FollowedLocation] {
        // Load followed locations from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "followedWeatherLocations"),
           let locations = try? JSONDecoder().decode([FollowedLocation].self, from: data) {
            return locations
        }
        return []
    }
    
    private func getCoordinatesForLocation(_ location: FollowedLocation) -> (Double, Double) {
        // This is a simplified version - in a real app, you'd use a geocoding service
        // For now, return some default coordinates for common Texas cities
        let value = location.value.lowercased()
        
        if value.contains("wylie") {
            return (33.0151, -96.5389)
        } else if value.contains("garland") {
            return (32.9126, -96.6389)
        } else if value.contains("southlake") {
            return (32.9412, -97.1342)
        } else if value.contains("plano") {
            return (33.0198, -96.6989)
        } else if value.contains("dallas") {
            return (32.7767, -96.7970)
        } else if value.contains("fort worth") {
            return (32.7555, -97.3308)
        } else if value.contains("allen") {
            return (33.1032, -96.6705)
        } else if value.contains("mckinney") {
            return (33.1972, -96.6397)
        } else if value.contains("frisco") {
            return (33.1507, -96.8236)
        } else {
            // Default to Dallas coordinates
            return (32.7767, -96.7970)
        }
    }
    
    func getActiveAlerts() -> [String] {
        return weatherAlerts
    }
    
    func getCriticalAlerts() -> [String] {
        return weatherAlerts
    }
    
    // Add mock weather alerts for testing
    func addMockAlert() {
        let mockAlert = "Severe Thunderstorm Warning - Your Area"
        if !weatherAlerts.contains(mockAlert) {
            weatherAlerts.append(mockAlert)
            lastUpdated = Date()
        }
    }
    
    // Remove mock alerts
    func clearMockAlerts() {
        weatherAlerts.removeAll()
        lastUpdated = Date()
    }
    

    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Followed Location Model
struct FollowedLocation: Codable, Identifiable {
    let id: String
    let name: String
    let type: WeatherLocationType
    let value: String
    var isEnabled: Bool
    
    init(name: String, type: WeatherLocationType, value: String) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.value = value
        self.isEnabled = true
    }
}

enum WeatherLocationType: String, Codable, CaseIterable {
    case city = "city"
    case zipCode = "zipCode"
    case coordinates = "coordinates"
    
    var displayName: String {
        switch self {
        case .city: return "City"
        case .zipCode: return "Zip Code"
        case .coordinates: return "Coordinates"
        }
    }
    
    var icon: String {
        switch self {
        case .city: return "building.2"
        case .zipCode: return "mappin.and.ellipse"
        case .coordinates: return "location"
        }
    }
}

// MARK: - Weather Data Models
struct CurrentWeather: Codable {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let pressure: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature = "temp"
        case feelsLike = "feels_like"
        case humidity, pressure
    }
}

struct WeatherForecast: Codable {
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

struct HourlyForecast: Codable, Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let weather: [WeatherDescription]
    let precipitation: Double
    let humidity: Int
    let windSpeed: Double
    
    enum CodingKeys: String, CodingKey {
        case time = "dt"
        case temperature = "temp"
        case weather
        case precipitation = "pop"
        case humidity
        case windSpeed = "wind_speed"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .time)
        time = Date(timeIntervalSince1970: timestamp)
        
        temperature = try container.decode(Double.self, forKey: .temperature)
        weather = try container.decode([WeatherDescription].self, forKey: .weather)
        precipitation = try container.decode(Double.self, forKey: .precipitation)
        humidity = try container.decode(Int.self, forKey: .humidity)
        windSpeed = try container.decode(Double.self, forKey: .windSpeed)
    }
}

struct DailyForecast: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let temp: TempRange
    let weather: [WeatherDescription]
    let precipitation: Double
    let humidity: Int
    let windSpeed: Double
    
    enum CodingKeys: String, CodingKey {
        case date = "dt"
        case temp
        case weather
        case precipitation = "pop"
        case humidity
        case windSpeed = "wind_speed"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .date)
        date = Date(timeIntervalSince1970: timestamp)
        
        temp = try container.decode(TempRange.self, forKey: .temp)
        weather = try container.decode([WeatherDescription].self, forKey: .weather)
        precipitation = try container.decode(Double.self, forKey: .precipitation)
        humidity = try container.decode(Int.self, forKey: .humidity)
        windSpeed = try container.decode(Double.self, forKey: .windSpeed)
    }
}

struct TempRange: Codable {
    let min: Double
    let max: Double
}

// MARK: - OpenWeatherMap API Models
struct OpenWeatherResponse: Codable {
    let main: CurrentWeather
    let weather: [WeatherDescription]
    let wind: Wind
    let visibility: Int
    let dt: TimeInterval
}

struct WeatherDescription: Codable {
    let main: String
    let description: String
    let icon: String
}

struct Wind: Codable {
    let speed: Double
    let deg: Int
}

struct OpenWeatherForecastResponse: Codable {
    let hourly: [HourlyForecast]
    let daily: [DailyForecast]
}

// MARK: - NOAA Weather API Models
struct NOAAAlertResponse: Codable {
    let features: [NOAAAlertFeature]
}

struct NOAAAlertFeature: Codable {
    let properties: NOAAAlertProperties
}

struct NOAAAlertProperties: Codable {
    let event: String
    let areaDesc: String
    let severity: String
    let urgency: String
    let certainty: String
    let effective: String
    let expires: String
    let description: String
    let instruction: String?
}



// MARK: - Firebase Cloud Messaging Delegate
class FCMDelegate: NSObject, MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM Registration Token updated: \(fcmToken ?? "nil")")
        
        if let token = fcmToken {
            // Store the token for later use
            UserDefaults.standard.set(token, forKey: "fcm_token")
            print("✅ FCM token stored in UserDefaults")
            
            // Automatically register the updated token
            Task {
                await autoRegisterFCMToken(token)
            }
        }
    }
    
    private func autoRegisterFCMToken(_ token: String) async {
        print("🔄 Auto-registering updated FCM token...")
        
        // Get current user from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "currentUser"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            print("❌ No current user found for FCM token update")
            return
        }
        
        // Update user's FCM token in Firestore
        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(user.id).updateData([
                "fcmToken": token,
                "lastTokenUpdate": FieldValue.serverTimestamp()
            ])
            print("✅ FCM token automatically updated for user: \(user.id)")
        } catch {
            print("❌ Failed to auto-update FCM token: \(error)")
        }
    }
    

}

// MARK: - App Delegate for APNS
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNS Device Token received")
        
        // Set APNS token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNS token set for Firebase Messaging")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

@main
struct LocalAlertApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var weatherNotificationManager = WeatherNotificationManager()
    @StateObject private var weatherService: WeatherService
    @StateObject private var apiService = APIService()
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var serviceCoordinator = ServiceCoordinator()
    @StateObject private var notificationService = iOSNotificationService()
    @State private var hasError = false
    @State private var errorMessage = ""

    
    init() {
        // Configure Firebase - testing if GoogleService-Info.plist is now accessible from Resources build phase
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        
        // Configure Firebase Cloud Messaging
        Messaging.messaging().delegate = nil // Will be set in onAppear
        
        let locationManager = LocationManager()
        let weatherNotificationManager = WeatherNotificationManager()
        
        self._locationManager = StateObject(wrappedValue: locationManager)
        self._weatherNotificationManager = StateObject(wrappedValue: weatherNotificationManager)
        self._weatherService = StateObject(wrappedValue: WeatherService(locationManager: locationManager, weatherNotificationManager: weatherNotificationManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationManager)
                .environmentObject(weatherNotificationManager)
                .environmentObject(apiService)
                .environmentObject(biometricAuthManager)
                .environmentObject(serviceCoordinator)
                .environmentObject(notificationService)
                .preferredColorScheme(.light)
                .onAppear {
                    // Add safety delay and error handling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Request notification permissions on app launch
                        notificationManager.requestPermissions { granted in
                            print("Notification permissions granted: \(granted)")
                        }
                        notificationManager.setupNotificationCategories()
                        weatherNotificationManager.requestPermissions()
                        
                        // Setup Firebase Cloud Messaging
                        setupFirebaseMessaging()
                        
                        // Listen for user profile saves to register pending FCM tokens
                        setupUserProfileNotificationObserver()
                        
                        // Clear any existing weather notifications
                        weatherNotificationManager.cancelAllWeatherAlerts()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear badge when app becomes active
                    notificationManager.handleAppDidBecomeActive()
                    
                    // Check if there's a pending alert to open from notification
                    if let pendingAlertId = UserDefaults.standard.string(forKey: "pendingAlertToOpen") {
                        print("📱 Opening pending alert: \(pendingAlertId)")
                        // Post notification to open the alert in the feed
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenAlertInFeed"),
                            object: nil,
                            userInfo: ["alertId": pendingAlertId]
                        )
                        // Clear the pending alert
                        UserDefaults.standard.removeObject(forKey: "pendingAlertToOpen")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Update badge when app goes to background
                    notificationManager.handleAppWillResignActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenAlertFromNotification"))) { notification in
                    // Handle opening alert from notification tap
                    if let alertId = notification.userInfo?["alertId"] as? String {
                        print("📱 Opening alert from notification: \(alertId)")
                        // Store the alert ID to open when the app becomes active
                        UserDefaults.standard.set(alertId, forKey: "pendingAlertToOpen")
                    }
                }
                .alert("Initialization Error", isPresented: $hasError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
        }
    }
    
    // MARK: - Firebase Cloud Messaging Setup
    private func setupFirebaseMessaging() {
        print("🔥 Setting up Firebase Cloud Messaging...")
        
        // Set the delegate
        let fcmDelegate = FCMDelegate()
        Messaging.messaging().delegate = fcmDelegate
        
        // Use the NotificationManager for handling notifications
        UNUserNotificationCenter.current().delegate = notificationManager
        
        // Request notification permissions and register for remote notifications
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                
                if granted {
                    print("✅ Notification permissions granted")
                    
                    // Register for remote notifications on main thread
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                        print("📱 Registered for remote notifications (APNS)")
                    }
                    
                    // Wait a moment for APNS token, then request FCM token
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    // Now request FCM token using async/await
                    do {
                        let token = try await Messaging.messaging().token()
                        if !token.isEmpty {
                            print("✅ FCM token received: \(token)")
                            
                            // Update the NotificationManager with the token
                            notificationManager.updateFCMToken(token)
                            
                            // Automatically register the token with the user profile
                            Task {
                                await self.autoRegisterFCMToken(token)
                            }
                        } else {
                            print("⚠️ FCM token is empty, skipping registration")
                        }
                    } catch {
                        print("❌ Error getting FCM token: \(error)")
                    }
                } else {
                    print("❌ Notification permissions denied")
                }
            } catch {
                print("❌ Error requesting notification permissions: \(error)")
                // Don't crash, continue without notifications
            }
        }
        
        print("✅ Firebase Cloud Messaging setup initiated")
    }
    
    // MARK: - Auto FCM Token Registration
    private func autoRegisterFCMToken(_ token: String) async {
        print("🔥 Auto-registering FCM token...")
        
        // Get current user from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "currentUser"),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            print("❌ No current user found for auto FCM registration")
            print("   This is normal if user hasn't signed in yet")
            print("   FCM token will be registered when user signs in")
            
            // Store the token for later registration
            UserDefaults.standard.set(token, forKey: "pending_fcm_token")
            print("📱 FCM token stored for later registration")
            return
        }
        
        print("✅ Current user found: \(user.name ?? "Unknown") (ID: \(user.id))")
        
        // BULLETPROOF: Ensure user document exists before updating FCM token
        print("🔧 BULLETPROOF: Ensuring user document exists...")
        await ensureUserDocumentExists(userId: user.id, email: user.email ?? "", name: user.name ?? "User")
        
        // Update user's FCM token in Firestore
        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(user.id).updateData([
                "fcmToken": token,
                "lastTokenUpdate": FieldValue.serverTimestamp()
            ])
            print("✅ FCM token automatically registered for user: \(user.id)")
            
            // Clear any pending token
            UserDefaults.standard.removeObject(forKey: "pending_fcm_token")
        } catch {
            print("❌ Failed to auto-register FCM token: \(error)")
        }
    }
    
    // MARK: - Bulletproof User Document Creation
    private func ensureUserDocumentExists(userId: String, email: String, name: String) async {
        print("🔧 BULLETPROOF: Ensuring user document exists for: \(userId)")
        print("   Email: \(email)")
        print("   Name: \(name)")
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // Get FCM token (or empty string if not available)
        let fcmToken = UserDefaults.standard.string(forKey: "fcm_token") ?? ""
        print("   FCM Token available: \(fcmToken.isEmpty ? "NO" : "YES")")
        
        // Create user document with all necessary fields
        let userData: [String: Any] = [
            "id": userId,
            "email": email,
            "name": name,
            "displayName": name,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isAdmin": false,
            "isOrganizationAdmin": false,
            "fcmToken": fcmToken,
            "alertsEnabled": true,
            "uid": userId,
            "lastSignIn": FieldValue.serverTimestamp(),
            "signInCount": 1
        ]
        
        do {
            // Use setData with merge: true to update existing or create new
            try await userRef.setData(userData, merge: true)
            print("✅ BULLETPROOF: User document created/updated successfully")
            
            // Verify the document exists
            let verifyDoc = try await userRef.getDocument()
            if verifyDoc.exists {
                print("✅ VERIFICATION: User document confirmed to exist")
                let data = verifyDoc.data()
                print("📋 Document fields: \(data?.keys.joined(separator: ", ") ?? "none")")
            } else {
                print("❌ VERIFICATION FAILED: Document still doesn't exist!")
            }
            
        } catch {
            print("❌ BULLETPROOF FAILED: Could not create user document: \(error)")
            print("🚨 This is critical - user will not receive push notifications!")
        }
    }
    
    // MARK: - Register Pending FCM Token
    func registerPendingFCMToken() async {
        guard let pendingToken = UserDefaults.standard.string(forKey: "pending_fcm_token") else {
            print("📱 No pending FCM token to register")
            return
        }
        
        print("📱 Registering pending FCM token...")
        await autoRegisterFCMToken(pendingToken)
    }
    
    // MARK: - User Profile Notification Observer
    private func setupUserProfileNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .userProfileSaved,
            object: nil,
            queue: .main
        ) { notification in
            print("📱 User profile saved notification received")
            
            // Check if there's a pending FCM token to register
            if let pendingToken = UserDefaults.standard.string(forKey: "pending_fcm_token") {
                print("📱 Found pending FCM token, registering now...")
                Task {
                    await self.autoRegisterFCMToken(pendingToken)
                }
            } else {
                print("📱 No pending FCM token found")
            }
        }
        
        print("📱 User profile notification observer set up")
    }
} 
