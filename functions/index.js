const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Firebase Cloud Functions for Image Upload Notifications
 * 
 * 画像アップロード時の通知機能実装
 * Firebase Storage と連携して、画像アップロード完了時に自動通知を送信
 */

// Initialize Firebase Admin
admin.initializeApp();

/**
 * 画像アップロード完了時のトリガー
 * Storage にファイルがアップロードされたときに実行
 */
exports.onImageUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name; // 例: "disaster_reports/report123/image1.jpg"
  const contentType = object.contentType;
  const bucket = object.bucket;

  // 画像ファイルのみ処理
  if (!contentType || !contentType.startsWith('image/')) {
    console.log('Not an image file, skipping notification');
    return null;
  }

  console.log(`🖼️ New image uploaded: ${filePath}`);

  try {
    // 画像の公開 URL を生成
    const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(filePath)}?alt=media`;

    // ファイルパスから disaster report ID を抽出
    const pathParts = filePath.split('/');
    let reportId = null;
    let reportType = 'general';

    if (pathParts[0] === 'disaster_reports' && pathParts.length > 1) {
      reportId = pathParts[1];
      reportType = 'disaster_report';
    } else if (pathParts[0] === 'chat_media' && pathParts.length > 1) {
      reportId = pathParts[1];
      reportType = 'chat_message';
    }

    // Firestore からレポート情報を取得
    let notificationData = {
      imageUrl: imageUrl,
      type: reportType,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (reportId) {
      const reportDoc = await admin.firestore()
        .collection('disaster_reports')
        .doc(reportId)
        .get();

      if (reportDoc.exists) {
        const reportData = reportDoc.data();
        notificationData = {
          ...notificationData,
          reportId: reportId,
          title: reportData.title || '新しい画像が追加されました',
          location: reportData.location,
          priority: reportData.priority,
          userId: reportData.userId,
        };
      }
    }

    // サムネイル URL を生成（オプション）
    const thumbnailUrl = imageUrl + '&width=200'; // パラメータで縮小画像を要求

    // 通知を送信
    await sendImageUploadNotification(notificationData, imageUrl, thumbnailUrl);

    console.log('✅ Image upload notification sent successfully');
    return null;

  } catch (error) {
    console.error('❌ Error sending image upload notification:', error);
    return null;
  }
});

/**
 * 画像アップロード通知を送信
 * @param {Object} data - レポートデータ
 * @param {string} imageUrl - 画像の URL
 * @param {string} thumbnailUrl - サムネイル URL
 */
async function sendImageUploadNotification(data, imageUrl, thumbnailUrl) {
  const { reportId, title, location, priority, userId, type } = data;

  // 通知タイトルとボディを作成
  const notificationTitle = title || '新しい画像が追加されました';
  const notificationBody = location 
    ? `場所: ${location.address || '位置情報あり'}`
    : '災害レポートに画像が追加されました';

  // 緊急度に応じた設定
  const isEmergency = priority === 'high' || priority === 'critical';
  
  // 全ユーザーのトークンを取得（または特定のユーザー/トピック）
  const tokensSnapshot = await admin.firestore()
    .collection('user_tokens')
    .get();

  if (tokensSnapshot.empty) {
    console.log('No user tokens found');
    return;
  }

  const tokens = [];
  tokensSnapshot.forEach(doc => {
    const tokenData = doc.data();
    // レポート作成者以外に通知（オプション）
    if (tokenData.fcmToken && tokenData.userId !== userId) {
      tokens.push(tokenData.fcmToken);
    }
  });

  if (tokens.length === 0) {
    console.log('No valid tokens to send notification');
    return;
  }

  // FCM メッセージペイロード（リッチ通知対応）
  const message = {
    tokens: tokens,
    notification: {
      title: notificationTitle,
      body: notificationBody,
    },
    data: {
      type: type || 'media',
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      reportId: reportId || '',
      screen: 'report',
      priority: priority || 'normal',
      clickAction: reportId ? `calamity://report/${reportId}` : 'calamity://notifications',
    },
    // Android 固有の設定
    android: {
      priority: isEmergency ? 'high' : 'normal',
      notification: {
        imageUrl: imageUrl, // 🖼️ リッチ通知: 画像を表示
        channelId: isEmergency ? 'emergency_alerts' : 'media_updates',
        color: isEmergency ? '#FF0000' : '#4CAF50',
        icon: 'notification_icon',
        sound: isEmergency ? 'emergency_alert' : 'default',
        priority: isEmergency ? 'high' : 'default',
        vibrationPattern: isEmergency ? [0, 500, 250, 500] : [0, 250, 250, 250],
      },
    },
    // iOS 固有の設定
    apns: {
      payload: {
        aps: {
          alert: {
            title: notificationTitle,
            body: notificationBody,
          },
          sound: isEmergency ? 'emergency_alert.wav' : 'default',
          badge: 1,
          'mutable-content': 1, // 画像表示のために必要
        },
      },
      fcm_options: {
        image: imageUrl, // 🖼️ リッチ通知: iOS でも画像を表示
      },
    },
    // Web プッシュ通知設定
    webpush: {
      notification: {
        title: notificationTitle,
        body: notificationBody,
        icon: '/notification-icon.png',
        image: imageUrl, // 🖼️ リッチ通知: Web でも画像を表示
        badge: '/badge-icon.png',
        requireInteraction: isEmergency,
      },
      fcm_options: {
        link: reportId ? `/report/${reportId}` : '/notifications',
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Successfully sent ${response.successCount} notifications`);
    console.log(`❌ Failed to send ${response.failureCount} notifications`);

    // 失敗したトークンを削除（無効なトークン対策）
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          failedTokens.push(tokens[idx]);
          console.error(`Failed token: ${tokens[idx]}, Error: ${resp.error}`);
        }
      });

      // 無効なトークンを削除
      await removeInvalidTokens(failedTokens);
    }

  } catch (error) {
    console.error('❌ Error sending multicast message:', error);
  }
}

/**
 * 無効なトークンを Firestore から削除
 * @param {Array} tokens - 削除するトークンのリスト
 */
async function removeInvalidTokens(tokens) {
  const batch = admin.firestore().batch();
  
  for (const token of tokens) {
    const tokenQuery = await admin.firestore()
      .collection('user_tokens')
      .where('fcmToken', '==', token)
      .get();

    tokenQuery.forEach(doc => {
      batch.delete(doc.ref);
    });
  }

  await batch.commit();
  console.log(`🗑️ Removed ${tokens.length} invalid tokens`);
}

/**
 * 手動で画像アップロード通知を送信する HTTP 関数
 * POST /sendImageNotification
 * Body: { reportId, imageUrl, userId }
 */
exports.sendImageNotification = functions.https.onCall(async (data, context) => {
  // 認証チェック
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { reportId, imageUrl } = data;

  if (!reportId || !imageUrl) {
    throw new functions.https.HttpsError('invalid-argument', 'reportId and imageUrl are required');
  }

  try {
    // レポート情報を取得
    const reportDoc = await admin.firestore()
      .collection('disaster_reports')
      .doc(reportId)
      .get();

    if (!reportDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Report not found');
    }

    const reportData = reportDoc.data();
    const thumbnailUrl = imageUrl + '&width=200';

    await sendImageUploadNotification({
      reportId: reportId,
      title: reportData.title,
      location: reportData.location,
      priority: reportData.priority,
      userId: reportData.userId,
      type: 'media',
    }, imageUrl, thumbnailUrl);

    return { success: true, message: 'Notification sent successfully' };

  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * 画像削除時の処理
 * Storage からファイルが削除されたときに実行
 */
exports.onImageDelete = functions.storage.object().onDelete(async (object) => {
  const filePath = object.name;
  console.log(`🗑️ Image deleted: ${filePath}`);

  // 必要に応じて通知やクリーンアップ処理を実装
  return null;
});
// const {
//   sendWelcomeEmail,
//   sendVerificationEmail,
//   sendPasswordResetEmail,
//   sendPasswordResetConfirmation
// } = require('./firebase-emailService');

// // Initialize Firebase Admin
// admin.initializeApp();

// // Get Firestore reference
// const db = admin.firestore();

// // ============================================
// // CLOUD FUNCTION: User Signup with Email
// // ============================================
// exports.signupWithEmail = functions.https.onCall(async (data, context) => {
//   const { email, password, displayName } = data;

//   // Validate input
//   if (!email || !password || !displayName) {
//     throw new functions.https.HttpsError(
//       'invalid-argument',
//       'Email, password, and display name are required'
//     );
//   }

//   try {
//     // Create user in Firebase Auth
//     const userRecord = await admin.auth().createUser({
//       email: email,
//       password: password,
//       displayName: displayName,
//       emailVerified: false
//     });

//     // Generate email verification link
//     const verificationLink = await admin.auth().generateEmailVerificationLink(email);

//     // Send verification email using our custom template
//     try {
//       await sendVerificationEmail(email, displayName, verificationLink);
//     } catch (emailError) {
//       console.error('Failed to send verification email:', emailError);
//       // Continue even if email fails - user is still created
//     }

//     // Create user document in Firestore
//     await db.collection('users').doc(userRecord.uid).set({
//       email: email,
//       displayName: displayName,
//       createdAt: admin.firestore.FieldValue.serverTimestamp(),
//       emailVerified: false
//     });

//     return {
//       success: true,
//       message: 'Account created! Please check your email to verify your account.',
//       uid: userRecord.uid
//     };

//   } catch (error) {
//     console.error('Signup error:', error);
    
//     // Handle specific Firebase Auth errors
//     if (error.code === 'auth/email-already-exists') {
//       throw new functions.https.HttpsError(
//         'already-exists',
//         'An account with this email already exists'
//       );
//     }
    
//     if (error.code === 'auth/invalid-email') {
//       throw new functions.https.HttpsError(
//         'invalid-argument',
//         'Invalid email address'
//       );
//     }
    
//     if (error.code === 'auth/weak-password') {
//       throw new functions.https.HttpsError(
//         'invalid-argument',
//         'Password should be at least 6 characters'
//       );
//     }

//     throw new functions.https.HttpsError('internal', 'Signup failed', error.message);
//   }
// });

// // ============================================
// // CLOUD FUNCTION: Send Welcome Email After Verification
// // ============================================
// exports.onEmailVerified = functions.auth.user().onCreate(async (user) => {
//   // This triggers when a user is created
//   // You can also use a Firestore trigger when emailVerified changes to true
  
//   if (user.emailVerified) {
//     try {
//       await sendWelcomeEmail(user.email, user.displayName || 'User');
//       console.log(`Welcome email sent to ${user.email}`);
//     } catch (error) {
//       console.error('Error sending welcome email:', error);
//     }
//   }
// });

// // ============================================
// // CLOUD FUNCTION: Password Reset Request
// // ============================================
// exports.requestPasswordReset = functions.https.onCall(async (data, context) => {
//   const { email } = data;

//   if (!email) {
//     throw new functions.https.HttpsError(
//       'invalid-argument',
//       'Email is required'
//     );
//   }

//   try {
//     // Check if user exists
//     let userRecord;
//     try {
//       userRecord = await admin.auth().getUserByEmail(email);
//     } catch (error) {
//       // For security, don't reveal if email exists
//       return {
//         success: true,
//         message: 'If that email exists, a reset link has been sent'
//       };
//     }

//     // Generate password reset link
//     const resetLink = await admin.auth().generatePasswordResetLink(email);

//     // Send password reset email using custom template
//     await sendPasswordResetEmail(
//       email,
//       userRecord.displayName || 'User',
//       resetLink
//     );

//     return {
//       success: true,
//       message: 'Password reset link sent to your email'
//     };

//   } catch (error) {
//     console.error('Password reset request error:', error);
//     throw new functions.https.HttpsError(
//       'internal',
//       'Failed to process password reset request',
//       error.message
//     );
//   }
// });

// // ============================================
// // CLOUD FUNCTION: Resend Verification Email
// // ============================================
// exports.resendVerificationEmail = functions.https.onCall(async (data, context) => {
//   // Check if user is authenticated
//   if (!context.auth) {
//     throw new functions.https.HttpsError(
//       'unauthenticated',
//       'User must be authenticated'
//     );
//   }

//   const uid = context.auth.uid;

//   try {
//     // Get user record
//     const userRecord = await admin.auth().getUser(uid);

//     if (userRecord.emailVerified) {
//       return {
//         success: false,
//         message: 'Email is already verified'
//       };
//     }

//     // Generate new verification link
//     const verificationLink = await admin.auth().generateEmailVerificationLink(userRecord.email);

//     // Send verification email
//     await sendVerificationEmail(
//       userRecord.email,
//       userRecord.displayName || 'User',
//       verificationLink
//     );

//     return {
//       success: true,
//       message: 'Verification email sent'
//     };

//   } catch (error) {
//     console.error('Resend verification error:', error);
//     throw new functions.https.HttpsError(
//       'internal',
//       'Failed to resend verification email',
//       error.message
//     );
//   }
// });

// // ============================================
// // FIRESTORE TRIGGER: Send Welcome Email on Email Verification
// // ============================================
// exports.onUserEmailVerified = functions.firestore
//   .document('users/{userId}')
//   .onUpdate(async (change, context) => {
//     const before = change.before.data();
//     const after = change.after.data();

//     // Check if emailVerified changed from false to true
//     if (!before.emailVerified && after.emailVerified) {
//       try {
//         await sendWelcomeEmail(after.email, after.displayName || 'User');
//         console.log(`Welcome email sent to ${after.email}`);
//       } catch (error) {
//         console.error('Error sending welcome email:', error);
//       }
//     }
//   });

// // ============================================
// // CLOUD FUNCTION: Update Email Verified Status
// // ============================================
// exports.updateEmailVerificationStatus = functions.https.onCall(async (data, context) => {
//   // Check if user is authenticated
//   if (!context.auth) {
//     throw new functions.https.HttpsError(
//       'unauthenticated',
//       'User must be authenticated'
//     );
//   }

//   const uid = context.auth.uid;

//   try {
//     // Get latest user data from Firebase Auth
//     const userRecord = await admin.auth().getUser(uid);

//     // Update Firestore document
//     await db.collection('users').doc(uid).update({
//       emailVerified: userRecord.emailVerified,
//       updatedAt: admin.firestore.FieldValue.serverTimestamp()
//     });

//     return {
//       success: true,
//       emailVerified: userRecord.emailVerified
//     };

//   } catch (error) {
//     console.error('Update verification status error:', error);
//     throw new functions.https.HttpsError(
//       'internal',
//       'Failed to update verification status',
//       error.message
//     );
//   }
// });

// // ============================================
// // HTTP FUNCTION: Test Email Configuration
// // ============================================
// exports.testEmail = functions.https.onRequest(async (req, res) => {
//   // Only allow in development/testing
//   if (process.env.NODE_ENV === 'production') {
//     res.status(403).send('Not allowed in production');
//     return;
//   }

//   try {
//     const { verifyTransporter } = require('./firebase-emailService');
//     const isReady = await verifyTransporter();
    
//     if (isReady) {
//       res.status(200).json({
//         success: true,
//         message: 'Email configuration is valid'
//       });
//     } else {
//       res.status(500).json({
//         success: false,
//         message: 'Email configuration failed'
//       });
//     }
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: 'Email test failed',
//       error: error.message
//     });
//   }
// });