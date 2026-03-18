/**
 * Firebase Cloud Functions for Surgery Scheduling App
 * 
 * These functions handle:
 * - Sending SMS notifications for new surgery schedules
 * - Sending SMS reminders for upcoming surgeries
 * - Notifying of surgery updates
 * - Notifying of surgery status changes
 * - Sending push notifications to devices
 * - Sending email notifications
 * 
 * Uses Twilio as the SMS service provider and Firebase Messaging for push notifications
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const dotenv = require('dotenv');
const twilio = require('twilio');

// Load environment variables
dotenv.config();

// Initialize Firebase Admin SDK
admin.initializeApp();

// Initialize Twilio client
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);
const twilioNumber = process.env.TWILIO_PHONE_NUMBER;

// Log Twilio initialization
console.log('Twilio client initialized:');
console.log('Account SID provided:', !!process.env.TWILIO_ACCOUNT_SID);
console.log('Auth Token provided:', !!process.env.TWILIO_AUTH_TOKEN);
console.log('Phone Number:', process.env.TWILIO_PHONE_NUMBER);

/**
 * Formats a date for SMS messages
 * @param {Date} date - Date object to format
 * @return {Object} - Object containing formatted date and time strings
 */
function formatDate(date) {
  const dateOptions = { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' };
  const timeOptions = { hour: 'numeric', minute: 'numeric', hour12: true };
  
  return {
    date: date.toLocaleDateString('en-US', dateOptions),
    time: date.toLocaleTimeString('en-US', timeOptions)
  };
}

/**
 * Gets a list of personnel phone numbers for a surgery
 * @param {Object} surgeryData - The surgery data
 * @return {Promise<Array>} - Array of user data objects with contact information
 */
async function getPersonnelData(surgeryData) {
  const personnel = [];
  const userData = [];
  
  // Get surgeon
  if (surgeryData.surgeon) {
    personnel.push({ name: surgeryData.surgeon, type: 'surgeon' });
  }
  
  // Get nurses
  if (surgeryData.nurses && Array.isArray(surgeryData.nurses)) {
    surgeryData.nurses.forEach(nurse => {
      personnel.push({ name: nurse, type: 'nurse' });
    });
  }
  
  // Get technologists
  if (surgeryData.technologists && Array.isArray(surgeryData.technologists)) {
    surgeryData.technologists.forEach(tech => {
      personnel.push({ name: tech, type: 'technologist' });
    });
  }
  
  // Query Firestore for user data
  for (const person of personnel) {
    const firstName = person.name.split(' ')[0];
    const snapshot = await admin.firestore()
      .collection('users')
      .where('firstName', '==', firstName)
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      const user = snapshot.docs[0];
      const data = user.data();
      
      userData.push({
        userId: user.id,
        name: person.name,
        type: person.type,
        phoneNumber: data.phoneNumber || null,
        email: data.email || null,
        fcmTokens: data.fcmTokens || []
      });
    }
  }
  
  return userData;
}

/**
 * Checks if user has enabled notifications of a specific type and channel
 * @param {string} userId - The user ID
 * @param {string} notificationType - The notification type (scheduled, approaching, update, status)
 * @param {string} channel - The notification channel (sms, push, email)
 * @return {Promise<boolean>} - Whether notifications are enabled
 */
async function isNotificationEnabled(userId, notificationType, channel) {
  try {
    // Check if the user exists
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) return false;
    
    // First check general notification setting
    const userData = userDoc.data();
    const notificationsEnabled = userData.notifications !== false;
    
    if (!notificationsEnabled) return false;
    
    // Then check specific notification settings
    const settingsDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('notifications')
      .get();
    
    if (!settingsDoc.exists) {
      // Default values if no settings document exists
      if (channel === 'email') return false;
      return true;
    }
    
    const settings = settingsDoc.data();
    
    // Check if the channel is enabled (e.g., sms_enabled, push_enabled, email_enabled)
    const channelEnabled = settings[`${channel}_enabled`] !== false;
    
    if (!channelEnabled) return false;
    
    // Check specific notification type for the channel
    const typeEnabled = settings[`${channel}_${notificationType}_enabled`] !== false;
    
    return typeEnabled;
  } catch (error) {
    console.error('Error checking notification settings:', error);
    return false;
  }
}

