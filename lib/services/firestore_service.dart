import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _usersCollection =>
      _firestore.collection('users');

  /// Save user data to Firestore.
  /// Returns null on success, or an error code/message on failure.
  /// Uses 60s timeout and one retry on timeout/network errors for flaky connections.
  Future<String?> saveUser(UserModel user) async {
    const timeout = Duration(seconds: 60);

    Future<String?> trySave() async {
      try {
        await _usersCollection.doc(user.uid).set(user.toMap()).timeout(timeout);
        return null;
      } on FirebaseException catch (e) {
        debugPrint('Error saving user (code=${e.code}): ${e.message}');
        return e.code;
      } catch (e, stackTrace) {
        debugPrint('Error saving user (raw): $e');
        debugPrint('Stack: $stackTrace');
        final msg = e.toString().toLowerCase();
        if (msg.contains('permission') || msg.contains('denied')) return 'permission-denied';
        if (msg.contains('not found') || msg.contains('not-found') || msg.contains('nonexistent')) return 'not-found';
        if (msg.contains('unavailable') || msg.contains('network') || msg.contains('connection')) return 'unavailable';
        if (msg.contains('certificate') || msg.contains('sha') || msg.contains('app not authorized') || msg.contains('api_key')) return 'app-not-authorized';
        if (msg.contains('timeout') || msg.contains('timed out')) return 'timeout';
        return 'unknown';
      }
    }

    String? result = await trySave();
    if (result != null && (result == 'timeout' || result == 'unavailable')) {
      debugPrint('Retrying saveUser once after $result...');
      await Future<void>.delayed(const Duration(seconds: 2));
      result = await trySave();
    }
    return result;
  }

  /// Get user data from Firestore
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Update user data
  Future<bool> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      await _usersCollection.doc(uid).update(updates);
      return true;
    } catch (e) {
      debugPrint('Error updating user: $e');
      return false;
    }
  }

  /// Check if student ID already exists
  Future<bool> studentIdExists(String studentId) async {
    try {
      final query = await _usersCollection
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking student ID: $e');
      return false;
    }
  }

  /// Check if CNIC already exists
  Future<bool> cnicExists(String cnic) async {
    try {
      final query = await _usersCollection
          .where('cnic', isEqualTo: cnic)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking CNIC: $e');
      return false;
    }
  }
}

