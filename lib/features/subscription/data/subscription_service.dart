import 'package:tontetic/core/models/user_model.dart';

enum TierStatus { allowed, requiresPremium, requiresAdmin, blocked }

class SubscriptionService {
  // Paliers Zone FCFA
  static const List<int> freeTiersFCFA = [10000, 20000, 30000];
  static const List<int> premiumTiersFCFA = [50000, 100000, 200000, 300000, 500000];
  static const int adminLimitFCFA = 500000;

  // Paliers Zone Euro
  static const List<int> freeTiersEuro = [30, 50, 70];
  static const List<int> premiumTiersEuro = [100, 200, 300, 400, 500];
  static const int adminLimitEuro = 500;

  static TierStatus checkLimit(double amount, UserState user) {
    if (user.zone == UserZone.zoneFCFA) {
      if (amount > adminLimitFCFA) return TierStatus.requiresAdmin;
      if (freeTiersFCFA.contains(amount.toInt())) return TierStatus.allowed;
      if (premiumTiersFCFA.contains(amount.toInt())) {
        return user.isPremium ? TierStatus.allowed : TierStatus.requiresPremium;
      }
      return TierStatus.blocked; // Montant non standard
    } else {
      if (amount > adminLimitEuro) return TierStatus.requiresAdmin;
      if (freeTiersEuro.contains(amount.toInt())) return TierStatus.allowed;
      if (premiumTiersEuro.contains(amount.toInt())) {
        return user.isPremium ? TierStatus.allowed : TierStatus.requiresPremium;
      }
      return TierStatus.blocked; // Montant non standard
    }
  }

  static String getCurrencySymbol(UserZone zone) {
    return zone == UserZone.zoneFCFA ? 'FCFA' : '€';
  }
}