/**
 * Sends an SMS via Twilio
 * @param {string} to - The recipient's phone number
 * @param {string} body - The message to send
 * @returns {Promise<boolean>} Success status
 */
async function sendSMS(to, body) {
  try {
    if (!to || !body) {
      console.error('Invalid phone number or message');
      return false;
    }

    // Format number if needed
    let formattedNumber = to;
    if (!to.startsWith('+')) {
      formattedNumber = `+${to}`;
    }

    // Log Twilio credentials (masked)
    console.log('Twilio configuration check:');
    console.log('Account SID exists:', !!process.env.TWILIO_ACCOUNT_SID);
    console.log('Auth Token exists:', !!process.env.TWILIO_AUTH_TOKEN);
    console.log('Phone Number:', process.env.TWILIO_PHONE_NUMBER);
    
    // Verify twilioClient is initialized properly
    if (!twilioClient) {
      console.error('Twilio client is not initialized properly');
      return false;
    }

    const message = await twilioClient.messages.create({
      body: body,
      from: twilioNumber,
      to: formattedNumber
    });

    console.log(`SMS sent to ${formattedNumber}, SID: ${message.sid}`);
    return true;
  } catch (error) {
    console.error('Error sending SMS:', error.message);
    console.error('Error details:', JSON.stringify({
      code: error.code,
      status: error.status,
      moreInfo: error.moreInfo
    }));
    return false;
  }
}

/**
 * Sends a push notification via FCM
 * @param {Array<string>} tokens - FCM tokens to send to
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Additional data to send
 * @return {Promise<boolean>} - Whether the notification was sent
 */
async function sendPushNotification(tokens, title, body, data) {
  if (!tokens || tokens.length === 0) return false;
  
  try {
    // Message payload
    const message = {
      notification: {
        title: title,
        body: body
      },
      data: data,
      tokens: tokens
    };
    
    // Send to all tokens
    const response = await admin.messaging().sendMulticast(message);
    
    // Log success and failures
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
        }
      });
      console.log('List of tokens that caused failures:', failedTokens);
    }
    
    console.log(`Successfully sent push notifications to ${response.successCount} devices`);
    return response.successCount > 0;
  } catch (error) {
    console.error('Error sending push notification:', error);
    return false;
  }
}

/**
 * Stores a notification in Firestore for in-app display
 * @param {string} userId - User ID to store notification for
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Additional data about the notification
 */
async function storeNotification(userId, title, body, data) {
  try {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        title: title,
        body: body,
        data: data,
        read: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    
    console.log(`Notification stored for user ${userId}`);
    return true;
  } catch (error) {
    console.error(`Error storing notification for user ${userId}:`, error);
    return false;
  }
}

/**
 * Sends notifications to a user through all enabled channels
 * @param {Object} recipient - User data object
 * @param {string} notificationType - Type of notification
 * @param {string} smsMessage - SMS message content
 * @param {string} pushTitle - Push notification title
 * @param {string} pushBody - Push notification body
 * @param {Object} data - Additional data for the notification
 */
async function sendToUser(recipient, notificationType, smsMessage, pushTitle, pushBody, data) {
  try {
    const userId = recipient.userId;
    
    // Check and send SMS
    const smsEnabled = await isNotificationEnabled(userId, notificationType, 'sms');
    if (smsEnabled && recipient.phoneNumber) {
      await sendSMS(recipient.phoneNumber, smsMessage);
    }
    
    // Check and send push notification
    const pushEnabled = await isNotificationEnabled(userId, notificationType, 'push');
    if (pushEnabled && recipient.fcmTokens && recipient.fcmTokens.length > 0) {
      await sendPushNotification(recipient.fcmTokens, pushTitle, pushBody, {
        ...data,
        userId: userId
      });
    }
    
    // Always store for in-app
    await storeNotification(userId, pushTitle, pushBody, data);
    
  } catch (error) {
    console.error(`Error sending notifications to user ${recipient.userId}:`, error);
  }
}

/**
 * Cloud Function triggered when a new surgery is created
 * Sends notifications to patients, doctors, and staff
 */
