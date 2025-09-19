import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Firebase Admin is already initialized in index.ts, so we don't need to initialize again
// admin.initializeApp();

// 🔄 Migration function to restructure followers
export const migrateFollowers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    console.log('🔄 Starting follower migration...');
    
    const db = admin.firestore();
    
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`📋 Found ${orgsSnapshot.size} organizations to migrate`);
    
    let totalMigrated = 0;
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      
      console.log(`🔄 Migrating followers for organization: ${orgData.name || orgId}`);
      
      // Check if organization already has the new followers structure
      const followersSnapshot = await db.collection('organizations').doc(orgId).collection('followers').get();
      
      if (followersSnapshot.size > 0) {
        console.log(`   ⏭️ Organization ${orgId} already has new structure (${followersSnapshot.size} followers)`);
        continue;
      }
      
      // Get followers from the old organizationFollowers collection
      const oldFollowersDoc = await db.collection('organizationFollowers').doc(orgId).get();
      
      if (!oldFollowersDoc.exists) {
        console.log(`   ℹ️ No old followers found for organization ${orgId}`);
        continue;
      }
      
      const oldFollowersData = oldFollowersDoc.data();
      const oldFollowers = oldFollowersData?.followers as string[] || [];
      
      if (oldFollowers.length === 0) {
        console.log(`   ℹ️ No followers to migrate for organization ${orgId}`);
        continue;
      }
      
      console.log(`   📋 Found ${oldFollowers.length} followers to migrate`);
      
      // Migrate each follower to the new structure
      for (const followerId of oldFollowers) {
        try {
          // Get user's group preferences from the old structure
          const userOrgDoc = await db.collection('users')
            .doc(followerId)
            .collection('followedOrganizations')
            .doc(orgId)
            .get();
          
          let groupPreferences: { [key: string]: boolean } = {};
          
          if (userOrgDoc.exists) {
            const userOrgData = userOrgDoc.data();
            groupPreferences = userOrgData?.groupPreferences || {};
          }
          
          // Create the new follower document
          await db.collection('organizations')
            .doc(orgId)
            .collection('followers')
            .doc(followerId)
            .set({
              userId: followerId,
              organizationId: orgId,
              followedAt: oldFollowersData?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
              groupPreferences: groupPreferences,
              alertsEnabled: true,
              createdAt: oldFollowersData?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          
          console.log(`   ✅ Migrated follower: ${followerId}`);
          
        } catch (error) {
          console.error(`   ❌ Error migrating follower ${followerId}:`, error);
        }
      }
      
      // Update organization document with follower count
      await db.collection('organizations').doc(orgId).update({
        followerCount: oldFollowers.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      totalMigrated += oldFollowers.length;
      console.log(`   ✅ Completed migration for organization ${orgId}`);
    }
    
    console.log(`🎉 Migration completed! Total followers migrated: ${totalMigrated}`);
    
    return {
      success: true,
      organizationsProcessed: orgsSnapshot.size,
      totalFollowersMigrated: totalMigrated,
      message: 'Follower migration completed successfully'
    };
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw new functions.https.HttpsError('internal', 'Migration failed: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
});

// 🧹 Cleanup function to remove old follower data (optional)
export const cleanupOldFollowers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    console.log('🧹 Starting cleanup of old follower data...');
    
    const db = admin.firestore();
    
    // Get all old follower documents
    const oldFollowersSnapshot = await db.collection('organizationFollowers').get();
    console.log(`📋 Found ${oldFollowersSnapshot.size} old follower documents to clean up`);
    
    let totalCleaned = 0;
    
    for (const doc of oldFollowersSnapshot.docs) {
      try {
        await doc.ref.delete();
        totalCleaned++;
        console.log(`   ✅ Cleaned up old follower document: ${doc.id}`);
      } catch (error) {
        console.error(`   ❌ Error cleaning up ${doc.id}:`, error);
      }
    }
    
    console.log(`🎉 Cleanup completed! Total documents cleaned: ${totalCleaned}`);
    
    return {
      success: true,
      totalCleaned: totalCleaned,
      message: 'Old follower data cleanup completed'
    };
    
  } catch (error) {
    console.error('❌ Cleanup failed:', error);
    throw new functions.https.HttpsError('internal', 'Cleanup failed: ' + (error instanceof Error ? error.message : 'Unknown error'));
  }
});
