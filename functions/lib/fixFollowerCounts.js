"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fixOrganizationFollowerCount = exports.fixFollowerCounts = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
// 🔧 Function to fix corrupted follower counts
exports.fixFollowerCounts = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    try {
        console.log('🔧 Starting follower count fix...');
        const db = admin.firestore();
        // Get all organizations
        const orgsSnapshot = await db.collection('organizations').get();
        console.log(`📋 Found ${orgsSnapshot.size} organizations to check`);
        let totalFixed = 0;
        for (const orgDoc of orgsSnapshot.docs) {
            const orgId = orgDoc.id;
            const orgData = orgDoc.data();
            const currentFollowerCount = orgData.followerCount || 0;
            console.log(`🔍 Checking organization: ${orgId}`);
            console.log(`   Current follower count: ${currentFollowerCount}`);
            // Count actual followers from the new structure
            const followersSnapshot = await db.collection('organizations')
                .doc(orgId)
                .collection('followers')
                .get();
            const actualCount = followersSnapshot.docs.length;
            console.log(`   Actual follower count: ${actualCount}`);
            // If counts don't match, fix it
            if (currentFollowerCount !== actualCount) {
                console.log(`   ❌ Count mismatch detected! Fixing...`);
                await db.collection('organizations')
                    .doc(orgId)
                    .update({
                    followerCount: actualCount,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                console.log(`   ✅ Fixed follower count: ${currentFollowerCount} → ${actualCount}`);
                totalFixed++;
            }
            else {
                console.log(`   ✅ Count is correct`);
            }
        }
        console.log(`🎉 Follower count fix completed! Fixed ${totalFixed} organizations`);
        return {
            success: true,
            organizationsChecked: orgsSnapshot.size,
            totalFixed: totalFixed,
            message: 'Follower counts have been corrected'
        };
    }
    catch (error) {
        console.error('❌ Follower count fix failed:', error);
        throw new functions.https.HttpsError('internal', 'Fix failed: ' + (error instanceof Error ? error.message : 'Unknown error'));
    }
});
// 🔧 Function to fix a specific organization's follower count
exports.fixOrganizationFollowerCount = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { organizationId } = data;
    if (!organizationId) {
        throw new functions.https.HttpsError('invalid-argument', 'Organization ID is required');
    }
    try {
        console.log(`🔧 Fixing follower count for organization: ${organizationId}`);
        const db = admin.firestore();
        // Count actual followers
        const followersSnapshot = await db.collection('organizations')
            .doc(organizationId)
            .collection('followers')
            .get();
        const actualCount = followersSnapshot.docs.length;
        console.log(`   Actual follower count: ${actualCount}`);
        // Update the organization document
        await db.collection('organizations')
            .doc(organizationId)
            .update({
            followerCount: actualCount,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`✅ Fixed follower count for ${organizationId}: ${actualCount}`);
        return {
            success: true,
            organizationId: organizationId,
            newFollowerCount: actualCount,
            message: 'Organization follower count has been corrected'
        };
    }
    catch (error) {
        console.error('❌ Organization follower count fix failed:', error);
        throw new functions.https.HttpsError('internal', 'Fix failed: ' + (error instanceof Error ? error.message : 'Unknown error'));
    }
});
//# sourceMappingURL=fixFollowerCounts.js.map