exports.onSurgeryCreated = functions.firestore
  .document('surgeries/{surgeryId}')
  .onCreate(async (snapshot, context) => {
    try {
      const surgeryData = snapshot.data();
      const surgeryId = context.params.surgeryId;
      
      // Extract surgery information
      const surgeryType = surgeryData.surgeryType || 'surgery';
      const startTime = surgeryData.startTime.toDate();
      const formattedTime = startTime.toLocaleString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: 'numeric',
        minute: 'numeric',
        hour12: true
      });
      
      // Get user IDs involved in the surgery
      const doctorId = surgeryData.doctorId;
      const involvedStaff = [...(surgeryData.nurses || []), ...(surgeryData.technologists || [])];
      
      // Create notification content
      const title = 'Surgery Scheduled';
      const body = `A ${surgeryType} has been scheduled for ${formattedTime}`;
      
      // Notification data for storing in Firestore
      const notificationData = {
        title,
        body,
        data: {
          type: 'scheduled',
          surgeryId,
        },
        read: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Send notifications to doctor
      if (doctorId) {
        const doctorDoc = await admin.firestore().collection('users').doc(doctorId).get();
        if (doctorDoc.exists) {
          const doctorData = doctorDoc.data();
          
          // Store in-app notification
          await admin.firestore()
            .collection('users')
            .doc(doctorId)
            .collection('notifications')
            .add(notificationData);
          
          // Send SMS if enabled
          if (doctorData.enableSmsNotifications && doctorData.phoneNumber) {
            await sendSMS(doctorData.phoneNumber, body);
          }
          
          // Send push notification if tokens exist
          if (doctorData.fcmTokens && doctorData.fcmTokens.length > 0) {
            for (const token of doctorData.fcmTokens) {
              try {
                await admin.messaging().send({
                  token,
                  notification: {
                    title,
                    body,
                  },
                  data: {
                    surgeryId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                });
              } catch (error) {
                console.error('Error sending push notification:', error);
              }
            }
          }
        }
      }
      
      // Process staff notifications
      for (const staffId of involvedStaff) {
        if (!staffId) continue;
        
        const staffDoc = await admin.firestore().collection('users').doc(staffId).get();
        if (staffDoc.exists) {
          const staffData = staffDoc.data();
          
          // Store in-app notification
          await admin.firestore()
            .collection('users')
            .doc(staffId)
            .collection('notifications')
            .add(notificationData);
          
          // Send SMS if enabled
          if (staffData.enableSmsNotifications && staffData.phoneNumber) {
            await sendSMS(staffData.phoneNumber, body);
          }
          
          // Send push notification if tokens exist
          if (staffData.fcmTokens && staffData.fcmTokens.length > 0) {
            for (const token of staffData.fcmTokens) {
              try {
                await admin.messaging().send({
                  token,
                  notification: {
                    title,
                    body,
                  },
                  data: {
                    surgeryId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                });
              } catch (error) {
                console.error('Error sending push notification:', error);
              }
            }
          }
        }
      }
      
      console.log(`Successfully processed notifications for surgery ${surgeryId}`);
      return null;
    } catch (error) {
      console.error('Error in onSurgeryCreated function:', error);
      return null;
    }
  });

/**
 * Cloud Function triggered when a surgery is updated
 * Sends notifications about changes to relevant users
 */
exports.onSurgeryUpdated = functions.firestore
  .document('surgeries/{surgeryId}')
  .onUpdate(async (change, context) => {
    try {
      const surgeryId = context.params.surgeryId;
      const oldData = change.before.data();
      const newData = change.after.data();
      
      // Check what changed
      const timeChanged = oldData.startTime.toDate().toISOString() !== newData.startTime.toDate().toISOString();
      const statusChanged = oldData.status !== newData.status;
      const roomChanged = oldData.room !== newData.room;
      
      // If nothing significant changed, exit early
      if (!timeChanged && !statusChanged && !roomChanged) {
        console.log('No significant changes detected for notifications');
        return null;
      }
      
      // Extract surgery information
      const surgeryType = newData.surgeryType || 'surgery';
      const startTime = newData.startTime.toDate();
      const formattedTime = startTime.toLocaleString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: 'numeric',
        minute: 'numeric',
        hour12: true
      });
      
      // Get user IDs involved in the surgery
      const doctorId = newData.doctorId;
      const involvedStaff = [...(newData.nurses || []), ...(newData.technologists || [])];
      
      // Create appropriate notification based on what changed
      let title, body, notificationType;
      
      if (statusChanged) {
        title = 'Surgery Status Changed';
        body = `The ${surgeryType} has changed from "${oldData.status}" to "${newData.status}"`;
        notificationType = 'status';
      } else if (timeChanged) {
        title = 'Surgery Time Updated';
        body = `The ${surgeryType} has been rescheduled to ${formattedTime}`;
        notificationType = 'update';
      } else if (roomChanged) {
        title = 'Surgery Room Changed';
        body = `The ${surgeryType} has been moved to ${newData.room}`;
        notificationType = 'update';
      } else {
        title = 'Surgery Updated';
        body = `The ${surgeryType} scheduled for ${formattedTime} has been updated`;
        notificationType = 'update';
      }
      
      // Notification data for storing in Firestore
      const notificationData = {
        title,
        body,
        data: {
          type: notificationType,
          surgeryId,
          oldStatus: statusChanged ? oldData.status : undefined,
          newStatus: statusChanged ? newData.status : undefined,
        },
        read: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Collect all user IDs to notify
      const userIdsToNotify = new Set();
      if (doctorId) userIdsToNotify.add(doctorId);
      involvedStaff.forEach(id => {
        if (id) userIdsToNotify.add(id);
      });
      
      // Send notifications to all users
      for (const userId of userIdsToNotify) {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          
          // Store in-app notification
          await admin.firestore()
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add(notificationData);
          
          // Send SMS if enabled
          if (userData.enableSmsNotifications && userData.phoneNumber) {
            await sendSMS(userData.phoneNumber, body);
          }
          
          // Send push notification if tokens exist
          if (userData.fcmTokens && userData.fcmTokens.length > 0) {
            for (const token of userData.fcmTokens) {
              try {
                await admin.messaging().send({
                  token,
                  notification: {
                    title,
                    body,
                  },
                  data: {
                    surgeryId,
                    type: notificationType,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                });
              } catch (error) {
                console.error('Error sending push notification:', error);
              }
            }
          }
        }
      }
      
      console.log(`Successfully processed update notifications for surgery ${surgeryId}`);
      return null;
    } catch (error) {
      console.error('Error in onSurgeryUpdated function:', error);
      return null;
    }
  });

