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
    @StateObject private var authManager = SimpleAuthManager()
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var serviceCoordinator: ServiceCoordinator
    @StateObject private var apiService = APIService()
    @State private var hasError = false
    @State private var errorMessage = ""

    init() {
        // Configure Firebase with error handling
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            FirebaseApp.configure()
            print("✅ Firebase configured successfully")
        } else {
            print("❌ GoogleService-Info.plist not found in bundle. Firebase will not be configured.")
            // Continue without Firebase for now
        }
        
        // Configure Firebase Cloud Messaging only if Firebase is available
        if FirebaseApp.app() != nil {
            Messaging.messaging().delegate = nil // Will be set in onAppear
        }
        
        let locationManager = LocationManager()
        let weatherNotificationManager = WeatherNotificationManager()
        
        self._locationManager = StateObject(wrappedValue: locationManager)
        self._weatherNotificationManager = StateObject(wrappedValue: weatherNotificationManager)
        self._weatherService = StateObject(wrappedValue: WeatherService(locationManager: locationManager))
        
        // Initialize SimpleAuthManager first
        let authManager = SimpleAuthManager()
        self._authManager = StateObject(wrappedValue: authManager)
        
        // Initialize ServiceCoordinator with the same SimpleAuthManager instance
        self._serviceCoordinator = StateObject(wrappedValue: ServiceCoordinator(simpleAuthManager: authManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationManager)
                .environmentObject(weatherNotificationManager)
                .environmentObject(authManager)
                .environmentObject(biometricAuthManager)
                .environmentObject(serviceCoordinator)
                .environmentObject(apiService)
                .onAppear {
                    print("🎯 ChimeoApp: ContentView appeared")
                    print("🔐 AuthManager state: isAuthenticated = \(authManager.isAuthenticated)")
                }
                .preferredColorScheme(ColorScheme.light)
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
                        
                        // FCM token registration will be handled by SimpleAuthManager
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear app badge when app becomes active
                    notificationManager.handleAppDidBecomeActive()
                    
                    // Check for pending FCM requests
                    checkForPendingFCMRequests()
                    
                    // FCM token registration will be handled by SimpleAuthManager
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
        
        // Check if Firebase is available
        guard FirebaseApp.app() != nil else {
            print("❌ Firebase not available, skipping FCM setup")
            return
        }
        
        // Set the delegate
        let fcmDelegate = FCMDelegate()
        Messaging.messaging().delegate = fcmDelegate
        
        // Use the NotificationManager for handling notifications
        UNUserNotificationCenter.current().delegate = notificationManager
        
        // Let NotificationManager handle the entire FCM setup to avoid conflicts
        print("🔄 Delegating FCM setup to NotificationManager...")
        notificationManager.registerForPushNotifications()
    }
    
    
    // MARK: - User Profile Notification Observer
    private func setupUserProfileNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserProfileSaved"),
            object: nil,
            queue: .main
        ) { _ in
            print("📱 User profile saved - retrying FCM token registration")
            self.notificationManager.retryFCMTokenRegistration()
        }
        
        // Also listen for user login events
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserLoggedIn"),
            object: nil,
            queue: .main
        ) { _ in
            print("📱 User logged in - retrying FCM token registration")
            self.notificationManager.retryFCMTokenRegistration()
            
            // Also try force registration as a fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("📱 User logged in - force FCM token registration")
                self.notificationManager.forceFCMTokenRegistration()
            }
            
            // If APNS token is not available, wait for it
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if Messaging.messaging().apnsToken == nil {
                    print("📱 APNS token still not available, forcing APNS registration...")
                    self.notificationManager.forceAPNSRegistration()
                    self.notificationManager.waitForAPNSTokenAndRegisterFCM()
                }
            }
        }
    }
    
    // MARK: - Check for Pending FCM Requests
    private func checkForPendingFCMRequests() {
        let hasPendingFCMRequest = UserDefaults.standard.bool(forKey: "pending_fcm_request")
        if hasPendingFCMRequest {
            print("🔄 Found pending FCM request, checking APNS token...")
            
            // Check if APNS token is now available
            if Messaging.messaging().apnsToken != nil {
                print("✅ APNS token is available, requesting FCM token...")
                UserDefaults.standard.removeObject(forKey: "pending_fcm_request")
                
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("❌ Error getting FCM token: \(error)")
                    } else if let token = token {
                        print("✅ FCM token received: \(token)")
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: .fcmTokenReceived,
                                object: nil,
                                userInfo: ["token": token]
                            )
                        }
                    }
                }
            } else {
                print("⏳ APNS token still not available, keeping request pending...")
            }
        }
    }
}

// MARK: - App Delegate for APNS
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNS Device Token received: \(deviceToken.count) bytes")
        
        // Set APNS token for Firebase Messaging only if Firebase is available
        if FirebaseApp.app() != nil {
            Messaging.messaging().apnsToken = deviceToken
            print("✅ APNS token set for Firebase Messaging")
            
            // Let NotificationManager handle FCM token request to avoid conflicts
            print("🔄 APNS token set, NotificationManager will handle FCM token request")
        } else {
            print("❌ Firebase not available, APNS token not set")
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
        print("❌ Error details: \(error.localizedDescription)")
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
