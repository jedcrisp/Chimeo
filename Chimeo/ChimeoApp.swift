//
//  ChimeoApp.swift
//  Chimeo
//
//  Created by Jed Crisp on 8/15/25.
//

import SwiftUI
import Firebase

@main
struct ChimeoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var weatherNotificationManager = WeatherNotificationManager()
    @StateObject private var weatherService: WeatherService
    @StateObject private var apiService = APIService()
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var serviceCoordinator = ServiceCoordinator()
    @StateObject private var notificationService = iOSNotificationService()
    @StateObject private var scheduledAlertExecutionService = ScheduledAlertExecutionService()
    @State private var hasError = false
    @State private var errorMessage = ""

    init() {
        // Configure Firebase
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
                .environmentObject(scheduledAlertExecutionService)
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
                        
                        // Start scheduled alert execution service
                        scheduledAlertExecutionService.startBackgroundExecution()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear app badge when app becomes active
                    notificationManager.handleAppDidBecomeActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // Update badge count when app goes to background
                    notificationManager.handleAppWillResignActive()
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
                    
                    // Register for remote notifications
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                        print("📱 Registered for remote notifications")
                    }
                    
                    // Get FCM token
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("❌ Error getting FCM token: \(error)")
                        } else if let token = token {
                            print("✅ FCM token received: \(token)")
                            self.notificationManager.updateFCMToken(token)
                        }
                    }
                } else {
                    print("❌ Notification permissions denied")
                }
            } catch {
                print("❌ Error requesting notification permissions: \(error)")
            }
        }
    }
    
    // MARK: - User Profile Notification Observer
    private func setupUserProfileNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserProfileSaved"),
            object: nil,
            queue: .main
        ) { _ in
            print("📱 User profile saved - checking for pending FCM token")
            
            // Check if there's a pending FCM token to register
            if let pendingToken = UserDefaults.standard.string(forKey: "pending_fcm_token") {
                print("📱 Found pending FCM token, registering with user profile")
                Task {
                    await self.notificationManager.registerFCMTokenWithUser(pendingToken)
                }
            }
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

// MARK: - FCM Delegate
class FCMDelegate: NSObject, MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM registration token: \(fcmToken ?? "nil")")
        
        if let token = fcmToken {
            // Update the notification manager with the new token
            NotificationCenter.default.post(
                name: .fcmTokenReceived,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
}
