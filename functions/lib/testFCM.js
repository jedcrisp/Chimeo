"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.testFCM = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Firebase Admin is already initialized in index.ts, so we don't need to initialize again
// Test FCM function
exports.testFCM = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        console.log('🧪 Testing FCM functionality...');
        // Get the user's FCM token
        const userId = context.auth.uid;
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User document not found');
        }
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken) {
            throw new functions.https.HttpsError('not-found', 'No FCM token found for user');
        }
        console.log(`📱 Found FCM token: ${fcmToken.substring(0, 20)}...`);
        // Try to send a test message
        const message = {
            notification: {
                title: '🧪 Test Notification',
                body: 'This is a test notification from Firebase Functions!',
            },
            data: {
                test: 'true',
                timestamp: Date.now().toString(),
            },
            token: fcmToken
        };
        console.log('📤 Attempting to send FCM message...');
        const response = await admin.messaging().send(message);
        console.log('✅ FCM message sent successfully!');
        console.log(`   Message ID: ${response}`);
        return {
            success: true,
            messageId: response,
            fcmToken: fcmToken.substring(0, 20) + '...'
        };
    }
    catch (error) {
        console.error('❌ FCM test failed:', error);
        // Check if it's a Firebase Admin SDK issue
        if (error instanceof Error) {
            if (error.message.includes('404') || error.message.includes('batch')) {
                throw new functions.https.HttpsError('internal', 'FCM API not available - check Firebase project configuration');
            }
            if (error.message.includes('messaging/')) {
                throw new functions.https.HttpsError('internal', `FCM error: ${error.message}`);
            }
        }
        throw new functions.https.HttpsError('internal', `Test failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
});
//# sourceMappingURL=testFCM.js.map