import 'package:tontetic/core/models/user_model.dart';

/// V17: SEPA PURE - Aucun transit par Tontetic
/// 
/// ARCHITECTURE:
/// - Cotisations: Prélèvement SEPA direct compte membre → compte bénéficiaire
/// - Garantie: AUTORISATION conditionnelle (jamais prélevée à l'avance)
/// - Tontetic = prestataire technique uniquement
/// - Pas de wallet = pas de licence ACPR/EME/EMI

class TontineContributionInfo {
  final double contributionAmount;    // Cotisation mensuelle
  final double guaranteeAuthorized;   // Garantie AUTORISÉE (pas prélevée)
  final String currency;

  TontineContributionInfo({
    required this.contributionAmount,
    required this.guaranteeAuthorized,
    required this.currency,
  });
}

class TontineTierService {
  // REMOVED V17 but restored for compatibility
  static bool requiresAdminApproval(double amount, UserZone zone) {
    return false;
  }

  // V17: Calcul des contributions SEPA Pure
  static TontineContributionInfo calculateContribution({
    required double amount,
    required UserZone zone,
  }) {
    // SEPA Pure: pas de frais, pas de wallet
    // Garantie = 1 cotisation (AUTORISATION seulement)
    double guaranteeAuthorized = amount;

    return TontineContributionInfo(
      contributionAmount: amount,
      guaranteeAuthorized: guaranteeAuthorized,
      currency: zone.currency,
    );
  }

  /// Texte explicatif pour l'utilisateur (pas de prélèvement wallet)
  static String formatContributionRecap(TontineContributionInfo info) {
    return '''
📋 RÉCAPITULATIF DE VOS ENGAGEMENTS

💰 COTISATION MENSUELLE
   Montant : ${info.contributionAmount} ${info.currency}
   Prélèvement : SEPA direct de votre compte bancaire
   Destination : Directement au bénéficiaire du tour

🛡️ GARANTIE CONDITIONNELLE
   Montant autorisé : ${info.guaranteeAuthorized} ${info.currency}
   
   ⚠️ IMPORTANT :
   → Cette garantie n'est PAS prélevée
   → C'est une AUTORISATION de prélèvement
   → Déclenchée UNIQUEMENT en cas de défaut de votre part
   
   CONDITIONS DE DÉCLENCHEMENT :
   • Prélèvement SEPA rejeté (fonds insuffisants)
   • Après 3 tentatives de prélèvement échouées
   • Après expiration du délai de grâce (7 jours)

────────────────────────────────────────

📌 CE QUE VOUS VOYEZ :
   Prélèvement mensuel : ${info.contributionAmount} ${info.currency}
   (Aucun prélèvement de garantie visible)

💡 FONCTIONNEMENT :
   L'argent va directement de votre compte bancaire
   au compte du bénéficiaire du tour.
   Tontetic ne touche jamais les fonds.
''';
  }

  /// Clause légale pour les CGU
  static String getLegalGuaranteeClause() {
    return '''
La garantie constitue une autorisation de prélèvement conditionnelle.
Aucun montant n'est prélevé tant qu'un défaut objectif n'est pas constaté
par le prestataire de paiement.

Le défaut est caractérisé de manière objective et automatique par :
- Le rejet du prélèvement SEPA pour insuffisance de provision
- L'échec de 3 tentatives successives de prélèvement
- Le dépassement du délai de grâce de 7 jours

Le déclenchement de la garantie est automatique et ne fait l'objet
d'aucune décision discrétionnaire.
''';
  }
}



