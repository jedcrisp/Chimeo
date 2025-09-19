import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin with explicit project configuration
admin.initializeApp({
  projectId: 'chimeo-96dfc'
});

interface OrganizationAlert {
  id: string;
  title: string;
  description: string;
  organizationId: string;
  organizationName: string;
  groupId?: string;
  groupName?: string;
  type: string;
  severity: string;
  postedBy: string;
  postedByUserId: string;
  isActive: boolean;
  createdAt: admin.firestore.Timestamp;
}

// 🚀 Main function: Send FCM notifications when alerts are posted
export const sendAlertNotifications = functions.firestore
  .document('organizations/{orgId}/alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const orgId = context.params.orgId;
    const alertId = context.params.alertId;
    const alert = snap.data() as OrganizationAlert;
    
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
      // Get organization followers from the correct structure: users/{userId}/followedOrganizations/{orgId}
      // We need to get all users who follow this organization by checking the subcollection
      const followersSnapshot = await admin.firestore()
        .collection('users')
        .get();
      
      // Filter users who follow this organization by checking their followedOrganizations subcollection
      console.log(`   🔍 Checking ${followersSnapshot.docs.length} users for followers of organization ${orgId}`);
      const followerIds: string[] = [];
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
            } else {
              console.log(`   🚫 User ${userDoc.id} is the alert creator - excluding from notifications`);
              console.log(`      Alert creator ID: ${alert.postedByUserId}`);
              console.log(`      Current user ID: ${userDoc.id}`);
              console.log(`      IDs match: ${userDoc.id === alert.postedByUserId}`);
            }
          }
        } catch (error) {
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
        eligibleFollowerIds = await filterFollowersByGroupPreferences(
          activeFollowerIds, 
          alert.groupId, 
          orgId
        );
        console.log(`✅ ${eligibleFollowerIds.length} followers have group '${alert.groupName}' enabled`);
      } else {
        // Alert is for "All members" - check if user has ANY groups enabled
        console.log(`🔍 Alert is for all members - checking if followers have any groups enabled`);
        eligibleFollowerIds = await filterFollowersForAllMembers(
          activeFollowerIds, 
          orgId
        );
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
          
          await admin.messaging().send(singleMessage);
          successCount++;
          console.log(`✅ Sent notification to unique token ${i + 1}/${uniqueFcmTokens.length}`);
        } catch (tokenError) {
          failureCount++;
          console.error(`❌ Failed to send to unique token ${i + 1}: ${tokenError instanceof Error ? tokenError.message : 'Unknown error'}`);
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
      
    } catch (error) {
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
async function filterFollowersByGroupPreferences(
  followerIds: string[], 
  groupId: string, 
  orgId: string
): Promise<string[]> {
  const eligibleFollowers: string[] = [];
  
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
        const groupPreferences = data?.groupPreferences || {};
        
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
          } catch (initError) {
            console.log(`   ⚠️ Could not initialize preference for ${followerId}: ${initError}`);
          }
          
          eligibleFollowers.push(followerId);
        } else if (groupPreferences[groupId] === true) {
          // User explicitly enabled this group
          eligibleFollowers.push(followerId);
          console.log(`   ✅ Follower ${followerId}: group explicitly enabled`);
        } else if (groupPreferences[groupId] === false) {
          // User explicitly disabled this group
          console.log(`   ❌ Follower ${followerId}: group explicitly disabled`);
        } else {
          // Any other value - default to enabled for safety
          console.log(`   🔄 Follower ${followerId}: unclear preference, defaulting to enabled`);
          eligibleFollowers.push(followerId);
        }
      } else {
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
        } catch (createError) {
          console.log(`   ⚠️ Could not create preferences for ${followerId}: ${createError}`);
          // Even if we can't create preferences, allow the notification
          eligibleFollowers.push(followerId);
        }
      }
    } catch (error) {
      console.error(`❌ Error checking preferences for follower ${followerId}:`, error);
      // On error, default to allowing notifications (more inclusive approach)
      console.log(`   🔄 Follower ${followerId}: error occurred, defaulting to enabled for safety`);
      eligibleFollowers.push(followerId);
    }
  }
  
  return eligibleFollowers;
}