/**
 * Scheduled Cloud Function to send reminders for upcoming surgeries
 * Runs every hour and checks for surgeries 1 hour and 24 hours away
 */
exports.sendSurgeryReminders = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      const nowDate = now.toDate();
      
      // Calculate time thresholds (1 hour and 24 hours from now)
      const oneHourFromNow = new Date(nowDate);
      oneHourFromNow.setHours(oneHourFromNow.getHours() + 1);
      
      const twentyFourHoursFromNow = new Date(nowDate);
      twentyFourHoursFromNow.setHours(twentyFourHoursFromNow.getHours() + 24);
      
      // Time ranges for queries (with 5-minute buffer)
      const oneHourLower = admin.firestore.Timestamp.fromDate(new Date(oneHourFromNow.getTime() - 5 * 60 * 1000));
      const oneHourUpper = admin.firestore.Timestamp.fromDate(new Date(oneHourFromNow.getTime() + 5 * 60 * 1000));
      
      const twentyFourHoursLower = admin.firestore.Timestamp.fromDate(new Date(twentyFourHoursFromNow.getTime() - 5 * 60 * 1000));
      const twentyFourHoursUpper = admin.firestore.Timestamp.fromDate(new Date(twentyFourHoursFromNow.getTime() + 5 * 60 * 1000));
      
      // Find surgeries happening in about 1 hour
      const oneHourSurgeries = await admin.firestore()
        .collection('surgeries')
        .where('startTime', '>=', oneHourLower)
        .where('startTime', '<=', oneHourUpper)
        .where('status', '==', 'Scheduled')
        .get();
      
      // Find surgeries happening in about 24 hours
      const twentyFourHourSurgeries = await admin.firestore()
        .collection('surgeries')
        .where('startTime', '>=', twentyFourHoursLower)
        .where('startTime', '<=', twentyFourHoursUpper)
        .where('status', '==', 'Scheduled')
        .get();
      
      // Process 1-hour reminders
      for (const doc of oneHourSurgeries.docs) {
        const surgeryData = doc.data();
        const surgeryId = doc.id;
        
        await processSurgeryReminder(surgeryData, surgeryId, '1 hour');
      }
      
      // Process 24-hour reminders
      for (const doc of twentyFourHourSurgeries.docs) {
        const surgeryData = doc.data();
        const surgeryId = doc.id;
        
        await processSurgeryReminder(surgeryData, surgeryId, '24 hours');
      }
      
      console.log(`Processed reminders: ${oneHourSurgeries.size} 1-hour reminders, ${twentyFourHourSurgeries.size} 24-hour reminders`);
      return null;
    } catch (error) {
      console.error('Error in sendSurgeryReminders function:', error);
      return null;
    }
  });

