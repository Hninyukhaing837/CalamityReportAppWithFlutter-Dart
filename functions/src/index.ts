import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

// ============================================
// Emergency Report Notification Functions (1st Gen)
// ============================================

export const onEmergencyReportCreated = functions.firestore
  .document('emergency_reports/{reportId}')
  .onCreate(async (snap, context) => {
    try {
      const reportData = snap.data();
      const reportId = context.params.reportId as string;

      console.log('📝 New emergency report created:', reportId);
      console.log('Report data:', reportData);

      // Get report creator ID to exclude them
      const excludeUserId = reportData.userId;

      // 1. Notify all admins
      const adminTokens = await getAdminFCMTokens(reportData, reportId);
      if (adminTokens.length > 0) {
        await sendAdminNotification(adminTokens, reportData, reportId);
        console.log(`✅ Admin notifications sent: ${adminTokens.length}`);
      } else {
        console.log('⚠️ No admin users found with FCM tokens');
      }

      // 2. Notify nearby users (if location available)
      if (reportData.location && reportData.location.geohash) {
        await notifyNearbyUsers(reportData, reportId, excludeUserId);
      } else {
        console.log('⚠️ Report has no location/geohash data');
      }

      return null;
    } catch (error) {
      console.error('❌ Error processing emergency report:', error);
      return null;
    }
  });

// Get admin users' FCM tokens
async function getAdminFCMTokens(reportData: any, reportId: string): Promise<string[]> {
  try {
    const adminsSnapshot = await db
      .collection('users')
      .where('role', '==', 'admin')
      .get();

    console.log(`Found ${adminsSnapshot.size} admin users`);

    const tokens: string[] = [];
    const batch = db.batch();

    // Extract both truncated and full description
    const description = reportData.description || 'No description provided';
    // const truncatedDesc = description.length > 100 
    //   ? description.substring(0, 100) + '...' 
    //   : description;

    for (const doc of adminsSnapshot.docs) {
      const userData = doc.data();
      const fcmToken = userData.fcmToken;

      if (fcmToken) {
        tokens.push(fcmToken);
      }

      const notificationRef = db.collection('notifications').doc();
      batch.set(notificationRef, {
        userId: doc.id,
        type: 'emergency_report',
        title: `🚨 緊急: ${reportData.type}`,
        body: description, 
        // fullDescription: description, 
        reportId: reportId,
        reportType: reportData.type,
        reportUserId: reportData.userId,
        reportUserName: reportData.userName || 'Unknown User',
        reportUserEmail: reportData.userEmail || '',
        priority: reportData.priority || 'high',
        // ✅ Include location data
        latitude: reportData.location?.latitude || null,
        longitude: reportData.location?.longitude || null,
        distance: null, // Not applicable for admin notifications
        read: false,
        pinned: true,
        favorite: false,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    console.log(`✅ Created ${adminsSnapshot.size} admin notification documents`);

    return tokens;
  } catch (error) {
    console.error('❌ Error getting admin tokens:', error);
    return [];
  }
}

// Send notification to admins
async function sendAdminNotification(
  tokens: string[],
  reportData: any,
  reportId: string
) {
  try {
    // ✅ FIXED: Use actual description
    const description = reportData.description || 'No description provided';
    const truncatedDesc = description.length > 100 
      ? description.substring(0, 100) + '...' 
      : description;

    const payload = {
      notification: {
        title: `🚨 緊急: ${reportData.type}`,
        body: truncatedDesc, // ✅ ACTUAL DESCRIPTION!
      },
      data: {
        type: 'emergency_report',
        reportId: reportId,
        reportType: reportData.type || '',
        category: reportData.type || '',
        priority: reportData.priority || 'high',
        reportUserId: reportData.userId || '',
        reportUserName: reportData.userName || '',
        reportUserEmail: reportData.userEmail || '',
        // ✅ Include location as strings (FCM data must be strings)
        latitude: reportData.location?.latitude?.toString() || '',
        longitude: reportData.location?.longitude?.toString() || '',
      },
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokens,
      ...payload,
    });

    console.log(`✅ FCM sent to admins: ${response.successCount}/${tokens.length}`);
    
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`Failed to send to token ${idx}:`, resp.error);
        }
      });
    }
  } catch (error) {
    console.error('❌ Error sending admin notification:', error);
  }
}

