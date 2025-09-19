import Foundation
import UserNotifications
import SwiftUI
import CoreLocation

// Import weather models



class WeatherNotificationManager: ObservableObject {
    @Published var hasPermission = false
    @Published var criticalAlertsEnabled = true
    @Published var weatherAlertsEnabled = true
    
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
    
    func checkPermissionStatus() {
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
    
    func scheduleWeatherAlert(_ alert: String) {
        // Temporarily simplified - will be restored when weather models are added
        print("Weather alert scheduling temporarily disabled")
    }
    
    func sendImmediateNotification(for alert: String) {
        // Temporarily simplified - will be restored when weather models are added
        print("Immediate weather alert notification temporarily disabled")
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
    
    // MARK: - Settings Management
    private func loadSettings() {
        criticalAlertsEnabled = UserDefaults.standard.bool(forKey: "criticalWeatherAlertsOnly")
        weatherAlertsEnabled = UserDefaults.standard.bool(forKey: "weatherAlertsEnabled")
    }
    
    func updateSettings() {
        loadSettings()
    }
    
    // MARK: - Weather Alert Monitoring
    func monitorWeatherAlerts(_ alerts: [String]) {
        // Temporarily simplified - will be restored when weather models are added
        print("Weather alert monitoring temporarily disabled")
    }
    
    // MARK: - Background Refresh
    func handleBackgroundRefresh() {
        // This would be called when the app receives a background refresh
        // In a real app, you'd fetch new weather data here
        print("Background refresh triggered for weather alerts")
    }
}

// MARK: - Notification Delegate
extension WeatherNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification actions
        switch response.actionIdentifier {
        case "VIEW_DETAILS":
            // In a real app, you'd navigate to the weather alert detail view
            print("User tapped View Details for weather alert")
            
        case "SHARE_ALERT":
            // In a real app, you'd share the alert
            print("User tapped Share for weather alert")
            
        case "DISMISS":
            // Dismiss the alert
            if let alertId = userInfo["alertId"] as? String {
                cancelWeatherAlert(alertId)
            }
            
        default:
            break
        }
        
        completionHandler()
    }
}
