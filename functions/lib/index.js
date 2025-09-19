"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notifyAdminsOfOrganizationRequest = exports.simpleFCMTest = exports.testFCM = exports.fixOrganizationFollowerCount = exports.fixFollowerCounts = exports.cleanupOldFollowers = exports.migrateFollowers = exports.testFCMNotification = exports.sendAlertNotifications = void 0;
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
    try {
        // Get organization followers from the correct structure: users/{userId}/followedOrganizations/{orgId}
        // We need to get all users who follow this organization by checking the subcollection
        const followersSnapshot = await admin.firestore()
            .collection('users')
            .get();
        // Filter users who follow this organization by checking their followedOrganizations subcollection
        console.log(`   🔍 Checking ${followersSnapshot.docs.length} users for followers of organization ${orgId}`);
        const followerIds = [];
        for (const userDoc of followersSnapshot.docs) {
            try {
                // Check if this user follows the organization by looking in their subcollection
                const followedOrgDoc = await admin.firestore()
                    .collection('users')
                    .doc(userDoc.id)
                    .collection('followedOrganizations')
                    .doc(orgId)
                    .get();
                if (followedOrgDoc.exists) {
                    // Don't include the alert creator in the notification list
                    if (userDoc.id !== alert.postedByUserId) {
                        followerIds.push(userDoc.id);
                        console.log(`   ✅ User ${userDoc.id} follows organization ${orgId}`);
                    }
                    else {
                        console.log(`   🚫 User ${userDoc.id} is the alert creator - excluding from notifications`);
                    }
                }
            }
            catch (error) {
                console.log(`   ⚠️ Error checking if user ${userDoc.id} follows organization: ${error}`);
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
        // Create notification content
        const titlePrefix = getSeverityPrefix(alert.severity);
        const notificationTitle = alert.groupName
            ? `${titlePrefix}${alert.groupName}: ${alert.title}`
            : `${titlePrefix}${alert.title}`;
        // Send FCM notifications individually to avoid batch endpoint issues
        let successCount = 0;
        let failureCount = 0;
        for (let i = 0; i < fcmTokens.length; i++) {
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
                    token: fcmTokens[i]
                };
                await admin.messaging().send(singleMessage);
                successCount++;
                console.log(`✅ Sent notification to token ${i + 1}/${fcmTokens.length}`);
            }
            catch (tokenError) {
                failureCount++;
                console.error(`❌ Failed to send to token ${i + 1}: ${tokenError instanceof Error ? tokenError.message : 'Unknown error'}`);
            }
        }
        console.log(`✅ FCM notifications completed!`);
        console.log(`   Success count: ${successCount}`);
        console.log(`   Failure count: ${failureCount}`);
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
                // If no preference is set, we'll initialize it to false but allow the notification
                // This ensures users get at least one notification to know they need to configure preferences
                if (groupPreferences[groupId] === undefined) {
                    // First time seeing this group - allow notification and initialize preference
                    console.log(`   🔄 Follower ${followerId}: first time with group, allowing notification and initializing preference`);
                    // Initialize the preference to false for future notifications
                    try {
                        await admin.firestore()
                            .collection('users')
                            .doc(followerId)
                            .collection('followedOrganizations')
                            .doc(orgId)
                            .update({
                            [`groupPreferences.${groupId}`]: false
                        });
                        console.log(`   ✅ Initialized group preference for ${followerId}: ${groupId} = false`);
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
                else {
                    // User explicitly disabled this group or preference is false
                    console.log(`   ❌ Follower ${followerId}: group explicitly disabled (preference: ${groupPreferences[groupId]})`);
                }
            }
            else {
                // No preferences document found - user gets no notifications by default
                console.log(`   ❌ Follower ${followerId}: no preferences document (no notifications by default)`);
            }
        }
        catch (error) {
            console.error(`❌ Error checking preferences for follower ${followerId}:`, error);
            // On error, default to no notifications (safer approach)
            console.log(`   ❌ Follower ${followerId}: error occurred (no notifications by default)`);
        }
    }
    return eligibleFollowers;
}
// 🔍 Filter followers for "All members" alerts - only include users who have at least one group enabled
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
                    // No preferences set yet - allow first notification to help user understand they need to configure
                    console.log(`   🔄 Follower ${followerId}: no preferences set yet, allowing first "All members" notification`);
                    eligibleFollowers.push(followerId);
                }
                else {
                    // Check if user has ANY groups explicitly enabled (value === true)
                    const hasAnyGroupsEnabled = Object.values(groupPreferences).some(preference => preference === true);
                    if (hasAnyGroupsEnabled) {
                        eligibleFollowers.push(followerId);
                        console.log(`   ✅ Follower ${followerId}: has groups explicitly enabled`);
                    }
                    else {
                        console.log(`   ❌ Follower ${followerId}: no groups explicitly enabled`);
                    }
                }
            }
            else {
                // No preferences document found - user gets no notifications by default
                console.log(`   ❌ Follower ${followerId}: no preferences document (no notifications by default)`);
            }
        }
        catch (error) {
            console.error(`❌ Error checking preferences for follower ${followerId}:`, error);
            // On error, default to no notifications (safer approach)
            console.log(`   ❌ Follower ${followerId}: error occurred (no notifications by default)`);
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
                if (fcmToken && typeof fcmToken === 'string') {
                    tokens.push(fcmToken);
                    console.log(`   📱 Found FCM token for user ${userId}`);
                }
                else {
                    console.log(`   ⚠️ No FCM token for user ${userId}`);
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
    return tokens;
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
        const response = await admin.messaging().send(message);
        console.log(`✅ Test FCM notification sent successfully: ${response}`);
        return {
            success: true,
            messageId: response,
            timestamp: Date.now()
        };
    }
    catch (error) {
        console.error(`❌ Error sending test FCM notification:`, error);
        throw new functions.https.HttpsError('internal', 'Failed to send test notification');
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
//# sourceMappingURL=index.js.map