// Notify nearby users
async function notifyNearbyUsers(
  reportData: any,
  reportId: string,
  excludeUserId: string
) {
  try {
    const reportGeohash = reportData.location.geohash;
    const reportLat = reportData.location.latitude;
    const reportLon = reportData.location.longitude;

    console.log('📍 Report location:', reportLat, reportLon);
    console.log('📍 Report geohash:', reportGeohash);

    // Get nearby geohash prefixes (5 chars = ~5km)
    const geohashPrefixes = getGeohashNeighbors(reportGeohash.substring(0, 5));
    console.log('🗺️ Searching in geohashes:', geohashPrefixes);

    // Find users in nearby geohashes
    const usersSnapshot = await db
      .collection('users')
      .where('geohash', 'in', geohashPrefixes)
      .get();

    console.log(`Found ${usersSnapshot.size} users in nearby geohashes`);

    const tokens: string[] = [];
    const batch = db.batch();
    let nearbyCount = 0;

    const description = reportData.description || 'No description provided';
    // const truncatedDesc = description.length > 100 
    //   ? description.substring(0, 100) + '...' 
    //   : description;

    for (const doc of usersSnapshot.docs) {
      // Skip report creator
      if (excludeUserId && doc.id === excludeUserId) {
        console.log(`⏭️ Skipping report creator: ${doc.id}`);
        continue;
      }

      const userData = doc.data();

      if (!userData.lastLocation) {
        console.log(`⏭️ User ${doc.id} has no location`);
        continue;
      }

      // Calculate distance
      const distance = calculateDistance(
        reportLat,
        reportLon,
        userData.lastLocation.latitude,
        userData.lastLocation.longitude
      );

      console.log(`👤 User ${doc.id} distance: ${distance.toFixed(2)}km`);

      // Only notify if within 5km
      if (distance <= 5) {
        if (userData.fcmToken) {
          tokens.push(userData.fcmToken);
        }

        // ✅ FIXED: Create notification document with BOTH truncated and full description
        const notificationRef = db.collection('notifications').doc();
        batch.set(notificationRef, {
          userId: doc.id,
          type: 'nearby_report',
          title: `⚠️ 近隣: ${reportData.type}`,
          body: description, // For notification preview in list
          // fullDescription: description, // ✅ FULL description for dialog
          reportId: reportId,
          reportType: reportData.type,
          reportUserId: reportData.userId,
          reportUserName: reportData.userName || 'Unknown User',
          reportUserEmail: reportData.userEmail || '',
          priority: reportData.priority || 'normal',
          distance: distance,
          // ✅ Include sender location coordinates
          latitude: reportLat,
          longitude: reportLon,
          read: false,
          pinned: false,
          favorite: false,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        nearbyCount++;
      }
    }

    if (nearbyCount > 0) {
      await batch.commit();
      console.log(`✅ Created ${nearbyCount} nearby notification documents`);
    }

    // Send FCM
    if (tokens.length > 0) {
      const payload = {
        notification: {
          title: `⚠️ 近隣: ${reportData.type}`,
          body: description, 
        },
        data: {
          type: 'nearby_report',
          reportId: reportId,
          reportType: reportData.type || '',
          category: reportData.type || '',
          priority: reportData.priority || 'normal',
          reportUserId: reportData.userId || '',
          reportUserName: reportData.userName || '',
          reportUserEmail: reportData.userEmail || '',
          // ✅ Include location as strings
          latitude: reportLat.toString(),
          longitude: reportLon.toString(),
        },
      };

      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        ...payload,
      });

      console.log(`✅ FCM sent to nearby users: ${response.successCount}/${tokens.length}`);
      
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${idx}:`, resp.error);
          }
        });
      }
    }
  } catch (error) {
    console.error('❌ Error notifying nearby users:', error);
  }
}

// Calculate distance using Haversine formula
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(degrees: number): number {
  return degrees * (Math.PI / 180);
}

// Get neighboring geohashes
function getGeohashNeighbors(geohash: string): string[] {
  const neighbors = [geohash];
  const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  const lastChar = geohash[geohash.length - 1];
  const prefix = geohash.substring(0, geohash.length - 1);

  const index = base32.indexOf(lastChar);

  if (index > 0) neighbors.push(prefix + base32[index - 1]);
  if (index < base32.length - 1) neighbors.push(prefix + base32[index + 1]);
  if (index > 1) neighbors.push(prefix + base32[index - 2]);
  if (index < base32.length - 2) neighbors.push(prefix + base32[index + 2]);

  return neighbors;
}