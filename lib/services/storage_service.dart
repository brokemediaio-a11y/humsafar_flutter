import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Uploads user document images to Firebase Storage and returns download URLs.
/// Use this instead of storing base64 in Firestore (1 MB document limit).
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a base64 image to Storage under users/{uid}/{fieldName}.jpg
  /// Returns the download URL or null on failure.
  Future<String?> uploadUserDocumentImage({
    required String uid,
    required String fieldName,
    required String base64Data,
  }) async {
    try {
      final bytes = base64Decode(base64Data);
      final ref = _storage.ref().child('users').child(uid).child('$fieldName.jpg');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage upload error ($fieldName): $e');
      return null;
    }
  }
}
