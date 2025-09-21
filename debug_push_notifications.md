# Push Notification Debug Guide

## Current FCM Token
Your FCM token: `cLFvlpquB0-ErL-6Azo-Zq:APA91bHi6lqJhGLrfpTGTNQHtiRt-Hw_YgLlZFaIL9DPyn1-UtR42HZ69YfJjqcnm4RAHF95mc4qBzrAq4s5hA6cZwnGs7ue4MYJAU5SKaMuxG_9OOeHV3U`

## Potential Issues Identified

### 1. **APNS Environment Mismatch**
- **Issue**: Your entitlements show `aps-environment: development` but you might be testing on a production build
- **Solution**: Ensure you're testing on a development build or update entitlements for production

### 2. **FCM Token Registration Issues**
- **Issue**: Multiple token registration methods that might conflict
- **Current Setup**: 
  - `NotificationManager` registers tokens
  - `APIService` has its own registration
  - `LocalAlertApp` has auto-registration
- **Solution**: Consolidate to one registration method

### 3. **Firebase Configuration**
- **Issue**: `FirebaseAppDelegateProxyEnabled: false` in Info.plist
- **Impact**: This disables automatic FCM handling
- **Solution**: Set to `true` or handle FCM manually (which you're doing)

### 4. **Token Validation**
- **Issue**: Your token length is 163 characters, which is valid
- **Issue**: Need to verify token is properly stored in Firestore

## Debug Steps

### Step 1: Check Token Registration
Run this in your app to verify token registration:

```swift
// Add this to your app for debugging
func debugFCMStatus() {
    let token = UserDefaults.standard.string(forKey: "fcm_token") ?? "No token"
    print("🔍 FCM Debug Status:")
    print("   - Stored Token: \(token.prefix(20))...")
    print("   - Token Length: \(token.count)")
    print("   - Current User: \(Auth.auth().currentUser?.uid ?? "Not logged in")")
    
    // Check Firestore
    if let userId = Auth.auth().currentUser?.uid {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { doc, error in
            if let doc = doc, doc.exists {
                let data = doc.data() ?? [:]
                let storedToken = data["fcmToken"] as? String ?? "No token in Firestore"
                print("   - Firestore Token: \(storedToken.prefix(20))...")
                print("   - Tokens Match: \(token == storedToken)")
            } else {
                print("   - Firestore Error: \(error?.localizedDescription ?? "Document not found")")
            }
        }
    }
}
```

### Step 2: Test with Firebase Functions
Use the test function to send a notification:

```bash
# In Firebase Functions directory
firebase functions:shell

# Then call the test function
testFCMNotification({
  userId: "YOUR_USER_ID",
  title: "Test Notification",
  body: "This is a test from Firebase Functions"
})
```

### Step 3: Check Notification Permissions
```swift
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("🔔 Notification Settings:")
    print("   - Authorization: \(settings.authorizationStatus.rawValue)")
    print("   - Alert Setting: \(settings.alertSetting.rawValue)")
    print("   - Sound Setting: \(settings.soundSetting.rawValue)")
    print("   - Badge Setting: \(settings.badgeSetting.rawValue)")
}
```

## Quick Fixes to Try

### Fix 1: Enable Firebase App Delegate Proxy
Update your `Info.plist`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<true/>
```

### Fix 2: Simplify FCM Token Registration
Remove duplicate registration methods and use only one:

```swift
// In ChimeoApp.swift, simplify the FCM setup
private func setupFirebaseMessaging() {
    print("🔥 Setting up Firebase Cloud Messaging...")
    
    // Set the delegate
    Messaging.messaging().delegate = FCMDelegate()
    
    // Request permissions and get token
    Task {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                // Get FCM token
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("❌ Error getting FCM token: \(error)")
                    } else if let token = token {
                        print("✅ FCM token received: \(token)")
                        // Register with user profile
                        Task {
                            await self.registerFCMTokenWithUser(token)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error requesting permissions: \(error)")
        }
    }
}
```

### Fix 3: Test with Simple Notification
Add this test function to your app:

```swift
func sendTestNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Test Notification"
    content.body = "This is a local test notification"
    content.sound = .default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("❌ Test notification failed: \(error)")
        } else {
            print("✅ Test notification scheduled")
        }
    }
}
```

## Next Steps

1. **Run the debug function** to check token registration
2. **Test local notifications** to verify permissions work
3. **Use Firebase Functions test** to verify FCM works
4. **Check Firebase Console** for any error logs
5. **Verify APNS certificates** are properly configured

## Common Issues

- **Development vs Production**: Make sure you're using the right APNS environment
- **Token Expiration**: FCM tokens can expire and need refresh
- **Network Issues**: FCM requires internet connection
- **App State**: Notifications might not show if app is in foreground without proper handling
- **iOS Simulator**: Push notifications don't work on iOS Simulator, only on physical devices

Let me know what the debug output shows and we can narrow down the issue!