/**
 * Helper function to process surgery reminders and send notifications
 */
async function processSurgeryReminder(surgeryData, surgeryId, timeRemaining) {
  try {
    // Extract surgery information
    const surgeryType = surgeryData.surgeryType || 'surgery';
    const startTime = surgeryData.startTime.toDate();
    const formattedTime = startTime.toLocaleString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      hour12: true
    });
    
    // Create notification content
    const title = 'Upcoming Surgery';
    const body = `Reminder: ${surgeryType} surgery is in ${timeRemaining} (${formattedTime})`;
    
    // Notification data for storing in Firestore
    const notificationData = {
      title,
      body,
      data: {
        type: 'approaching',
        surgeryId,
        timeRemaining,
      },
      read: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Get user IDs involved in the surgery
    const doctorId = surgeryData.doctorId;
    const involvedStaff = [...(surgeryData.nurses || []), ...(surgeryData.technologists || [])];
    
    // Collect all user IDs to notify
    const userIdsToNotify = new Set();
    if (doctorId) userIdsToNotify.add(doctorId);
    involvedStaff.forEach(id => {
      if (id) userIdsToNotify.add(id);
    });
    
    // Send notifications to all users
    for (const userId of userIdsToNotify) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        
        // Store in-app notification
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);
        
        // Send SMS if enabled
        if (userData.enableSmsNotifications && userData.phoneNumber) {
          await sendSMS(userData.phoneNumber, body);
        }
        
        // Send push notification if tokens exist
        if (userData.fcmTokens && userData.fcmTokens.length > 0) {
          for (const token of userData.fcmTokens) {
            try {
              await admin.messaging().send({
                token,
                notification: {
                  title,
                  body,
                },
                data: {
                  surgeryId,
                  type: 'approaching',
                  timeRemaining,
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
              });
            } catch (error) {
              console.error('Error sending push notification:', error);
            }
          }
        }
      }
    }
    
    console.log(`Processed ${timeRemaining} reminder for surgery ${surgeryId}`);
  } catch (error) {
    console.error(`Error processing reminder for surgery ${surgeryId}:`, error);
  }
}

/**
 * HTTP Function to send SMS directly
 * This allows the mobile app to call this function directly
 */
exports.sendSMSDirectly = functions.https.onCall(async (data, context) => {
  try {
    // Check if authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }
    
    // Log credentials for debugging
    console.log('Twilio configuration check:');
    console.log('Account SID exists:', !!process.env.TWILIO_ACCOUNT_SID);
    console.log('Auth Token exists:', !!process.env.TWILIO_AUTH_TOKEN);
    console.log('Phone Number:', process.env.TWILIO_PHONE_NUMBER);
    
    // Verify required data
    if (!data.phoneNumber || !data.message) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Phone number and message are required'
      );
    }
    
    // Format the phone number
    let formattedNumber = data.phoneNumber;
    if (!formattedNumber.startsWith('+')) {
      if (formattedNumber.length === 10) {
        formattedNumber = `+1${formattedNumber}`;  // US number
      } else {
        formattedNumber = `+${formattedNumber}`;
      }
    }
    
    console.log(`Attempting to send SMS to ${formattedNumber}`);
    
    // Send the SMS
    const result = await sendSMS(formattedNumber, data.message);
    
    console.log(`SMS to ${formattedNumber} result: ${result}`);
    
    return { success: result };
  } catch (error) {
    console.error('Error in sendSMSDirectly function:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
}); 