// 🔍 Filter followers for "All members" alerts - include users who have any groups or no preferences set
async function filterFollowersForAllMembers(
  followerIds: string[], 
  orgId: string
): Promise<string[]> {
  const eligibleFollowers: string[] = [];
  
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
        const groupPreferences = data?.groupPreferences || {};
        
        if (Object.keys(groupPreferences).length === 0) {
          // No preferences set yet - allow notification by default
          console.log(`   🔄 Follower ${followerId}: no preferences set yet, allowing "All members" notification by default`);
          eligibleFollowers.push(followerId);
        } else {
          // Check if user has ANY groups explicitly enabled (value === true)
          // OR if they have no explicit preferences (undefined values)
          const hasExplicitlyEnabledGroups = Object.values(groupPreferences).some(preference => preference === true);
          const hasExplicitlyDisabledGroups = Object.values(groupPreferences).some(preference => preference === false);
          
          if (hasExplicitlyEnabledGroups) {
            // User has some groups enabled
            eligibleFollowers.push(followerId);
            console.log(`   ✅ Follower ${followerId}: has groups explicitly enabled`);
          } else if (hasExplicitlyDisabledGroups && !hasExplicitlyEnabledGroups) {
            // User has only disabled groups and no enabled ones
            console.log(`   ❌ Follower ${followerId}: only has disabled groups`);
          } else {
            // Mixed or unclear preferences - default to enabled for safety
            console.log(`   🔄 Follower ${followerId}: mixed preferences, defaulting to enabled`);
            eligibleFollowers.push(followerId);
          }
        }
      } else {
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
        } catch (createError) {
          console.log(`   ⚠️ Could not create preferences for ${followerId}: ${createError}`);
          // Even if we can't create preferences, allow the notification
          eligibleFollowers.push(followerId);
        }
      }
    } catch (error) {
      console.error(`❌ Error checking preferences for follower ${followerId}:`, error);
      // On error, default to allowing notifications (more inclusive approach)
      console.log(`   🔄 Follower ${followerId}: error occurred, defaulting to enabled for safety`);
      eligibleFollowers.push(followerId);
    }
  }
  
  return eligibleFollowers;
}

// 📱 Get FCM tokens for users
async function getFCMTokensForUsers(userIds: string[]): Promise<string[]> {
  const tokens: string[] = [];
  
  for (const userId of userIds) {
    try {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      if (userDoc.exists) {
        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;
        
        if (fcmToken && typeof fcmToken === 'string' && fcmToken.trim().length > 0) {
          // Basic FCM token validation (should be a long string)
          if (fcmToken.length > 100) {
            tokens.push(fcmToken);
            console.log(`   📱 Found valid FCM token for user ${userId} (length: ${fcmToken.length})`);
          } else {
            console.log(`   ⚠️ FCM token for user ${userId} seems too short (length: ${fcmToken.length})`);
          }
        } else {
          console.log(`   ⚠️ No valid FCM token for user ${userId} (token: ${fcmToken || 'undefined'})`);
        }
      } else {
        console.log(`   ❌ User document not found: ${userId}`);
      }
    } catch (error) {
      console.error(`❌ Error getting FCM token for user ${userId}:`, error);
    }
  }
  
  console.log(`📱 Total valid FCM tokens found: ${tokens.length}/${userIds.length}`);
  return tokens;
}

