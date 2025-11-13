const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {
  sendWelcomeEmail,
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendPasswordResetConfirmation
} = require('./firebase-emailService');

// Initialize Firebase Admin
admin.initializeApp();

// Get Firestore reference
const db = admin.firestore();

// ============================================
// CLOUD FUNCTION: User Signup with Email
// ============================================
exports.signupWithEmail = functions.https.onCall(async (data, context) => {
  const { email, password, displayName } = data;

  // Validate input
  if (!email || !password || !displayName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email, password, and display name are required'
    );
  }

  try {
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
      emailVerified: false
    });

    // Generate email verification link
    const verificationLink = await admin.auth().generateEmailVerificationLink(email);

    // Send verification email using our custom template
    try {
      await sendVerificationEmail(email, displayName, verificationLink);
    } catch (emailError) {
      console.error('Failed to send verification email:', emailError);
      // Continue even if email fails - user is still created
    }

    // Create user document in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      email: email,
      displayName: displayName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      emailVerified: false
    });

    return {
      success: true,
      message: 'Account created! Please check your email to verify your account.',
      uid: userRecord.uid
    };

  } catch (error) {
    console.error('Signup error:', error);
    
    // Handle specific Firebase Auth errors
    if (error.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError(
        'already-exists',
        'An account with this email already exists'
      );
    }
    
    if (error.code === 'auth/invalid-email') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email address'
      );
    }
    
    if (error.code === 'auth/weak-password') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Password should be at least 6 characters'
      );
    }

    throw new functions.https.HttpsError('internal', 'Signup failed', error.message);
  }
});

// ============================================
// CLOUD FUNCTION: Send Welcome Email After Verification
// ============================================
exports.onEmailVerified = functions.auth.user().onCreate(async (user) => {
  // This triggers when a user is created
  // You can also use a Firestore trigger when emailVerified changes to true
  
  if (user.emailVerified) {
    try {
      await sendWelcomeEmail(user.email, user.displayName || 'User');
      console.log(`Welcome email sent to ${user.email}`);
    } catch (error) {
      console.error('Error sending welcome email:', error);
    }
  }
});

// ============================================
// CLOUD FUNCTION: Password Reset Request
// ============================================
exports.requestPasswordReset = functions.https.onCall(async (data, context) => {
  const { email } = data;

  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email is required'
    );
  }

  try {
    // Check if user exists
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (error) {
      // For security, don't reveal if email exists
      return {
        success: true,
        message: 'If that email exists, a reset link has been sent'
      };
    }

    // Generate password reset link
    const resetLink = await admin.auth().generatePasswordResetLink(email);

    // Send password reset email using custom template
    await sendPasswordResetEmail(
      email,
      userRecord.displayName || 'User',
      resetLink
    );

    return {
      success: true,
      message: 'Password reset link sent to your email'
    };

  } catch (error) {
    console.error('Password reset request error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to process password reset request',
      error.message
    );
  }
});

// ============================================
// CLOUD FUNCTION: Resend Verification Email
// ============================================
exports.resendVerificationEmail = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;

  try {
    // Get user record
    const userRecord = await admin.auth().getUser(uid);

    if (userRecord.emailVerified) {
      return {
        success: false,
        message: 'Email is already verified'
      };
    }

    // Generate new verification link
    const verificationLink = await admin.auth().generateEmailVerificationLink(userRecord.email);

    // Send verification email
    await sendVerificationEmail(
      userRecord.email,
      userRecord.displayName || 'User',
      verificationLink
    );

    return {
      success: true,
      message: 'Verification email sent'
    };

  } catch (error) {
    console.error('Resend verification error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to resend verification email',
      error.message
    );
  }
});

// ============================================
// FIRESTORE TRIGGER: Send Welcome Email on Email Verification
// ============================================
exports.onUserEmailVerified = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if emailVerified changed from false to true
    if (!before.emailVerified && after.emailVerified) {
      try {
        await sendWelcomeEmail(after.email, after.displayName || 'User');
        console.log(`Welcome email sent to ${after.email}`);
      } catch (error) {
        console.error('Error sending welcome email:', error);
      }
    }
  });

// ============================================
// CLOUD FUNCTION: Update Email Verified Status
// ============================================
exports.updateEmailVerificationStatus = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const uid = context.auth.uid;

  try {
    // Get latest user data from Firebase Auth
    const userRecord = await admin.auth().getUser(uid);

    // Update Firestore document
    await db.collection('users').doc(uid).update({
      emailVerified: userRecord.emailVerified,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      emailVerified: userRecord.emailVerified
    };

  } catch (error) {
    console.error('Update verification status error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update verification status',
      error.message
    );
  }
});

// ============================================
// HTTP FUNCTION: Test Email Configuration
// ============================================
exports.testEmail = functions.https.onRequest(async (req, res) => {
  // Only allow in development/testing
  if (process.env.NODE_ENV === 'production') {
    res.status(403).send('Not allowed in production');
    return;
  }

  try {
    const { verifyTransporter } = require('./firebase-emailService');
    const isReady = await verifyTransporter();
    
    if (isReady) {
      res.status(200).json({
        success: true,
        message: 'Email configuration is valid'
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Email configuration failed'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Email test failed',
      error: error.message
    });
  }
});