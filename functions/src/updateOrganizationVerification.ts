import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Cloud Function to update existing organizations to have verified: true
export const updateOrganizationVerification = functions.https.onCall(async (data, context) => {
  // Only allow authenticated users to call this function
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  console.log('🔄 Updating existing organizations to set verified: true...');
  
  try {
    const db = admin.firestore();
    
    // Get all organizations
    const snapshot = await db.collection('organizations').get();
    console.log(`📊 Found ${snapshot.docs.length} organizations`);
    
    const batch = db.batch();
    let updateCount = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Only update if verified field is missing or false
      if (data.verified !== true) {
        console.log(`📝 Updating organization: ${doc.id} (${data.name || 'Unknown'})`);
        batch.update(doc.ref, { 
          verified: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        updateCount++;
      } else {
        console.log(`✅ Organization already verified: ${doc.id} (${data.name || 'Unknown'})`);
      }
    }
    
    if (updateCount > 0) {
      await batch.commit();
      console.log(`✅ Successfully updated ${updateCount} organizations`);
      return { 
        success: true, 
        message: `Successfully updated ${updateCount} organizations`,
        updatedCount: updateCount
      };
    } else {
      console.log('✅ All organizations already have verified: true');
      return { 
        success: true, 
        message: 'All organizations already have verified: true',
        updatedCount: 0
      };
    }
    
  } catch (error) {
    console.error('❌ Error updating organizations:', error);
    throw new functions.https.HttpsError('internal', `Failed to update organizations: ${error}`);
  }
});