// 🔄 Enhanced FCM token management for cross-platform support
async function updateUserFCMToken(userId: string, token: string, platform: string = 'unknown') {
  try {
    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    
    const updateData: any = {
      fcmToken: token,
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
      platform: platform,
      tokenStatus: 'active'
    };
    
    // Add platform-specific fields
    if (platform === 'ios') {
      updateData.iosToken = token;
      updateData.iosLastUpdate = admin.firestore.FieldValue.serverTimestamp();
    } else if (platform === 'web') {
      updateData.webToken = token;
      updateData.webLastUpdate = admin.firestore.FieldValue.serverTimestamp();
    }
    
    await userRef.update(updateData);
    console.log(`✅ FCM token updated for user ${userId} (platform: ${platform})`);
    
    return true;
  } catch (error) {
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
      const fcmToken = userData?.fcmToken;
      
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
        } catch (error) {
          console.log(`   ⚠️ Could not clean token for user ${userDoc.id}: ${error}`);
        }
      }
    }
    
    console.log(`✅ FCM token cleanup completed: ${cleanedCount} tokens cleaned`);
    return cleanedCount;
    
  } catch (error) {
    console.error('❌ Error during FCM token cleanup:', error);
    return 0;
  }
}

// 🎯 Get severity prefix for notifications
function getSeverityPrefix(severity: string): string {
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
export const testFCMNotification = functions.https.onCall(async (data, context) => {
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
    const fcmToken = userData?.fcmToken;
    
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
    
  } catch (error) {
    console.error(`❌ Error sending test FCM notification:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to send test notification');
  }
});

// 🔍 Debug function to check FCM token status for all users
export const debugFCMTokens = functions.https.onCall(async (data, context) => {
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
      tokenDetails: [] as any[]
    };
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;
      
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
        } else {
          userStats.invalidTokens++;
          userStats.tokenDetails.push({
            userId: userDoc.id,
            hasToken: true,
            tokenLength: fcmToken.length,
            tokenPreview: fcmToken,
            issue: 'Token too short'
          });
        }
      } else {
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
    
  } catch (error) {
    console.error(`❌ Error debugging FCM tokens:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to debug FCM tokens');
  }
});

// 🔄 Migration functions
export { migrateFollowers, cleanupOldFollowers } from './migrateFollowers';

// 🔧 Follower count fix functions
export { fixFollowerCounts, fixOrganizationFollowerCount } from './fixFollowerCounts';

// 🧪 Test FCM function
export { testFCM } from './testFCM';

// 🧪 Simple FCM test function
export { simpleFCMTest } from './simpleFCMTest';

// 📱 iOS FCM Token Management Function
export const manageIOSFCMToken = functions.https.onCall(async (data, context) => {
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
        } else {
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
          const currentToken = userData?.fcmToken;
          const isValid = currentToken === token && currentToken && currentToken.length > 100;
          
          console.log(`🔍 Token validation for user ${userId}: ${isValid ? 'VALID' : 'INVALID'}`);
          return { 
            success: true, 
            isValid: isValid,
            hasToken: !!currentToken,
            tokenLength: currentToken?.length || 0
          };
        } else {
          throw new functions.https.HttpsError('not-found', 'User not found');
        }
        
      default:
        throw new functions.https.HttpsError('invalid-argument', 'Invalid action specified');
    }
    
  } catch (error) {
    console.error(`❌ Error in iOS FCM token management:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to manage FCM token');
  }
});

// 🧹 FCM Token Cleanup Function
export const cleanupFCMTokens = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  // Only allow admins to run cleanup
  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || !userDoc.data()?.isAdmin) {
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
    
  } catch (error) {
    console.error(`❌ Error during FCM token cleanup:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to cleanup FCM tokens');
  }
});

// 🏢 Send notifications to admins when new organization requests are submitted
export const notifyAdminsOfOrganizationRequest = functions.firestore
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
        } catch (error) {
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
      
    } catch (error) {
      console.error(`❌ Error sending admin notifications:`, error);
      await snap.ref.update({
        adminNotificationsSent: false,
        adminNotificationError: error instanceof Error ? error.message : 'Unknown error',
        adminNotificationErrorAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  });

