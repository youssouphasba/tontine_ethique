import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/models/plan_model.dart';

/// Subscription Provider
/// Manages enterprise subscription plans with limits
/// 
/// Features:
/// - Plan limits (max employees, max tontines)
/// - Subscription status (active, expired, trial)
/// - Billing via PSP (Stripe/Wave)
/// - Permission-based access control

/// Subscription Plan Category (UI Only)
enum SubscriptionPlan {
  starter,
  starterPro,
  team,
  teamPro,
  department,
  enterprise,
  unlimited;

  String get id {
    switch (this) {
      case SubscriptionPlan.starter: return 'plan_corporate_starter';
      case SubscriptionPlan.starterPro: return 'plan_corporate_starter_pro';
      case SubscriptionPlan.team: return 'plan_corporate_team';
      case SubscriptionPlan.teamPro: return 'plan_corporate_team_pro';
      case SubscriptionPlan.department: return 'plan_corporate_dept';
      case SubscriptionPlan.enterprise: return 'plan_corporate_enterprise';
      case SubscriptionPlan.unlimited: return 'plan_corporate_unlimited';
    }
  }
}

/// Dynamic plan limits helper (Loaded from Firestore)
class PlanLimits {
  final int maxEmployees;
  final int maxTontines;
  final double priceEuro;
  final List<String> features;
  final bool flexibleLimits;

  const PlanLimits({
    required this.maxEmployees,
    required this.maxTontines,
    required this.priceEuro,
    required this.features,
    this.flexibleLimits = true,
  });

  /// Note about flexibility
  static const String flexibilityNote = 
    'Nombre de salariés impair ou supérieur au plan ? Contactez notre support '
    'pour un ajustement personnalisé. Nos équipes peuvent modifier vos limites '
    'selon vos besoins spécifiques.';

  /// Note: Global contribution limits (maxContributionParticulier, maxContributionEntreprise)
  /// should now be fetched from SubscriptionService or a ConfigProvider.
}


enum SubscriptionStatus {
  active,
  trial,
  expired,
  cancelled,
}

class CompanySubscription {
  final String companyId;
  final Plan plan; // Use the dynamic Plan model
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? pspSubscriptionId;

  // Current usage
  final int currentEmployees;
  final int currentTontines;

  CompanySubscription({
    required this.companyId,
    required this.plan,
    required this.status,
    required this.startDate,
    this.endDate,
    this.pspSubscriptionId,
    this.currentEmployees = 0,
    required this.currentTontines,
  });

  // Dynamic limits from the Plan model
  int get maxEmployees => plan.getLimit<int>('maxEmployees', 0);
  int get maxTontines => plan.getLimit<int>('maxCircles', 0);
  
  bool get isActive => status == SubscriptionStatus.active || status == SubscriptionStatus.trial;
  
  bool get canAddEmployee => currentEmployees < maxEmployees;
  int get remainingEmployeeSlots => maxEmployees - currentEmployees;
  
  bool get canCreateTontine => currentTontines < maxTontines;
  int get remainingTontineSlots => maxTontines - currentTontines;

  double get employeeUsagePercent => maxEmployees > 0 ? (currentEmployees / maxEmployees).clamp(0.0, 1.0) : 1.0;
  double get tontineUsagePercent => maxTontines > 0 ? (currentTontines / maxTontines).clamp(0.0, 1.0) : 1.0;

  CompanySubscription copyWith({
    Plan? plan,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? pspSubscriptionId,
    int? currentEmployees,
    int? currentTontines,
  }) {
    return CompanySubscription(
      companyId: companyId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pspSubscriptionId: pspSubscriptionId ?? this.pspSubscriptionId,
      currentEmployees: currentEmployees ?? this.currentEmployees,
      currentTontines: currentTontines ?? this.currentTontines,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<CompanySubscription?> {
  SubscriptionNotifier() : super(null);

  /// Initialize subscription for a company with a dynamic Plan
  void initSubscription({
    required String companyId,
    required Plan plan,
    String? pspSubscriptionId,
  }) {
    state = CompanySubscription(
      companyId: companyId,
      plan: plan,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      pspSubscriptionId: pspSubscriptionId,
      currentTontines: 0,
    );
    debugPrint('[Subscription] Initialized: ${plan.name} for $companyId');
  }

  /// Try to add an employee - returns true if allowed
  bool tryAddEmployee() {
    if (state == null || !state!.canAddEmployee) {
      debugPrint('[Subscription] Cannot add employee: limit reached (${state?.currentEmployees}/${state?.maxEmployees})');
      return false;
    }
    state = state!.copyWith(currentEmployees: state!.currentEmployees + 1);
    debugPrint('[Subscription] Employee added: ${state!.currentEmployees}/${state!.maxEmployees}');
    return true;
  }

  /// Remove an employee from count
  void removeEmployee() {
    if (state == null || state!.currentEmployees <= 0) return;
    state = state!.copyWith(currentEmployees: state!.currentEmployees - 1);
    debugPrint('[Subscription] Employee removed: ${state!.currentEmployees}/${state!.maxEmployees}');
  }

  /// Try to create a tontine - returns true if allowed
  bool tryCreateTontine() {
    if (state == null || !state!.canCreateTontine) {
      debugPrint('[Subscription] Cannot create tontine: limit reached (${state?.currentTontines}/${state?.maxTontines})');
      return false;
    }
    state = state!.copyWith(currentTontines: state!.currentTontines + 1);
    debugPrint('[Subscription] Tontine created: ${state!.currentTontines}/${state!.maxTontines}');
    return true;
  }

  /// Close a tontine - decrement count
  void closeTontine() {
    if (state == null || state!.currentTontines <= 0) return;
    state = state!.copyWith(currentTontines: state!.currentTontines - 1);
    debugPrint('[Subscription] Tontine closed: ${state!.currentTontines}/${state!.maxTontines}');
  }

  /// Upgrade plan
  void upgradePlan(Plan newPlan) {
    if (state == null) return;
    state = state!.copyWith(plan: newPlan);
    debugPrint('[Subscription] Upgraded to: ${newPlan.name}');
  }

  /// Check if user can perform action based on plan
  bool canPerformAction(String action) {
    if (state == null || !state!.isActive) return false;
    
    switch (action) {
      case 'export_pdf':
      case 'export_csv':
        return state!.plan.getLimit<bool>('canExport', false);
      case 'advanced_reporting':
        return state!.plan.type == PlanType.enterprise;
      case 'team_scores':
        return state!.plan.type == PlanType.enterprise;
      default:
        return true;
    }
  }

  /// Get upgrade suggestions
  List<SubscriptionPlan> getUpgradeSuggestions() {
    if (state == null) return [];
    return SubscriptionPlan.values
        .where((p) => p.index > state!.plan.sortOrder)
        .take(2)
        .toList();
  }
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, CompanySubscription?>((ref) {
  return SubscriptionNotifier();
});

/// Derived providers for easy access
final canAddEmployeeProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return sub?.canAddEmployee ?? false;
});

final canCreateTontineProvider = Provider<bool>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return sub?.canCreateTontine ?? false;
});

final subscriptionUsageProvider = Provider<({double employees, double tontines})>((ref) {
  final sub = ref.watch(subscriptionProvider);
  return (
    employees: sub?.employeeUsagePercent ?? 0,
    tontines: sub?.tontineUsagePercent ?? 0,
  );
});
