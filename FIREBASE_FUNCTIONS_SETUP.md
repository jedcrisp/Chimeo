# 🚀 Firebase Functions Setup for Real Push Notifications

## Prerequisites
- Firebase CLI installed (`npm install -g firebase-tools`)
- Node.js 18+ installed
- Firebase project already set up

## 🔧 Setup Steps

### 1. Initialize Firebase Functions (if not already done)
```bash
# In your project root
firebase init functions
```
- Choose TypeScript
- Use ESLint? Yes
- Install dependencies? Yes

### 2. Install Dependencies
```bash
cd functions
npm install
```

### 3. Deploy Firebase Functions
```bash
# From project root
firebase deploy --only functions
```

### 4. Verify Deployment
```bash
firebase functions:log
```

## 🧪 Testing

### Test via iOS App
1. Open the app
2. Go to Settings
3. Tap "Test Real FCM" button
4. Check console for success/error messages

### Test via Firebase Console
1. Go to Firebase Console → Functions
2. Find `sendAlertNotifications` function
3. Check execution logs

## 🚨 Real Push Notification Flow

When you post an alert:

1. **Alert Posted** → Firestore `organizations/{orgId}/alerts/{alertId}`
2. **Function Triggered** → `sendAlertNotifications` executes automatically
3. **Followers Found** → Gets organization followers from Firestore
4. **Group Filtering** → Filters by user group preferences
5. **FCM Tokens Retrieved** → Gets tokens for eligible users
6. **FCM Sent** → Real push notifications sent to devices
7. **Status Updated** → Alert updated with notification stats

## 📱 What You'll See

### Posting Device Console:
```
🚀 Real FCM notifications now handled by Firebase Functions!
   Alert will be posted to Firestore, which triggers Firebase Function
   Firebase Function will send FCM notifications to all eligible followers
✅ Real cross-device FCM notifications will be sent by Firebase Functions
```

### Firebase Functions Logs:
```
🚨 New alert posted in organization Velocity_Physical_Therapy_North_Denton: Test Alert
📋 Found 2 active followers
✅ 2 followers have this group enabled
📱 Found 2 FCM tokens
✅ FCM notifications sent successfully!
   Success count: 2
   Failure count: 0
```

### Follower Devices:
- **Real push notifications appear** with proper content
- **Group names included** in notification titles
- **Works across all devices** (not just posting device)

## 🔧 Troubleshooting

### Functions not deploying?
```bash
firebase login
firebase use --add
firebase deploy --only functions
```

### No notifications received?
1. Check Firebase Functions logs: `firebase functions:log`
2. Verify FCM tokens are registered: Use "Debug Notifications" in Settings
3. Check group preferences: Ensure users have groups enabled

### Test FCM manually:
```bash
# Call test function directly
firebase functions:shell
testFCMNotification({userId: "user-id", title: "Test", body: "Test body"})
```

## 🎉 Success!

Once deployed, you'll have **real cross-device push notifications** that:
- ✅ Work across all devices
- ✅ Respect group preferences  
- ✅ Include proper notification content
- ✅ Scale automatically with Firebase
- ✅ Handle errors gracefully

