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
                .onAppear {
                    setupNotificationObservers()
                }
                .alert("Error", isPresented: $hasError) {
                    Button("OK") {
                        hasError = false
                    }
                } message: {
                    Text(errorMessage)
                }
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for user profile saved notifications
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
    
    private func autoRegisterFCMToken(_ token: String) async {
        print("📱 Auto-registering FCM token: \(token.prefix(20))...")
        
        // Get current user
        guard let user = Auth.auth().currentUser else {
            print("❌ No authenticated user found for auto FCM registration")
            return
        }
        
        print("✅ Found Firebase Auth user: \(user.uid)")
        
        // Update user's FCM token in Firestore
        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(user.uid).updateData([
                "fcmToken": token,
                "lastTokenUpdate": FieldValue.serverTimestamp()
            ])
            print("✅ FCM token automatically updated for user: \(user.uid)")
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

// MARK: - Notification Names
// userProfileSaved is defined in AuthenticationService.swift