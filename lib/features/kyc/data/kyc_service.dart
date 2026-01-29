import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// KYC Service - PRODUCTION VERSION
/// Uploads identity documents to Firebase Storage and updates Firestore status
class KycService {
  /// Upload identity document to Firebase Storage for KYC verification
  /// Returns true if upload successful, false otherwise
  static Future<bool> uploadIdentityDocument(XFile image) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('[KYC] Error: User not authenticated');
        return false;
      }

      // Read image bytes
      final bytes = await image.readAsBytes();
      final fileName = 'kyc_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('kyc_documents')
          .child(uid)
          .child(fileName);

      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update Firestore with KYC status
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'kycStatus': 'pending',
        'kycDocumentUrl': downloadUrl,
        'kycSubmittedAt': FieldValue.serverTimestamp(),
        'kycFileName': fileName,
      }, SetOptions(merge: true));

      // Create KYC request for admin review
      await FirebaseFirestore.instance.collection('kyc_requests').add({
        'userId': uid,
        'documentUrl': downloadUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[KYC] Document uploaded successfully: $downloadUrl');
      return true;
    } catch (e) {
      debugPrint('[KYC] Upload error: $e');
      return false;
    }
  }

  /// Get current KYC status for user
  static Future<String?> getKycStatus(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return doc.data()?['kycStatus'] as String?;
    } catch (e) {
      debugPrint('[KYC] Error getting status: $e');
      return null;
    }
  }

  /// Upload Liveness Check photos (Neutral + Smile)
  /// Returns true if successful
  static Future<bool> uploadLivenessPhotos({
    required XFile neutralPhoto,
    required XFile smilePhoto,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 1. Upload Neutral Photo
      final neutralRef = FirebaseStorage.instance
          .ref()
          .child('liveness_checks')
          .child(uid)
          .child('neutral_$timestamp.jpg');
      await neutralRef.putData(
        await neutralPhoto.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final neutralUrl = await neutralRef.getDownloadURL();

      // 2. Upload Smile Photo
      final smileRef = FirebaseStorage.instance
          .ref()
          .child('liveness_checks')
          .child(uid)
          .child('smile_$timestamp.jpg');
      await smileRef.putData(
        await smilePhoto.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final smileUrl = await smileRef.getDownloadURL();

      // 3. Create Liveness Document in Firestore
      await FirebaseFirestore.instance.collection('liveness_checks').add({
        'userId': uid,
        'neutralPhotoUrl': neutralUrl,
        'smilePhotoUrl': smileUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Validation manual or AI service webhook
      });
      
      // 4. Update User Profile
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'livenessStatus': 'pending',
      }, SetOptions(merge: true));

      debugPrint('[LIVENESS] Photos uploaded successfully.');
      return true;
    } catch (e) {
      debugPrint('[LIVENESS] Upload error: $e');
      return false;
    }
  }
}
