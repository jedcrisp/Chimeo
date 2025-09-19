import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Simple FCM test function
export const simpleFCMTest = functions.https.onCall(async (data, context) => {
  try {
    console.log('🧪 Starting simple FCM test...');
    
    // Test 1: Check if Firebase Admin is properly initialized
    console.log('✅ Firebase Admin initialized');
    console.log('   Project ID:', admin.app().options.projectId);
    
    // Test 2: Check if messaging is available
    const messaging = admin.messaging();
    console.log('✅ Messaging service available');
    
    // Test 3: Try to send a simple message to a test token
    // This will fail, but we'll get a better error message
    const testToken = 'test_token_123';
    
    console.log('📤 Attempting to send test FCM message...');
    const response = await messaging.send({
      token: testToken,
      notification: {
        title: 'Test',
        body: 'Test message'
      }
    });
    
    return { success: true, messageId: response };
    
  } catch (error) {
    console.error('❌ FCM test failed:', error);
    
    // Provide detailed error information
    let errorType = 'unknown';
    let errorDetails = '';
    
    if (error instanceof Error) {
      errorType = error.constructor.name;
      errorDetails = error.message;
      
      if (error.message.includes('404')) {
        errorType = 'API_NOT_FOUND';
        errorDetails = 'The FCM API endpoint was not found. This usually means the Cloud Messaging API is not enabled.';
      } else if (error.message.includes('403')) {
        errorType = 'PERMISSION_DENIED';
        errorDetails = 'Permission denied. The service account needs Firebase Admin and Cloud Messaging Admin roles.';
      } else if (error.message.includes('401')) {
        errorType = 'UNAUTHORIZED';
        errorDetails = 'Unauthorized. Check service account credentials and permissions.';
      }
    }
    
    return {
      success: false,
      errorType,
      errorDetails,
      fullError: error instanceof Error ? error.message : String(error)
    };
  }
});
