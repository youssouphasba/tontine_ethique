/// Subscription Service
/// 
/// Handles logic for plan-based restrictions and formatting.
/// All data (prices, limits, features) is fetched dynamically from 
/// the 'plans' collection in Firestore.
/// 
/// V17: Zero Hardcoding - The 'Plan' model is the source of truth.
library;



import 'package:tontetic/core/models/plan_model.dart';
import 'package:tontetic/core/providers/user_provider.dart';

class SubscriptionService {
  
  // --- Dynamic Configuration Methods (V15/V16 Architecture) ---

  /// ⚠️ VÉRIFICATION SERVEUR: L'utilisateur peut-il créer une nouvelle tontine? (Dynamic)
  static String? getCreationErrorMessage({
    required Plan? plan, 
    required int activeCirclesCount,
  }) {
    if (plan == null) return null; // Fallback or Guest
    
    final maxCircles = plan.getLimit<int>('maxCircles', 1);
    if (activeCirclesCount >= maxCircles) {
      return "Vous avez atteint le nombre maximum de tontines actives pour votre plan ($maxCircles). Passez à un plan supérieur pour en créer davantage.";
    }
    return null;
  }

  /// ⚠️ VÉRIFICATION SERVEUR: Le nombre de participants est-il autorisé? (Dynamic)
  static String? getParticipantsErrorMessage({
    required Plan? plan,
    required int requestedParticipants,
  }) {
    if (plan == null) return null; // Fallback or Guest
    
    final maxMembers = plan.getLimit<int>('maxMembers', 5);
    if (requestedParticipants > maxMembers) {
      return "Le nombre de participants ($requestedParticipants) dépasse la limite de votre plan ($maxMembers max).";
    }
    return null;
  }

  /// Get remaining circles available (Dynamic)
  static int getRemainingCircles(Plan plan, int activeCirclesCount) {
    final maxCircles = plan.getLimit<int>('maxCircles', 1);
    return (maxCircles - activeCirclesCount).clamp(0, maxCircles);
  }

  /// Format plan price from a dynamic Plan model
  static String formatPlanPrice(Plan plan, UserZone zone) {
    final currency = zone == UserZone.zoneEuro ? 'EUR' : 'XOF';
    final price = plan.getPrice(currency);
    
    if (price == 0) return 'Gratuit';
    
    final symbol = zone == UserZone.zoneEuro ? '€' : 'FCFA';
    final formatted = zone == UserZone.zoneEuro 
      ? price.toStringAsFixed(2) 
      : price.toStringAsFixed(0);
    return '$formatted $symbol/mois';
  }

  /// ⚠️ VÉRIFICATION SERVEUR: Le marchand peut-il ajouter un produit? (V16)
  static String? getMerchantProductsErrorMessage({
    required Plan? plan,
    required int activeProductsCount,
  }) {
    if (plan == null || plan.type != PlanType.merchant) return null;
    
    final maxProducts = plan.getLimit<int>('maxProducts', 10);
    if (activeProductsCount >= maxProducts) {
      return "Vous avez atteint le nombre maximum de produits autorisés pour votre forfait ($maxProducts).";
    }
    return null;
  }

  /// ⚠️ VÉRIFICATION SERVEUR: L'entreprise peut-elle ajouter un collaborateur? (V16)
  static String? getEnterpriseEmployeesErrorMessage({
    required Plan? plan,
    required int activeEmployeesCount,
  }) {
    if (plan == null || plan.type != PlanType.enterprise) return null;
    
    final maxEmployees = plan.getLimit<int>('maxEmployees', 5);
    if (activeEmployeesCount >= maxEmployees) {
      return "Limite de collaborateurs atteinte pour votre compte entreprise ($maxEmployees).";
    }
    return null;
  }

  /// Format price with currency (Utility helper)
  static String formatPrice(double amount, {String currency = '€'}) {
    if (currency == '€' || currency == 'EUR') {
      return '${amount.toStringAsFixed(2)} €';
    } else {
      return '${amount.toInt()} F';
    }
  }

  // Placeholder to fix build error
  static String? getMaxContributionErrorMessage({required double monthlyAmount, required UserZone zone}) {
    return null; 
  }
}
