# 🔔 iOS Push Notification Debugging Guide

## 🚨 **Problem: External Testers Not Receiving Push Notifications**

### **1. Immediate Checks for Testers**

#### **A. iOS Settings Verification**
- [ ] **Notifications enabled** for your app in iOS Settings
- [ ] **Background App Refresh** enabled for your app
- [ ] **Do Not Disturb** mode disabled
- [ ] **Focus modes** not blocking notifications

#### **B. App Permission Status**
- [ ] **Notification permissions granted** when app first launched
- [ ] **App has notification access** in iOS Settings > Notifications > [Your App]

### **2. FCM Token Verification**

#### **A. Check Firestore Database**
Go to [Firebase Console](https://console.firebase.google.com/project/chimeo-96dfc/firestore/data/users)

Look for your testers' user documents and verify:
- [ ] **fcmToken field exists** and contains a valid token
- [ ] **Token is not empty** or "nil"
- [ ] **Token was updated recently** (within last 24 hours)

#### **B. Check iOS Console Logs**
When testers launch the app, look for these log messages:
```
🔥 FCM Registration Token updated: [TOKEN]
✅ FCM token stored in UserDefaults
✅ FCM token automatically registered for user: [USER_ID]
```

### **3. Common Issues & Solutions**

#### **A. Development vs Production Builds**
- **TestFlight builds** need production APNS certificates
- **Development builds** need development APNS certificates
- **Verify provisioning profile** matches build type

#### **B. FCM Token Expiration**
- FCM tokens expire and need refresh
- Check if tokens are being refreshed automatically
- Look for "FCM Registration Token updated" logs

#### **C. User Authentication Issues**
- FCM tokens only stored for authenticated users
- Verify testers are properly signed in
- Check if `currentUser` exists when registering tokens

### **4. Testing Steps**

#### **Step 1: Create Test Alert**
1. Create an alert from web app
2. Check Firebase Functions logs for execution
3. Verify alert appears in `organizations/{orgId}/alerts`

#### **Step 2: Check FCM Token Storage**
1. Have tester launch app
2. Check console for FCM token logs
3. Verify token stored in Firestore

#### **Step 3: Test Direct FCM**
1. Use Firebase Console to send test message
2. Verify tester receives test notification
3. Check if issue is with alerts or FCM in general

### **5. Debug Commands**

#### **Check Firebase Functions Logs**
```bash
firebase functions:log --only sendAlertNotifications
```

#### **Check Recent Alerts**
Look in Firebase Console > Firestore > `organizations/{orgId}/alerts`

#### **Check User FCM Tokens**
Look in Firebase Console > Firestore > `users` collection

### **6. Most Likely Causes**

1. **APNS Certificate Issues** (40% probability)
2. **FCM Token Not Stored** (30% probability)  
3. **Notification Permissions Denied** (20% probability)
4. **Background App Refresh Disabled** (10% probability)

### **7. Next Steps**

1. **Verify FCM token storage** in Firestore
2. **Check APNS certificate configuration**
3. **Test with Firebase Console** direct messaging
4. **Review iOS app logs** for FCM registration
5. **Verify provisioning profiles** match build type

---

**Need Help?** Check Firebase Console logs and iOS device logs for specific error messages.
