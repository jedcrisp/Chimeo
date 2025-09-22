import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Simple FCM diagnostic function
export const simpleFCMTest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    console.log('🧪 Running simple FCM test...');
    
    // Get project info
    const projectId = process.env.GCLOUD_PROJECT || 'unknown';
    console.log(`📋 Project ID: ${projectId}`);
    
    // Check if Firebase Admin is initialized
    let app;
    try {
      app = admin.app();
      console.log('✅ Firebase Admin app initialized');
    } catch (error) {
      console.error('❌ Firebase Admin app not initialized:', error);
      throw new functions.https.HttpsError('internal', 'Firebase Admin not initialized');
    }
    
    // Check project configuration
    const config = app.options;
    console.log('📋 Firebase config:', {
      projectId: config.projectId,
      credential: config.credential ? 'present' : 'missing',
      databaseURL: config.databaseURL || 'missing'
    });
    
    // Test FCM messaging instance
    let messaging;
    try {
      messaging = admin.messaging();
      console.log('✅ FCM messaging instance created');
    } catch (error) {
      console.error('❌ Failed to create FCM messaging instance:', error);
      throw new functions.https.HttpsError('internal', 'Failed to create FCM messaging instance');
    }
    
    // Test FCM API with a dummy message (this will fail but tells us about API availability)
    const testMessage = {
      notification: {
        title: 'FCM API Test',
        body: 'Testing FCM API endpoint availability'
      },
      token: 'dummy-token-for-testing'
    };
    
    try {
      await messaging.send(testMessage);
      console.log('✅ FCM API test passed (unexpected)');
      return { success: true, message: 'FCM API is working' };
    } catch (apiError) {
      console.log('🔍 FCM API test result:', apiError);
      
      if (apiError instanceof Error) {
        if (apiError.message.includes('InvalidRegistration')) {
          console.log('✅ FCM API is accessible (got expected InvalidRegistration)');
          return { 
            success: true, 
            message: 'FCM API is accessible - InvalidRegistration error is expected with dummy token',
            error: apiError.message
          };
        } else if (apiError.message.includes('404')) {
          console.error('❌ FCM API 404 error - project may not have FCM enabled');
          return { 
            success: false, 
            message: 'FCM API 404 error - project may not have FCM enabled',
            error: apiError.message,
            suggestion: 'Check if FCM is enabled in Firebase Console'
          };
        } else if (apiError.message.includes('403')) {
          console.error('❌ FCM API 403 error - permission denied');
          return { 
            success: false, 
            message: 'FCM API 403 error - permission denied',
            error: apiError.message,
            suggestion: 'Check service account permissions'
          };
        } else {
          console.error('❌ FCM API error:', apiError.message);
          return { 
            success: false, 
            message: 'FCM API error',
            error: apiError.message
          };
        }
      } else {
        console.error('❌ Unknown FCM API error:', apiError);
        return { 
          success: false, 
          message: 'Unknown FCM API error',
          error: String(apiError)
        };
      }
    }
    
  } catch (error) {
    console.error('❌ Simple FCM test failed:', error);
    throw new functions.https.HttpsError('internal', 'Simple FCM test failed');
  }
});
