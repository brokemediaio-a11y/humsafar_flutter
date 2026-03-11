import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

class AuthService {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  FirebaseAuth? get _auth {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return FirebaseAuth.instance;
    } catch (e) {
      return null;
    }
  }

  // Get current user
  User? get currentUser {
    final auth = _auth;
    if (auth == null) return null;
    return auth.currentUser;
  }

  // Auth state stream
  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) return Stream.value(null);
    return auth.authStateChanges();
  }

  /// Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required UserModel userData,
  }) async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult.error('Firebase is not initialized. Please configure Firebase for web.');
    }
    
    try {
      // Create Firebase Auth user
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        userData = userData.copyWith(
          uid: userCredential.user!.uid,
        );

        // Duplicate check after auth so Firestore rules allow read (authenticated)
        final studentIdExists = await _firestoreService.studentIdExists(userData.studentId);
        if (studentIdExists) {
          try {
            await userCredential.user?.delete();
          } catch (e) {
            debugPrint('Error deleting auth user: $e');
          }
          return const AuthResult.error('Student ID already exists.');
        }
        final cnicExists = await _firestoreService.cnicExists(userData.cnic);
        if (cnicExists) {
          try {
            await userCredential.user?.delete();
          } catch (e) {
            debugPrint('Error deleting auth user: $e');
          }
          return const AuthResult.error('CNIC already exists.');
        }

        final uid = userCredential.user!.uid;
        // Upload document images to Storage (Firestore doc limit is 1 MB; base64 images exceed it)
        String? studentCardFrontUrl = userData.studentCardFront != null
            ? await _storageService.uploadUserDocumentImage(uid: uid, fieldName: 'studentCardFront', base64Data: userData.studentCardFront!)
            : null;
        String? studentCardBackUrl = userData.studentCardBack != null
            ? await _storageService.uploadUserDocumentImage(uid: uid, fieldName: 'studentCardBack', base64Data: userData.studentCardBack!)
            : null;
        String? cnicFrontUrl = userData.cnicFront != null
            ? await _storageService.uploadUserDocumentImage(uid: uid, fieldName: 'cnicFront', base64Data: userData.cnicFront!)
            : null;
        String? cnicBackUrl = userData.cnicBack != null
            ? await _storageService.uploadUserDocumentImage(uid: uid, fieldName: 'cnicBack', base64Data: userData.cnicBack!)
            : null;
        String? licenseFrontUrl = userData.licenseFront != null
            ? await _storageService.uploadUserDocumentImage(uid: uid, fieldName: 'licenseFront', base64Data: userData.licenseFront!)
            : null;
        String? licenseBackUrl = userData.licenseBack != null
            ? await _storageService.uploadUserDocumentImage(uid: uid, fieldName: 'licenseBack', base64Data: userData.licenseBack!)
            : null;

        userData = userData.copyWith(
          studentCardFront: studentCardFrontUrl,
          studentCardBack: studentCardBackUrl,
          cnicFront: cnicFrontUrl,
          cnicBack: cnicBackUrl,
          licenseFront: licenseFrontUrl,
          licenseBack: licenseBackUrl,
        );

        // Save user data to Firestore (URLs only; no base64)
        final saveError = await _firestoreService.saveUser(userData);
        if (saveError == null) {
          return AuthResult.success(userCredential.user!);
        }
        // If Firestore save fails, delete the auth user to keep data consistent
        try {
          await userCredential.user?.delete();
        } catch (e) {
          debugPrint('Error deleting auth user: $e');
        }
        final String message;
        switch (saveError) {
          case 'permission-denied':
            message = 'Firestore denied the write. In Firebase Console → Firestore → Rules, '
                'use test mode or add rules that allow writes to the users collection.';
            break;
          case 'not-found':
          case 'not-found-database':
            message = 'Firestore database may not exist. In Firebase Console → Firestore, '
                'create a database (choose a region) and start in test mode if needed.';
            break;
          case 'unavailable':
            message = 'Cannot reach Firestore. Check your internet connection and try again.';
            break;
          case 'timeout':
            message = 'Request timed out. Try again. If it keeps failing: use mobile data instead of '
                'Wi‑Fi (some networks block Firebase), or add your app\'s SHA-1 in Firebase Console '
                '→ Project settings → Android → Add fingerprint, then replace google-services.json and rebuild.';
            break;
          case 'app-not-authorized':
            message = 'This device/build is not recognized by Firebase. Add your app\'s SHA-1 in '
                'Firebase Console → Project settings → Your apps → Android → Add fingerprint, '
                'then download the new google-services.json and rebuild.';
            break;
          case 'invalid-argument':
            message = 'Document too large. Document images are now uploaded to Storage; try signup again.';
            break;
          case 'unknown':
          default:
            message = 'Failed to save user data. On a physical device this is often due to SHA-1: '
                'Firebase Console → Project settings → Android app → Add fingerprint (SHA-1), '
                'then replace android/app/google-services.json and rebuild.';
        }
        return AuthResult.error(message);
      }
      return const AuthResult.error('Failed to create user');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      // Provide more detailed error message
      final errorMsg = e.toString();
      if (errorMsg.contains('CONFIGURATION_NOT_FOUND') || 
          errorMsg.contains('reCAPTCHA')) {
        return const AuthResult.error(
          'Firebase Auth reCAPTCHA is not configured. Please enable it in Firebase Console.',
        );
      }
      if (errorMsg.contains('PERMISSION_DENIED') || 
          errorMsg.contains('Firestore API')) {
        return const AuthResult.error(
          'Firestore API is not enabled. Please enable it in Firebase Console.',
        );
      }
      return AuthResult.error('An error occurred: ${e.toString()}');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult.error('Firebase is not initialized. Please configure Firebase for web.');
    }
    
    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Check if user is verified
      if (userCredential.user != null) {
        final userData = await _firestoreService.getUser(userCredential.user!.uid);
        if (userData != null && !userData.isVerified) {
          // Sign out the user if not verified
          await auth.signOut();
          return const AuthResult.error('User not verified. Please wait for verification.');
        }
      }
      
      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.error('An unexpected error occurred');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    final auth = _auth;
    if (auth != null) {
      await auth.signOut();
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      default:
        return 'An error occurred: $code';
    }
  }
}

/// Result class for authentication operations
class AuthResult {
  final User? user;
  final String? error;

  AuthResult.success(this.user) : error = null;
  const AuthResult.error(this.error) : user = null;

  bool get isSuccess => user != null;
}

