import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'companion_service.dart';

class AuthService {
  // Lazy access to FirebaseAuth only when Firebase is initialized
  bool get _isReady => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth {
    if (!_isReady) {
      throw FirebaseAuthException(
        code: 'no-app',
        message: 'Firebase is not configured',
      );
    }
    return FirebaseAuth.instance;
  }

  bool get isSignedIn {
    try {
      return _isReady && _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  User? get currentUser {
    try {
      return _isReady ? _auth.currentUser : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    if (!_isReady) return;
    try {
      await CompanionService().syncDeviceState({'online': false});
      await _auth.signOut();
    } catch (_) {}
  }

  // Phone auth
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String message) onError,
    Function(UserCredential)? onVerified,
    int? forceResendingToken,
  }) async {
    if (!_isReady) {
      onError(
        'Firebase is not configured. Add GoogleService-Info.plist (iOS) and call Firebase.initializeApp().',
      );
      return;
    }
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final cred = await _auth.signInWithCredential(credential);
            await CompanionService().syncCurrentUserProfile();
            if (onVerified != null) onVerified(cred);
          } catch (e) {
            onError('Auto verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // No-op: user can still enter the code manually.
        },
      );
    } catch (e) {
      onError('Failed to start verification: $e');
    }
  }

  Future<UserCredential> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!_isReady) {
      throw FirebaseAuthException(
        code: 'no-app',
        message: 'Firebase is not configured',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    await CompanionService().syncCurrentUserProfile();
    return result;
  }

  // Email/password auth
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!_isReady) {
      throw FirebaseAuthException(
        code: 'no-app',
        message: 'Firebase is not configured',
      );
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(displayName.trim());
    }
    await CompanionService().syncCurrentUserProfile();
    return cred;
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_isReady) {
      throw FirebaseAuthException(
        code: 'no-app',
        message: 'Firebase is not configured',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Save email for offline access if login successful
      if (credential.user?.email != null) {
        await _saveEmail(credential.user!.email!);
        await handleOfflineAuth(credential.user!.email!);
      }

      await CompanionService().syncCurrentUserProfile();

      return credential;
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'network-request-failed') {
        // Check if we have a previously logged in user with this email
        final savedEmail = await _getSavedEmail();
        if (savedEmail != null && savedEmail == email.trim()) {
          // Handle offline authentication
          final success = await handleOfflineAuth(email);
          if (success) {
            // Return null to indicate offline authentication
            return null;
          }
        }
      }
      // Re-throw the original error if we can't handle it
      rethrow;
    }
  }

  // Handle offline authentication
  Future<bool> handleOfflineAuth(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_offline_authenticated', true);
      await prefs.setString('offline_user_email', email);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Check if user is authenticated in offline mode
  Future<bool> isOfflineAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_offline_authenticated') ?? false;
    } catch (_) {
      return false;
    }
  }

  // Get saved email from local storage
  Future<String?> _getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_email');
    } catch (_) {
      return null;
    }
  }

  // Save email to local storage
  Future<void> _saveEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
    } catch (_) {
      // Ignore storage errors
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    // Ensure Firebase is ready; attempt init on Android if not yet initialized.
    if (!_isReady) {
      try {
        await Firebase.initializeApp();
      } catch (_) {
        throw FirebaseAuthException(
          code: 'no-app',
          message:
              'Firebase/Google is not configured. Add GoogleService-Info.plist and URL types in Info.plist.',
        );
      }
    }

    try {
      // Use modern provider-based sign-in to avoid google_sign_in constructor issues.
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      final credential = await _auth.signInWithProvider(googleProvider);

      // Save email for offline access if login successful
      if (credential.user?.email != null) {
        await _saveEmail(credential.user!.email!);
        await handleOfflineAuth(credential.user!.email!);
      }

      await CompanionService().syncCurrentUserProfile();

      return credential;
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'network-request-failed') {
        // Check if we have a previously logged in Google user
        final savedEmail = await _getSavedEmail();
        if (savedEmail != null && savedEmail.isNotEmpty) {
          final success = await handleOfflineAuth(savedEmail);
          if (success) {
            // Return null to indicate offline authentication
            return null;
          }
        }
      }
      rethrow;
    }
  }
}
