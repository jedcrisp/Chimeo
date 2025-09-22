"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateOrganizationVerification = exports.executeScheduledAlerts = exports.notifyAdminsOfOrganizationRequest = exports.cleanupFCMTokens = exports.manageIOSFCMToken = exports.simpleFCMTest = exports.testFCM = exports.fixOrganizationFollowerCount = exports.fixFollowerCounts = exports.cleanupOldFollowers = exports.migrateFollowers = exports.debugFCMTokens = exports.diagnoseFCMConfiguration = exports.testFCMNotification = exports.sendAlertNotifications = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// Initialize Firebase Admin with explicit project configuration
admin.initializeApp({
    projectId: 'chimeo-96dfc'
});
// 🚀 Main function: Send FCM notifications when alerts are posted
exports.sendAlertNotifications = functions.firestore
    .document('organizations/{orgId}/alerts/{alertId}')
    .onCreate(async (snap, context) => {
    const orgId = context.params.orgId;
    const alertId = context.params.alertId;
    const alert = snap.data();
    console.log(`🚨 New alert posted in organization ${orgId}: ${alert.title}`);
    console.log(`   Alert ID: ${alertId}`);
    console.log(`   Group: ${alert.groupName || 'All members'}`);
    console.log(`   Severity: ${alert.severity}`);
    console.log(`   🔍 Looking for followers in users/{userId}/followedOrganizations/${orgId}`);
    console.log(`   🚫 Alert creator ID: ${alert.postedByUserId}`);
    console.log(`   🚫 Alert creator name: ${alert.postedBy}`);
    // Validate that we have the alert creator's ID
    if (!alert.postedByUserId || alert.postedByUserId === "unknown" || alert.postedByUserId === "") {
        console.error(`❌ Invalid postedByUserId: ${alert.postedByUserId}`);
        return;
    }
    try {
        // Get organization followers from the subcollection: organizations/{orgId}/followers/{userId}
        console.log(`   🔍 Getting followers from organizations/${orgId}/followers subcollection`);
        const followersSnapshot = await admin.firestore()
            .collection('organizations')
            .doc(orgId)
            .collection('followers')
            .get();
        console.log(`   🔍 Found ${followersSnapshot.docs.length} followers in subcollection`);
        const followerIds = [];
        for (const followerDoc of followersSnapshot.docs) {
            const followerId = followerDoc.id;
            // Don't include the alert creator in the notification list
            if (followerId !== alert.postedByUserId) {
                followerIds.push(followerId);
                console.log(`   ✅ User ${followerId} follows organization ${orgId}`);
            }
            else {
                console.log(`   🚫 User ${followerId} is the alert creator - excluding from notifications`);
                console.log(`      Alert creator ID: ${alert.postedByUserId}`);
                console.log(`      Current user ID: ${followerId}`);
                console.log(`      IDs match: ${followerId === alert.postedByUserId}`);
            }
        }
        if (followerIds.length === 0) {
            console.log('ℹ️ No followers found for this organization');
            return;
        }
        const activeFollowerIds = followerIds.filter(followerId => {
            // Check if user has alerts enabled (default to true)
            const userDoc = followersSnapshot.docs.find(doc => doc.id === followerId);
            if (userDoc) {
                const userData = userDoc.data();
                return userData.alertsEnabled !== false; // Default to true if not set
            }
            return true; // Default to enabled if user doc not found
        });
        console.log(`📋 Found ${activeFollowerIds.length} active followers`);
        if (activeFollowerIds.length === 0) {
            console.log('ℹ️ No active followers to notify');
            return;
        }
        // Filter followers by group preferences
        let eligibleFollowerIds = activeFollowerIds;
        if (alert.groupId) {
            // Alert is for a specific group - filter by that group's preferences
            console.log(`🔍 Filtering followers for specific group: ${alert.groupName}`);
            eligibleFollowerIds = await filterFollowersByGroupPreferences(activeFollowerIds, alert.groupId, orgId);
            console.log(`✅ ${eligibleFollowerIds.length} followers have group '${alert.groupName}' enabled`);
        }
        else {
            // Alert is for "All members" - check if user has ANY groups enabled
            console.log(`🔍 Alert is for all members - checking if followers have any groups enabled`);
            eligibleFollowerIds = await filterFollowersForAllMembers(activeFollowerIds, orgId);
            console.log(`✅ ${eligibleFollowerIds.length} followers have at least one group enabled`);
        }
        if (eligibleFollowerIds.length === 0) {
            console.log('ℹ️ No eligible followers after group filtering');
            return;
        }
        // Get FCM tokens for eligible followers
        const fcmTokens = await getFCMTokensForUsers(eligibleFollowerIds);
        console.log(`📱 Found ${fcmTokens.length} FCM tokens`);
        if (fcmTokens.length === 0) {
            console.log('ℹ️ No valid FCM tokens found');
            return;
        }
        // Remove duplicate FCM tokens to prevent duplicate notifications
        const uniqueFcmTokens = [...new Set(fcmTokens)];
        if (uniqueFcmTokens.length !== fcmTokens.length) {
            const duplicateCount = fcmTokens.length - uniqueFcmTokens.length;
            console.log(`⚠️ Found ${duplicateCount} duplicate FCM tokens - removing duplicates`);
            console.log(`   Original tokens: ${fcmTokens.length}`);
            console.log(`   Unique tokens: ${uniqueFcmTokens.length}`);
        }
        // Create notification content
        const titlePrefix = getSeverityPrefix(alert.severity);
        const notificationTitle = alert.groupName
            ? `${titlePrefix}${alert.groupName}: ${alert.title}`
            : `${titlePrefix}${alert.title}`;
        // Send FCM notifications individually to avoid batch endpoint issues
        let successCount = 0;
        let failureCount = 0;
        for (let i = 0; i < uniqueFcmTokens.length; i++) {
            try {
                const singleMessage = {
                    notification: {
                        title: notificationTitle,
                        body: alert.description,
                    },
                    data: {
                        alertId: alertId,
                        organizationId: orgId,
                        organizationName: alert.organizationName,
                        alertType: alert.type,
                        severity: alert.severity,
                        groupId: alert.groupId || '',
                        groupName: alert.groupName || '',
                        click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    token: uniqueFcmTokens[i]
                };
                const result = await admin.messaging().send(singleMessage);
                successCount++;
                console.log(`✅ Sent notification to unique token ${i + 1}/${uniqueFcmTokens.length} - Message ID: ${result}`);
            }
            catch (tokenError) {
                failureCount++;
                console.error(`❌ Failed to send to unique token ${i + 1}:`, tokenError);
                // Enhanced error logging for FCM issues
                if (tokenError instanceof Error) {
                    console.error(`   Error message: ${tokenError.message}`);
                    console.error(`   Error code: ${tokenError.code || 'unknown'}`);
                    console.error(`   Error details: ${JSON.stringify(tokenError.errorInfo || {})}`);
                    // Check for specific FCM errors
                    if (tokenError.message.includes('404') || tokenError.message.includes('batch')) {
                        console.error(`🚨 FCM API 404 Error - This usually means:`);
                        console.error(`   1. Firebase project doesn't have FCM enabled`);
                        console.error(`   2. Service account lacks FCM permissions`);
                        console.error(`   3. Firebase project ID is incorrect`);
                        console.error(`   4. FCM API is not properly configured`);
                    }
                }
            }
        }
        console.log(`✅ FCM notifications completed!`);
        console.log(`   Success count: ${successCount}`);
        console.log(`   Failure count: ${failureCount}`);
        console.log(`   🚫 Alert creator excluded: ${alert.postedByUserId}`);
        console.log(`   📊 Total followers found: ${followerIds.length}`);
        console.log(`   📊 Eligible followers after filtering: ${eligibleFollowerIds.length}`);
        console.log(`   📊 Final notification recipients: ${successCount}`);
        // Update alert with notification status
        await snap.ref.update({
            notificationsSent: true,
            notificationCount: successCount,
            notificationFailures: failureCount,
            notificationSentAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`🎉 Alert notification process completed for organization ${orgId}`);
    }
    catch (error) {
        console.error(`❌ Error sending alert notifications:`, error);
        // Update alert with error status
        await snap.ref.update({
            notificationsSent: false,
            notificationError: error instanceof Error ? error.message : 'Unknown error',
            notificationErrorAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
});
// 🔍 Filter followers by group preferences
// Looks in users/{userId}/followedOrganizations/{orgId} for groupPreferences
async function filterFollowersByGroupPreferences(followerIds, groupId, orgId) {
    const eligibleFollowers = [];
    for (const followerId of followerIds) {
        try {
            // Get group preferences from the correct structure: users/{userId}/followedOrganizations/{orgId}
            const followerDoc = await admin.firestore()
                .collection('users')
                .doc(followerId)
                .collection('followedOrganizations')
                .doc(orgId)
                .get();
            if (followerDoc.exists) {
                const data = followerDoc.data();
                const groupPreferences = (data === null || data === void 0 ? void 0 : data.groupPreferences) || {};
                // Check if this is the user's first time with this group
                // If no preference is set, we'll allow the notification by default
                // This ensures users get notifications until they explicitly disable them
                if (groupPreferences[groupId] === undefined) {
                    // First time seeing this group - allow notification by default
                    console.log(`   🔄 Follower ${followerId}: first time with group, allowing notification (default: enabled)`);
                    // Initialize the preference to true for future notifications (opt-out model)
                    try {
                        await admin.firestore()
                            .collection('users')
                            .doc(followerId)
                            .collection('followedOrganizations')
                            .doc(orgId)
                            .update({
                            [`groupPreferences.${groupId}`]: true
                        });
                        console.log(`   ✅ Initialized group preference for ${followerId}: ${groupId} = true (enabled by default)`);
                    }
                    catch (initError) {
                        console.log(`   ⚠️ Could not initialize preference for ${followerId}: ${initError}`);
                    }
                    eligibleFollowers.push(followerId);
                }
                else if (groupPreferences[groupId] === true) {
                    // User explicitly enabled this group
                    eligibleFollowers.push(followerId);
                    console.log(`   ✅ Follower ${followerId}: group explicitly enabled`);
                }
                else if (groupPreferences[groupId] === false) {
                    // User explicitly disabled this group
                    console.log(`   ❌ Follower ${followerId}: group explicitly disabled`);
                }
                else {
                    // Any other value - default to enabled for safety
                    console.log(`   🔄 Follower ${followerId}: unclear preference, defaulting to enabled`);
                    eligibleFollowers.push(followerId);
                }
            }
            else {
                // No preferences document found - create one and allow notifications by default
                console.log(`   🔄 Follower ${followerId}: no preferences document, creating with default enabled`);
                try {
                    await admin.firestore()
                        .collection('users')
                        .doc(followerId)
                        .collection('followedOrganizations')
                        .doc(orgId)
                        .set({
                        groupPreferences: { [groupId]: true },
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    console.log(`   ✅ Created preferences document for ${followerId} with ${groupId} = true`);
                    eligibleFollowers.push(followerId);
                }
                catch (createError) {
                    console.log(`   ⚠️ Could not create preferences for ${followerId}: ${createError}`);
                    // Even if we can't create preferences, allow the notification
                    eligibleFollowers.push(followerId);
                }
            }
        }
        catch (error) {
            console.error(`❌ Error checking preferences for follower ${followerId}:`, error);
            // On error, default to allowing notifications (more inclusive approach)
            console.log(`   🔄 Follower ${followerId}: error occurred, defaulting to enabled for safety`);
            eligibleFollowers.push(followerId);
        }
    }
    return eligibleFollowers;
}
// 🔍 Filter followers for "All members" alerts - include users who have any groups or no preferences set
async function filterFollowersForAllMembers(followerIds, orgId) {
    const eligibleFollowers = [];
    for (const followerId of followerIds) {
        try {
            // Get group preferences from the correct structure: users/{userId}/followedOrganizations/{orgId}
            const followerDoc = await admin.firestore()
                .collection('users')
                .doc(followerId)
                .collection('followedOrganizations')
                .doc(orgId)
                .get();
            if (followerDoc.exists) {
                const data = followerDoc.data();
                const groupPreferences = (data === null || data === void 0 ? void 0 : data.groupPreferences) || {};
                if (Object.keys(groupPreferences).length === 0) {
                    // No preferences set yet - allow notification by default
                    console.log(`   🔄 Follower ${followerId}: no preferences set yet, allowing "All members" notification by default`);
                    eligibleFollowers.push(followerId);
                }
                else {
                    // Check if user has ANY groups explicitly enabled (value === true)
                    // OR if they have no explicit preferences (undefined values)
                    const hasExplicitlyEnabledGroups = Object.values(groupPreferences).some(preference => preference === true);
                    const hasExplicitlyDisabledGroups = Object.values(groupPreferences).some(preference => preference === false);
                    if (hasExplicitlyEnabledGroups) {
                        // User has some groups enabled
                        eligibleFollowers.push(followerId);
                        console.log(`   ✅ Follower ${followerId}: has groups explicitly enabled`);
                    }
                    else if (hasExplicitlyDisabledGroups && !hasExplicitlyEnabledGroups) {
                        // User has only disabled groups and no enabled ones
                        console.log(`   ❌ Follower ${followerId}: only has disabled groups`);
                    }
                    else {
                        // Mixed or unclear preferences - default to enabled for safety
                        console.log(`   🔄 Follower ${followerId}: mixed preferences, defaulting to enabled`);
                        eligibleFollowers.push(followerId);
                    }
                }
            }
            else {
                // No preferences document found - create one and allow notifications by default
                console.log(`   🔄 Follower ${followerId}: no preferences document, creating with default enabled for "All members"`);
                try {
                    await admin.firestore()
                        .collection('users')
                        .doc(followerId)
                        .collection('followedOrganizations')
                        .doc(orgId)
                        .set({
                        groupPreferences: {},
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    console.log(`   ✅ Created preferences document for ${followerId} with empty preferences (enabled by default)`);
                    eligibleFollowers.push(followerId);
                }
                catch (createError) {
                    console.log(`   ⚠️ Could not create preferences for ${followerId}: ${createError}`);
                    // Even if we can't create preferences, allow the notification
                    eligibleFollowers.push(followerId);
                }
            }
        }
        catch (error) {
            console.error(`❌ Error checking preferences for follower ${followerId}:`, error);
            // On error, default to allowing notifications (more inclusive approach)
            console.log(`   🔄 Follower ${followerId}: error occurred, defaulting to enabled for safety`);
            eligibleFollowers.push(followerId);
        }
    }
    return eligibleFollowers;
}
// 📱 Get FCM tokens for users
async function getFCMTokensForUsers(userIds) {
    const tokens = [];
    for (const userId of userIds) {
        try {
            const userDoc = await admin.firestore()
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                if (fcmToken && typeof fcmToken === 'string' && fcmToken.trim().length > 0) {
                    // Basic FCM token validation (should be a long string)
                    if (fcmToken.length > 100) {
                        tokens.push(fcmToken);
                        console.log(`   📱 Found valid FCM token for user ${userId} (length: ${fcmToken.length})`);
                    }
                    else {
                        console.log(`   ⚠️ FCM token for user ${userId} seems too short (length: ${fcmToken.length})`);
                    }
                }
                else {
                    console.log(`   ⚠️ No valid FCM token for user ${userId} (token: ${fcmToken || 'undefined'})`);
                }
            }
            else {
                console.log(`   ❌ User document not found: ${userId}`);
            }
        }
        catch (error) {
            console.error(`❌ Error getting FCM token for user ${userId}:`, error);
        }
    }
    console.log(`📱 Total valid FCM tokens found: ${tokens.length}/${userIds.length}`);
    return tokens;
}
// 🔄 Enhanced FCM token management for cross-platform support
async function updateUserFCMToken(userId, token, platform = 'unknown') {
    try {
        const db = admin.firestore();
        const userRef = db.collection('users').doc(userId);
        const updateData = {
            fcmToken: token,
            lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
            platform: platform,
            tokenStatus: 'active'
        };
        // Add platform-specific fields
        if (platform === 'ios') {
            updateData.iosToken = token;
            updateData.iosLastUpdate = admin.firestore.FieldValue.serverTimestamp();
        }
        else if (platform === 'web') {
            updateData.webToken = token;
            updateData.webLastUpdate = admin.firestore.FieldValue.serverTimestamp();
        }
        await userRef.update(updateData);
        console.log(`✅ FCM token updated for user ${userId} (platform: ${platform})`);
        return true;
    }
    catch (error) {
        console.error(`❌ Failed to update FCM token for user ${userId}:`, error);
        return false;
    }
}
// 🧹 Clean up invalid FCM tokens
async function cleanupInvalidFCMTokens() {
    try {
        console.log('🧹 Cleaning up invalid FCM tokens...');
        const usersSnapshot = await admin.firestore()
            .collection('users')
            .where('fcmToken', '!=', null)
            .get();
        let cleanedCount = 0;
        for (const userDoc of usersSnapshot.docs) {
            const userData = userDoc.data();
            const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
            // Check if token is valid
            if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim().length < 100) {
                try {
                    await userDoc.ref.update({
                        fcmToken: null,
                        tokenStatus: 'invalid',
                        lastTokenCleanup: admin.firestore.FieldValue.serverTimestamp()
                    });
                    cleanedCount++;
                    console.log(`   🧹 Cleaned invalid token for user: ${userDoc.id}`);
                }
                catch (error) {
                    console.log(`   ⚠️ Could not clean token for user ${userDoc.id}: ${error}`);
                }
            }
        }
        console.log(`✅ FCM token cleanup completed: ${cleanedCount} tokens cleaned`);
        return cleanedCount;
    }
    catch (error) {
        console.error('❌ Error during FCM token cleanup:', error);
        return 0;
    }
}
// 🎯 Get severity prefix for notifications
function getSeverityPrefix(severity) {
    switch (severity.toLowerCase()) {
        case 'critical':
            return '🚨 CRITICAL: ';
        case 'high':
            return '⚠️ HIGH PRIORITY: ';
        case 'medium':
            return '📢 ';
        case 'low':
            return 'ℹ️ ';
        default:
            return '📢 ';
    }
}
// 🧪 Test function for manual FCM testing
exports.testFCMNotification = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { userId, title, body } = data;
    if (!userId || !title || !body) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    try {
        console.log(`🧪 Testing FCM notification for user: ${userId}`);
        // Get user's FCM token
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User not found');
        }
        const userData = userDoc.data();
        const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
        if (!fcmToken) {
            throw new functions.https.HttpsError('failed-precondition', 'No FCM token found for user');
        }
        // Send test notification
        const message = {
            notification: {
                title: `🧪 TEST: ${title}`,
                body: body,
            },
            data: {
                test: 'true',
                timestamp: Date.now().toString()
            },
            token: fcmToken
        };
        const result = await admin.messaging().send(message);
        console.log(`✅ Test FCM notification sent successfully: ${result}`);
        return { success: true, messageId: result };
    }
    catch (error) {
        console.error(`❌ Error sending test FCM notification:`, error);
        throw new functions.https.HttpsError('internal', 'Failed to send test notification');
    }
});
// 🔧 FCM Configuration Diagnostic Function
exports.diagnoseFCMConfiguration = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        console.log('🔍 Diagnosing FCM configuration...');
        const diagnostics = {
            timestamp: new Date().toISOString(),
            firebaseProject: process.env.GCLOUD_PROJECT || 'unknown',
            nodeVersion: process.version,
            firebaseAdminVersion: require('firebase-admin/package.json').version,
            firebaseFunctionsVersion: require('firebase-functions/package.json').version,
            fcmApiAvailable: false,
            serviceAccountInfo: {},
            errors: []
        };
        // Check Firebase Admin initialization
        try {
            const app = admin.app();
            const projectId = app.options.projectId;
            diagnostics.serviceAccountInfo.projectId = projectId;
            console.log(`✅ Firebase Admin initialized with project: ${projectId}`);
        }
        catch (error) {
            diagnostics.errors.push(`Firebase Admin initialization error: ${error}`);
            console.error('❌ Firebase Admin initialization error:', error);
        }
        // Test FCM API availability with a simple call
        try {
            // Try to get FCM app instance
            const messaging = admin.messaging();
            console.log('✅ FCM messaging instance created successfully');
            // Try a simple validation call (this will fail if FCM is not properly configured)
            // We'll use a dummy token to test the API endpoint
            const testMessage = {
                notification: {
                    title: 'FCM Test',
                    body: 'Testing FCM API availability'
                },
                token: 'test-token-for-api-check'
            };
            try {
                await messaging.send(testMessage);
                diagnostics.fcmApiAvailable = true;
                console.log('✅ FCM API is accessible');
            }
            catch (apiError) {
                // We expect this to fail with invalid token, but it tells us if the API is reachable
                if (apiError instanceof Error && apiError.message.includes('InvalidRegistration')) {
                    diagnostics.fcmApiAvailable = true;
                    console.log('✅ FCM API is accessible (got expected InvalidRegistration error)');
                }
                else if (apiError instanceof Error && apiError.message.includes('404')) {
                    diagnostics.fcmApiAvailable = false;
                    diagnostics.errors.push('FCM API returned 404 - project may not have FCM enabled');
                    console.error('❌ FCM API 404 error - project may not have FCM enabled');
                }
                else {
                    diagnostics.errors.push(`FCM API error: ${apiError}`);
                    console.error('❌ FCM API error:', apiError);
                }
            }
        }
        catch (error) {
            diagnostics.errors.push(`FCM messaging error: ${error}`);
            console.error('❌ FCM messaging error:', error);
        }
        // Check environment variables
        const envVars = {
            GCLOUD_PROJECT: process.env.GCLOUD_PROJECT,
            FIREBASE_CONFIG: process.env.FIREBASE_CONFIG ? 'present' : 'missing',
            GOOGLE_APPLICATION_CREDENTIALS: process.env.GOOGLE_APPLICATION_CREDENTIALS ? 'present' : 'missing'
        };
        diagnostics.environmentVariables = envVars;
        console.log('🔍 FCM Configuration Diagnostics:', JSON.stringify(diagnostics, null, 2));
        return diagnostics;
    }
    catch (error) {
        console.error('❌ Error in FCM configuration diagnosis:', error);
        throw new functions.https.HttpsError('internal', 'Failed to diagnose FCM configuration');
    }
});
// 🔍 Debug function to check FCM token status for all users
exports.debugFCMTokens = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        console.log(`🔍 Debugging FCM tokens for all users...`);
        const usersSnapshot = await admin.firestore().collection('users').get();
        const userStats = {
            totalUsers: usersSnapshot.docs.length,
            usersWithTokens: 0,
            usersWithoutTokens: 0,
            validTokens: 0,
            invalidTokens: 0,
            tokenDetails: []
        };
        for (const userDoc of usersSnapshot.docs) {
            const userData = userDoc.data();
            const fcmToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
            if (fcmToken && typeof fcmToken === 'string' && fcmToken.trim().length > 0) {
                userStats.usersWithTokens++;
                if (fcmToken.length > 100) {
                    userStats.validTokens++;
                    userStats.tokenDetails.push({
                        userId: userDoc.id,
                        hasToken: true,
                        tokenLength: fcmToken.length,
                        tokenPreview: `${fcmToken.substring(0, 20)}...`
                    });
                }
                else {
                    userStats.invalidTokens++;
                    userStats.tokenDetails.push({
                        userId: userDoc.id,
                        hasToken: true,
                        tokenLength: fcmToken.length,
                        tokenPreview: fcmToken,
                        issue: 'Token too short'
                    });
                }
            }
            else {
                userStats.usersWithoutTokens++;
                userStats.tokenDetails.push({
                    userId: userDoc.id,
                    hasToken: false,
                    tokenValue: fcmToken
                });
            }
        }
        console.log(`📊 FCM Token Debug Results:`, userStats);
        return {
            success: true,
            stats: userStats
        };
    }
    catch (error) {
        console.error(`❌ Error debugging FCM tokens:`, error);
        throw new functions.https.HttpsError('internal', 'Failed to debug FCM tokens');
    }
});
// 🔄 Migration functions
var migrateFollowers_1 = require("./migrateFollowers");
Object.defineProperty(exports, "migrateFollowers", { enumerable: true, get: function () { return migrateFollowers_1.migrateFollowers; } });
Object.defineProperty(exports, "cleanupOldFollowers", { enumerable: true, get: function () { return migrateFollowers_1.cleanupOldFollowers; } });
// 🔧 Follower count fix functions
var fixFollowerCounts_1 = require("./fixFollowerCounts");
Object.defineProperty(exports, "fixFollowerCounts", { enumerable: true, get: function () { return fixFollowerCounts_1.fixFollowerCounts; } });
Object.defineProperty(exports, "fixOrganizationFollowerCount", { enumerable: true, get: function () { return fixFollowerCounts_1.fixOrganizationFollowerCount; } });
// 🧪 Test FCM function
var testFCM_1 = require("./testFCM");
Object.defineProperty(exports, "testFCM", { enumerable: true, get: function () { return testFCM_1.testFCM; } });
// 🧪 Simple FCM test function
var simpleFCMTest_1 = require("./simpleFCMTest");
Object.defineProperty(exports, "simpleFCMTest", { enumerable: true, get: function () { return simpleFCMTest_1.simpleFCMTest; } });
// 📱 iOS FCM Token Management Function
exports.manageIOSFCMToken = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { action, token, platform } = data;
    const userId = context.auth.uid;
    if (!action || !token) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
    }
    try {
        console.log(`📱 iOS FCM token management for user: ${userId}`);
        console.log(`   Action: ${action}`);
        console.log(`   Platform: ${platform || 'ios'}`);
        switch (action) {
            case 'register':
                const success = await updateUserFCMToken(userId, token, platform || 'ios');
                if (success) {
                    console.log(`✅ FCM token registered for iOS user: ${userId}`);
                    return { success: true, message: 'FCM token registered successfully' };
                }
                else {
                    throw new functions.https.HttpsError('internal', 'Failed to register FCM token');
                }
            case 'unregister':
                // Remove FCM token
                await admin.firestore().collection('users').doc(userId).update({
                    fcmToken: null,
                    iosToken: null,
                    tokenStatus: 'unregistered',
                    lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
                });
                console.log(`✅ FCM token unregistered for iOS user: ${userId}`);
                return { success: true, message: 'FCM token unregistered successfully' };
            case 'validate':
                // Validate existing token
                const userDoc = await admin.firestore().collection('users').doc(userId).get();
                if (userDoc.exists) {
                    const userData = userDoc.data();
                    const currentToken = userData === null || userData === void 0 ? void 0 : userData.fcmToken;
                    const isValid = currentToken === token && currentToken && currentToken.length > 100;
                    console.log(`🔍 Token validation for user ${userId}: ${isValid ? 'VALID' : 'INVALID'}`);
                    return {
                        success: true,
                        isValid: isValid,
                        hasToken: !!currentToken,
                        tokenLength: (currentToken === null || currentToken === void 0 ? void 0 : currentToken.length) || 0
                    };
                }
                else {
                    throw new functions.https.HttpsError('not-found', 'User not found');
                }
            default:
                throw new functions.https.HttpsError('invalid-argument', 'Invalid action specified');
        }
    }
    catch (error) {
        console.error(`❌ Error in iOS FCM token management:`, error);
        throw new functions.https.HttpsError('internal', 'Failed to manage FCM token');
    }
});
// 🧹 FCM Token Cleanup Function
exports.cleanupFCMTokens = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    // Only allow admins to run cleanup
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || !((_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.isAdmin)) {
        throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    try {
        console.log(`🧹 FCM token cleanup initiated by admin: ${context.auth.uid}`);
        const cleanedCount = await cleanupInvalidFCMTokens();
        return {
            success: true,
            cleanedCount: cleanedCount,
            message: `Cleaned ${cleanedCount} invalid FCM tokens`
        };
    }
    catch (error) {
        console.error(`❌ Error during FCM token cleanup:`, error);
        throw new functions.https.HttpsError('internal', 'Failed to cleanup FCM tokens');
    }
});
// 🏢 Send notifications to admins when new organization requests are submitted
exports.notifyAdminsOfOrganizationRequest = functions.firestore
    .document('organizationRequests/{requestId}')
    .onCreate(async (snap, context) => {
    const requestId = context.params.requestId;
    const request = snap.data();
    console.log(`🏢 New organization request submitted: ${requestId}`);
    console.log(`   Organization: ${request.name}`);
    console.log(`   Contact: ${request.contactPersonEmail}`);
    try {
        // Get all admin users (users with isAdmin: true)
        const adminUsersSnapshot = await admin.firestore()
            .collection('users')
            .where('isAdmin', '==', true)
            .get();
        if (adminUsersSnapshot.empty) {
            console.log('ℹ️ No admin users found to notify');
            return;
        }
        const adminUserIds = adminUsersSnapshot.docs.map(doc => doc.id);
        console.log(`👑 Found ${adminUserIds.length} admin users to notify`);
        // Get FCM tokens for admin users
        const fcmTokens = await getFCMTokensForUsers(adminUserIds);
        console.log(`📱 Found ${fcmTokens.length} FCM tokens for admins`);
        if (fcmTokens.length === 0) {
            console.log('ℹ️ No valid FCM tokens found for admins');
            return;
        }
        // Create notification content
        const notificationTitle = 'New Organization Request';
        const notificationBody = `${request.name} has requested to join the platform`;
        // Send FCM notifications to all admins
        let successCount = 0;
        let failureCount = 0;
        for (let i = 0; i < fcmTokens.length; i++) {
            try {
                const message = {
                    notification: {
                        title: notificationTitle,
                        body: notificationBody,
                    },
                    data: {
                        type: 'organization_request',
                        requestId: String(requestId),
                        organizationName: String(request.name || ''),
                        contactEmail: String(request.contactPersonEmail || ''),
                        click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    token: fcmTokens[i]
                };
                await admin.messaging().send(message);
                successCount++;
                console.log(`✅ Notification sent to admin ${i + 1}`);
            }
            catch (error) {
                failureCount++;
                console.error(`❌ Failed to send notification to admin ${i + 1}:`, error);
            }
        }
        console.log(`📊 Admin notifications completed: ${successCount} success, ${failureCount} failures`);
        // Update the request document with notification status
        await snap.ref.update({
            adminNotificationsSent: true,
            adminNotificationCount: successCount,
            adminNotificationFailures: failureCount,
            adminNotificationSentAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    catch (error) {
        console.error(`❌ Error sending admin notifications:`, error);
        await snap.ref.update({
            adminNotificationsSent: false,
            adminNotificationError: error instanceof Error ? error.message : 'Unknown error',
            adminNotificationErrorAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
});
// ⏰ Scheduled Alert Execution Function
exports.executeScheduledAlerts = functions.pubsub
    .schedule('every 1 minutes')
    .onRun(async (context) => {
    var _a, _b, _c;
    console.log('⏰ Running scheduled alert execution...');
    try {
        const now = new Date();
        console.log(`   Current time: ${now.toISOString()}`);
        // Get all organizations
        const organizationsSnapshot = await admin.firestore()
            .collection('organizations')
            .get();
        console.log(`   Found ${organizationsSnapshot.docs.length} organizations`);
        let totalProcessed = 0;
        let totalExecuted = 0;
        for (const orgDoc of organizationsSnapshot.docs) {
            const orgId = orgDoc.id;
            console.log(`   Checking organization: ${orgId}`);
            // Get due scheduled alerts for this organization
            const dueAlertsSnapshot = await admin.firestore()
                .collection('organizations')
                .doc(orgId)
                .collection('scheduledAlerts')
                .where('isActive', '==', true)
                .where('scheduledDate', '<=', now)
                .orderBy('scheduledDate', 'asc')
                .get();
            console.log(`   Found ${dueAlertsSnapshot.docs.length} due alerts for ${orgId}`);
            for (const alertDoc of dueAlertsSnapshot.docs) {
                const alertId = alertDoc.id;
                const alert = alertDoc.data();
                console.log(`   Processing scheduled alert: ${alert.title} (${alertId})`);
                console.log(`   Scheduled for: ${((_c = (_b = (_a = alert.scheduledDate) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) === null || _c === void 0 ? void 0 : _c.toISOString()) || 'Invalid date'}`);
                console.log(`   Group: ${alert.groupName || 'All members'}`);
                try {
                    // Execute the scheduled alert
                    await executeScheduledAlert(orgId, alertId, alert);
                    totalExecuted++;
                    console.log(`   ✅ Successfully executed scheduled alert: ${alert.title}`);
                }
                catch (error) {
                    console.error(`   ❌ Error executing scheduled alert ${alertId}:`, error);
                }
                totalProcessed++;
            }
        }
        console.log(`⏰ Scheduled alert execution completed:`);
        console.log(`   Total processed: ${totalProcessed}`);
        console.log(`   Total executed: ${totalExecuted}`);
    }
    catch (error) {
        console.error('❌ Error in scheduled alert execution:', error);
    }
});
// 🚨 Execute individual scheduled alert
async function executeScheduledAlert(orgId, alertId, alert) {
    console.log(`🚨 Executing scheduled alert: ${alert.title}`);
    // Create organization alert from scheduled alert
    const organizationAlert = {
        title: alert.title,
        description: alert.description,
        organizationId: alert.organizationId,
        organizationName: alert.organizationName,
        groupId: alert.groupId || '',
        groupName: alert.groupName || '',
        type: alert.type,
        severity: alert.severity,
        location: alert.location || {},
        postedBy: alert.postedBy,
        postedByUserId: alert.postedByUserId,
        imageURLs: alert.imageURLs || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        scheduledAlertId: alertId // Track that this came from a scheduled alert
    };
    // Post the alert to the regular alerts collection to trigger notifications
    await admin.firestore()
        .collection('organizations')
        .doc(orgId)
        .collection('alerts')
        .add(organizationAlert);
    // Handle recurrence if applicable
    if (alert.isRecurring && alert.recurrencePattern) {
        await handleScheduledAlertRecurrence(orgId, alertId, alert);
    }
    else {
        // Deactivate the scheduled alert since it's not recurring
        await admin.firestore()
            .collection('organizations')
            .doc(orgId)
            .collection('scheduledAlerts')
            .doc(alertId)
            .update({
            isActive: false,
            executedAt: admin.firestore.FieldValue.serverTimestamp(),
            executed: true
        });
    }
}
// 🔄 Handle recurrence for scheduled alerts
async function handleScheduledAlertRecurrence(orgId, alertId, alert) {
    var _a, _b, _c, _d;
    console.log(`🔄 Handling recurrence for scheduled alert: ${alert.title}`);
    const pattern = alert.recurrencePattern;
    const currentDate = new Date(((_b = (_a = alert.scheduledDate) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) || new Date());
    let nextDate;
    switch (pattern.frequency) {
        case 'daily':
            nextDate = new Date(currentDate.getTime() + (pattern.interval || 1) * 24 * 60 * 60 * 1000);
            break;
        case 'weekly':
            nextDate = new Date(currentDate.getTime() + (pattern.interval || 1) * 7 * 24 * 60 * 60 * 1000);
            break;
        case 'monthly':
            nextDate = new Date(currentDate);
            nextDate.setMonth(nextDate.getMonth() + (pattern.interval || 1));
            break;
        case 'yearly':
            nextDate = new Date(currentDate);
            nextDate.setFullYear(nextDate.getFullYear() + (pattern.interval || 1));
            break;
        default:
            console.log(`   ⚠️ Unknown recurrence frequency: ${pattern.frequency}`);
            return;
    }
    // Check if we've reached the end date
    if (pattern.endDate) {
        const endDate = new Date(((_d = (_c = pattern.endDate).toDate) === null || _d === void 0 ? void 0 : _d.call(_c)) || pattern.endDate);
        if (nextDate > endDate) {
            console.log(`   📅 Recurrence end date reached, deactivating scheduled alert`);
            await admin.firestore()
                .collection('organizations')
                .doc(orgId)
                .collection('scheduledAlerts')
                .doc(alertId)
                .update({
                isActive: false,
                executedAt: admin.firestore.FieldValue.serverTimestamp(),
                executed: true,
                recurrenceEnded: true
            });
            return;
        }
    }
    // Update the scheduled alert with the next occurrence
    await admin.firestore()
        .collection('organizations')
        .doc(orgId)
        .collection('scheduledAlerts')
        .doc(alertId)
        .update({
        scheduledDate: admin.firestore.Timestamp.fromDate(nextDate),
        lastExecutedAt: admin.firestore.FieldValue.serverTimestamp(),
        executionCount: admin.firestore.FieldValue.increment(1)
    });
    console.log(`   ✅ Next occurrence scheduled for: ${nextDate.toISOString()}`);
}
// Export the updateOrganizationVerification function
var updateOrganizationVerification_1 = require("./updateOrganizationVerification");
Object.defineProperty(exports, "updateOrganizationVerification", { enumerable: true, get: function () { return updateOrganizationVerification_1.updateOrganizationVerification; } });
//# sourceMappingURL=index.js.map