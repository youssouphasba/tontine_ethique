class StripeConstants {
  // Corporate Plan Price IDs
  static const String starter = 'price_1Suh0wCpguZvNb1U31MBhu7P';
  static const String starterPro = 'price_1Suh1rCpguZvNb1UL4HZHv2v';
  static const String team = 'price_1Suh3WCpguZvNb1UqkodV50W';
  static const String teamPro = 'price_1Suh6tCpguZvNb1Ufn4GQOZd';
  static const String department = 'price_1Suh9NCpguZvNb1UrPDgTxqe';
  static const String enterprise = 'price_1SuhCzCpguZvNb1UrmPmAZVb';

  // Map internal plan codes to Stripe Price IDs
  static const Map<String, String> corporatePlanToPriceId = {
    'starter': starter,
    'starter_pro': starterPro,
    'team': team,
    'team_pro': teamPro,
    'department': department,
    'enterprise': enterprise,
  };

  static String? getPriceIdForPlan(String planCode) {
    return corporatePlanToPriceId[planCode];
  }
}
