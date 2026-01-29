class ReferralService {
  // Simule l'appel à la table app_config de Supabase
  static Future<bool> isReferralActive() async {

    // RETOURNE TRUE POUR LES TESTS (Mettre à false pour tester la disparition)
    return true; 
  }

  static String generateReferralCode() {
    return 'TON-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }
}
