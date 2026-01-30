import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralService {
  /// Checks if referral campaign is active via Firestore app_config
  static Future<bool> isReferralActive() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('features')
          .get();
      
      if (doc.exists && doc.data() != null) {
        return doc.data()!['referralEnabled'] == true;
      }
      return false; // Default to disabled if config not found
    } catch (e) {
      return false; // Fail-safe: disable referral if error
    }
  }

  static String generateReferralCode() {
    return 'TON-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }
}

