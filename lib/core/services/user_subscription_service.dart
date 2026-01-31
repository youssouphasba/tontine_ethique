/// User Subscription Plans Service
/// 
/// 4 FORMULES UTILISATEUR:
/// - Gratuit: 0€/mois, 1 tontine max, 5 participants max
/// - Starter: 3.99€/mois, 2 tontines max, 10 participants max
/// - Standard: 6.99€/mois, 3 tontines max, 15 participants max
/// - Premium: 9.99€/mois, 5 tontines max, 20 participants max
///
/// RÈGLES BACKEND:
/// 1. Vérifier à chaque création: "Utilisateur dépasse-t-il sa limite?"
/// 2. Vérifier: "Nombre de participants autorisé?"
/// 3. Toutes fonctionnalités actives pour tous (vote, aléatoire, messagerie, wallet, IA)
/// 4. Facturation via PSP (Stripe/Wave) - renouvellement mensuel automatique
library;

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ENUMS
// ============================================================

/// Les 4 formules utilisateur
enum UserPlan {
  gratuit,
  starter,
  standard,
  premium,
}

/// Statut de l'abonnement
enum SubscriptionStatus {
  active,
  trial,
  pastDue,
  canceled,
  expired,
}

/// Résultat de vérification de limite
enum LimitCheckResult {
  allowed,
  circleCountExceeded,
  participantCountExceeded,
  upgradeRequired,
}

// ============================================================
// MODÈLES
// ============================================================

/// Définition d'un plan
class PlanDefinition {
  final UserPlan plan;
  final String name;
  final String description;
  final double monthlyPriceEur;
  final int maxCircles;
  final int maxParticipantsPerCircle;
  final List<String> features;
  final String supportLevel;
  final bool hasAlerts;
  final bool hasPriorityAI;

  const PlanDefinition({
    required this.plan,
    required this.name,
    required this.description,
    required this.monthlyPriceEur,
    required this.maxCircles,
    required this.maxParticipantsPerCircle,
    required this.features,
    required this.supportLevel,
    this.hasAlerts = false,
    this.hasPriorityAI = false,
  });

  /// Prix formaté
  String get formattedPrice => 
    monthlyPriceEur == 0 ? 'Gratuit' : '${monthlyPriceEur.toStringAsFixed(2)} €/mois';

  /// Conversion en JSON
  Map<String, dynamic> toJson() => {
    'plan': plan.name,
    'name': name,
    'description': description,
    'monthlyPriceEur': monthlyPriceEur,
    'maxCircles': maxCircles,
    'maxParticipantsPerCircle': maxParticipantsPerCircle,
    'features': features,
    'supportLevel': supportLevel,
    'hasAlerts': hasAlerts,
    'hasPriorityAI': hasPriorityAI,
  };
}

/// Abonnement d'un utilisateur
class UserSubscription {
  final String id;
  final String userId;
  final UserPlan plan;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final String? pspSubscriptionId;
  final String psp; // stripe, wave
  final int currentCircleCount;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.startDate,
    this.endDate,
    this.nextBillingDate,
    this.pspSubscriptionId,
    required this.psp,
    required this.currentCircleCount,
  });

  /// Vérifie si l'abonnement est actif
  bool get isActive => 
    status == SubscriptionStatus.active || status == SubscriptionStatus.trial;

  /// Conversion en JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'plan': plan.name,
    'status': status.name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'nextBillingDate': nextBillingDate?.toIso8601String(),
    'pspSubscriptionId': pspSubscriptionId,
    'psp': psp,
    'currentCircleCount': currentCircleCount,
  };
}

/// Résultat de vérification de limite
class LimitValidation {
  final LimitCheckResult result;
  final bool allowed;
  final String message;
  final int? currentCount;
  final int? maxAllowed;
  final UserPlan? suggestedUpgrade;

  const LimitValidation({
    required this.result,
    required this.allowed,
    required this.message,
    this.currentCount,
    this.maxAllowed,
    this.suggestedUpgrade,
  });
}

/// Usage actuel de l'utilisateur
class UserUsage {
  final String userId;
  final int circlesCreated;
  final int circlesJoined;
  final int totalCircles;
  final int circlesRemaining;
  final int maxCircles;
  final int maxParticipantsPerCircle;
  final double usagePercentage;

  const UserUsage({
    required this.userId,
    required this.circlesCreated,
    required this.circlesJoined,
    required this.totalCircles,
    required this.circlesRemaining,
    required this.maxCircles,
    required this.maxParticipantsPerCircle,
    required this.usagePercentage,
  });
}

// ============================================================
// DÉFINITIONS DES PLANS (FALLBACK UNIQUEMENT)
// ============================================================
// ⚠️ ATTENTION: Ces définitions sont des FALLBACKS LOCAUX uniquement.
// Les vraies données (prix, limites) viennent de Firestore collection 'plans'.
// Ces valeurs ne sont utilisées que si Firestore n'est pas disponible.
// Pour modifier les plans, utilisez le Back-Office Admin ou Firestore directement.

class PlanDefinitions {
  /// Fonctionnalités communes à tous les plans
  static const List<String> commonFeatures = [
    'Vote pour l\'ordre des pots',
    'Attribution aléatoire',
    'Messagerie intégrée',
    'Wallet sécurisé',
    'Suivi du score de fiabilité',
    'IA Tontii (conseils)',
  ];

  /// Plan Gratuit
  static const PlanDefinition gratuit = PlanDefinition(
    plan: UserPlan.gratuit,
    name: 'Gratuit',
    description: 'Parfait pour découvrir la plateforme',
    monthlyPriceEur: 0.00,
    maxCircles: 1,
    maxParticipantsPerCircle: 5,
    features: commonFeatures,
    supportLevel: 'Support limité',
    hasAlerts: false,
    hasPriorityAI: false,
  );

  /// Plan Starter
  static const PlanDefinition starter = PlanDefinition(
    plan: UserPlan.starter,
    name: 'Starter',
    description: 'Idéal pour commencer sérieusement',
    monthlyPriceEur: 3.99,
    maxCircles: 2,
    maxParticipantsPerCircle: 10,
    features: commonFeatures,
    supportLevel: 'Support prioritaire par chat',
    hasAlerts: false,
    hasPriorityAI: false,
  );

  /// Plan Standard
  static const PlanDefinition standard = PlanDefinition(
    plan: UserPlan.standard,
    name: 'Standard',
    description: 'Pour les utilisateurs actifs',
    monthlyPriceEur: 6.99,
    maxCircles: 3,
    maxParticipantsPerCircle: 15,
    features: commonFeatures,
    supportLevel: 'Support prioritaire',
    hasAlerts: false,
    hasPriorityAI: false,
  );

  /// Plan Premium
  static const PlanDefinition premium = PlanDefinition(
    plan: UserPlan.premium,
    name: 'Premium',
    description: 'L\'expérience complète sans limites',
    monthlyPriceEur: 9.99,
    maxCircles: 5,
    maxParticipantsPerCircle: 20,
    features: [
      ...commonFeatures,
      'Alertes personnalisées',
      'Priorisation IA Tontii',
    ],
    supportLevel: 'Support premium dédié',
    hasAlerts: true,
    hasPriorityAI: true,
  );

  /// Récupère la définition d'un plan
  static PlanDefinition getDefinition(UserPlan plan) {
    switch (plan) {
      case UserPlan.gratuit:
        return gratuit;
      case UserPlan.starter:
        return starter;
      case UserPlan.standard:
        return standard;
      case UserPlan.premium:
        return premium;
    }
  }

  /// Liste de tous les plans
  static List<PlanDefinition> get all => [gratuit, starter, standard, premium];

  /// Plan suivant (pour upgrade)
  static UserPlan? getNextPlan(UserPlan current) {
    switch (current) {
      case UserPlan.gratuit:
        return UserPlan.starter;
      case UserPlan.starter:
        return UserPlan.standard;
      case UserPlan.standard:
        return UserPlan.premium;
      case UserPlan.premium:
        return null; // Déjà au max
    }
  }
}

// ============================================================
// SERVICE PRINCIPAL
// ============================================================

class UserSubscriptionService {
  static final UserSubscriptionService _instance = UserSubscriptionService._internal();
  factory UserSubscriptionService() => _instance;
  UserSubscriptionService._internal() {
    _initializeService();
  }

  /// Stockage des définitions locales (fallback)
  final Map<UserPlan, PlanDefinition> _localPlans = {
    UserPlan.gratuit: PlanDefinitions.gratuit,
    UserPlan.starter: PlanDefinitions.starter,
    UserPlan.standard: PlanDefinitions.standard,
    UserPlan.premium: PlanDefinitions.premium,
  };

  /// Stockage des définitions distantes (Firestore)
  final Map<UserPlan, PlanDefinition> _remotePlans = {};

  /// Stockage des abonnements (en mémoire pour la démo)
  final Map<String, UserSubscription> _subscriptions = {};

  /// Stockage du nombre de cercles par utilisateur
  final Map<String, int> _userCircleCounts = {};

  Future<void> _initializeService() async {
    // 1. Initialiser avec les données locales par défaut
    debugPrint('[Subscription] Service initialized with local defaults');
    
    // 2. Tenter de récupérer les configs à jour depuis Firestore
    try {
      await _fetchPlansFromFirestore();
    } catch (e) {
      debugPrint('[Subscription] Failed to fetch remote plans: $e');
    }
  }

  /// Récupère les définitions à jour depuis Firestore
  Future<void> _fetchPlansFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('plans').get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('[Subscription] No remote plans found in Firestore.');
        return;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final planCode = _parsePlanCode(data['code'] ?? doc.id); // 'gratuit', 'starter'...
        
        if (planCode != null) {
          final limits = data['limits'] as Map<String, dynamic>? ?? {};
          
          final def = PlanDefinition(
            plan: planCode,
            name: data['name'] ?? _localPlans[planCode]?.name ?? 'Plan',
            description: data['description'] ?? _localPlans[planCode]?.description ?? '',
            monthlyPriceEur: (data['priceCents'] ?? 0) / 100.0,
            maxCircles: limits['maxActiveCircles'] ?? _localPlans[planCode]?.maxCircles ?? 1,
            maxParticipantsPerCircle: limits['maxMembers'] ?? _localPlans[planCode]?.maxParticipantsPerCircle ?? 5,
            features: List<String>.from(data['features'] ?? _localPlans[planCode]?.features ?? []),
            supportLevel: data['supportLevel'] ?? _localPlans[planCode]?.supportLevel ?? 'Standard',
            hasAlerts: data['hasAlerts'] ?? _localPlans[planCode]?.hasAlerts ?? false,
            hasPriorityAI: data['hasPriorityAI'] ?? _localPlans[planCode]?.hasPriorityAI ?? false,
          );
          
          _remotePlans[planCode] = def;
          debugPrint('[Subscription] Loaded remote config for ${planCode.name}: ${def.maxCircles} circles, ${def.maxParticipantsPerCircle} members');
        }
      }
    } catch (e) {
      debugPrint('[Subscription] Error parsing remote plans: $e');
    }
  }

  UserPlan? _parsePlanCode(String code) {
    try {
      return UserPlan.values.firstWhere(
        (e) => e.name.toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _initializeDemoData() {
    // Deprecated - kept for reference
  }

  // ============================================================
  // MÉTHODES DE VÉRIFICATION (CÔTÉ SERVEUR)
  // ============================================================

  /// Récupère l'abonnement d'un utilisateur
  UserSubscription? getSubscription(String userId) => _subscriptions[userId];

  /// Récupère le plan d'un utilisateur (gratuit par défaut)
  UserPlan getUserPlan(String userId) {
    return _subscriptions[userId]?.plan ?? UserPlan.gratuit;
  }

  /// Récupère la définition du plan de l'utilisateur (Remote > Local)
  PlanDefinition getUserPlanDefinition(String userId) {
    final userPlan = getUserPlan(userId);
    // Priorité à la config Firestore, sinon fallback hardcodé
    return _remotePlans[userPlan] ?? _localPlans[userPlan] ?? PlanDefinitions.getDefinition(userPlan);
  }

  /// ⚠️ VÉRIFICATION SERVEUR: L'utilisateur peut-il créer une nouvelle tontine?
  LimitValidation canCreateCircle(String userId) {
    final plan = getUserPlanDefinition(userId);
    final currentCount = _userCircleCounts[userId] ?? 0;

    if (currentCount >= plan.maxCircles) {
      final nextPlan = PlanDefinitions.getNextPlan(plan.plan);
      return LimitValidation(
        result: LimitCheckResult.circleCountExceeded,
        allowed: false,
        message: 'Vous avez atteint la limite de ${plan.maxCircles} tontine(s) pour votre plan ${plan.name}.',
        currentCount: currentCount,
        maxAllowed: plan.maxCircles,
        suggestedUpgrade: nextPlan,
      );
    }

    return LimitValidation(
      result: LimitCheckResult.allowed,
      allowed: true,
      message: 'Création autorisée. Tontines: $currentCount/${plan.maxCircles}',
      currentCount: currentCount,
      maxAllowed: plan.maxCircles,
    );
  }

  /// ⚠️ VÉRIFICATION SERVEUR: Le nombre de participants est-il autorisé?
  LimitValidation canAddParticipants(String userId, int requestedParticipants) {
    final plan = getUserPlanDefinition(userId);

    if (requestedParticipants > plan.maxParticipantsPerCircle) {
      final nextPlan = PlanDefinitions.getNextPlan(plan.plan);
      return LimitValidation(
        result: LimitCheckResult.participantCountExceeded,
        allowed: false,
        message: 'Maximum ${plan.maxParticipantsPerCircle} participants pour le plan ${plan.name}.',
        currentCount: requestedParticipants,
        maxAllowed: plan.maxParticipantsPerCircle,
        suggestedUpgrade: nextPlan,
      );
    }

    return LimitValidation(
      result: LimitCheckResult.allowed,
      allowed: true,
      message: 'Nombre de participants autorisé: $requestedParticipants/${plan.maxParticipantsPerCircle}',
      currentCount: requestedParticipants,
      maxAllowed: plan.maxParticipantsPerCircle,
    );
  }

  /// ⚠️ VÉRIFICATION COMPLÈTE avant création de cercle
  LimitValidation validateCircleCreation({
    required String userId,
    required int plannedParticipants,
  }) {
    // 1. Vérifier limite de tontines
    final circleCheck = canCreateCircle(userId);
    if (!circleCheck.allowed) {
      return circleCheck;
    }

    // 2. Vérifier limite de participants
    final participantCheck = canAddParticipants(userId, plannedParticipants);
    if (!participantCheck.allowed) {
      return participantCheck;
    }

    return LimitValidation(
      result: LimitCheckResult.allowed,
      allowed: true,
      message: 'Création autorisée',
      currentCount: _userCircleCounts[userId] ?? 0,
      maxAllowed: getUserPlanDefinition(userId).maxCircles,
    );
  }

  /// Récupère l'usage actuel de l'utilisateur
  UserUsage getUserUsage(String userId) {
    final plan = getUserPlanDefinition(userId);
    final circleCount = _userCircleCounts[userId] ?? 0;
    final remaining = plan.maxCircles - circleCount;
    final percentage = (circleCount / plan.maxCircles) * 100;

    return UserUsage(
      userId: userId,
      circlesCreated: circleCount,
      circlesJoined: 0, // À implémenter avec vraie base de données
      totalCircles: circleCount,
      circlesRemaining: remaining,
      maxCircles: plan.maxCircles,
      maxParticipantsPerCircle: plan.maxParticipantsPerCircle,
      usagePercentage: percentage,
    );
  }

  // ============================================================
  // GESTION DES ABONNEMENTS
  // ============================================================

  /// Crée un nouvel abonnement (via PSP)
  Future<UserSubscription> createSubscription({
    required String userId,
    required UserPlan plan,
    required String psp,
    required String pspSubscriptionId,
  }) async {
    final subscription = UserSubscription(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      plan: plan,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      nextBillingDate: DateTime.now().add(const Duration(days: 30)),
      pspSubscriptionId: pspSubscriptionId,
      psp: psp,
      currentCircleCount: _userCircleCounts[userId] ?? 0,
    );

    _subscriptions[userId] = subscription;
    debugPrint('[Subscription] Abonnement créé: ${subscription.id} - Plan: ${plan.name}');
    return subscription;
  }

  /// Met à jour le plan (upgrade/downgrade)
  Future<UserSubscription?> upgradePlan({
    required String userId,
    required UserPlan newPlan,
  }) async {
    final current = _subscriptions[userId];
    if (current == null) {
      debugPrint('[Subscription] Erreur: Aucun abonnement pour $userId');
      return null;
    }

    final updated = UserSubscription(
      id: current.id,
      userId: userId,
      plan: newPlan,
      status: SubscriptionStatus.active,
      startDate: current.startDate,
      nextBillingDate: DateTime.now().add(const Duration(days: 30)),
      pspSubscriptionId: current.pspSubscriptionId,
      psp: current.psp,
      currentCircleCount: current.currentCircleCount,
    );

    _subscriptions[userId] = updated;
    debugPrint('[Subscription] Plan mis à jour: ${current.plan.name} → ${newPlan.name}');
    return updated;
  }

  /// Annule un abonnement
  Future<bool> cancelSubscription(String userId) async {
    final current = _subscriptions[userId];
    if (current == null) return false;

    final canceled = UserSubscription(
      id: current.id,
      userId: userId,
      plan: current.plan,
      status: SubscriptionStatus.canceled,
      startDate: current.startDate,
      endDate: current.nextBillingDate, // Fin à la prochaine facturation
      pspSubscriptionId: current.pspSubscriptionId,
      psp: current.psp,
      currentCircleCount: current.currentCircleCount,
    );

    _subscriptions[userId] = canceled;
    debugPrint('[Subscription] Abonnement annulé: ${current.id}');
    return true;
  }

  /// Incrémente le compteur de cercles après création réussie
  void incrementCircleCount(String userId) {
    _userCircleCounts[userId] = (_userCircleCounts[userId] ?? 0) + 1;
    debugPrint('[Subscription] Cercles pour $userId: ${_userCircleCounts[userId]}');
  }

  /// Décrémente le compteur de cercles après fermeture
  void decrementCircleCount(String userId) {
    final current = _userCircleCounts[userId] ?? 1;
    _userCircleCounts[userId] = (current - 1).clamp(0, 999);
    debugPrint('[Subscription] Cercles pour $userId: ${_userCircleCounts[userId]}');
  }

  // ============================================================
  // STATISTIQUES ADMIN
  // ============================================================

  /// Statistiques des abonnements
  Map<String, dynamic> getSubscriptionStats() {
    final plans = {
      UserPlan.gratuit: 0,
      UserPlan.starter: 0,
      UserPlan.standard: 0,
      UserPlan.premium: 0,
    };

    double totalMRR = 0.0;

    for (final sub in _subscriptions.values) {
      if (sub.isActive) {
        plans[sub.plan] = (plans[sub.plan] ?? 0) + 1;
        totalMRR += PlanDefinitions.getDefinition(sub.plan).monthlyPriceEur;
      }
    }

    return {
      'total_subscribers': _subscriptions.length,
      'active_subscribers': _subscriptions.values.where((s) => s.isActive).length,
      'by_plan': {
        'gratuit': plans[UserPlan.gratuit],
        'starter': plans[UserPlan.starter],
        'standard': plans[UserPlan.standard],
        'premium': plans[UserPlan.premium],
      },
      'mrr_eur': totalMRR,
      'avg_plan_value': _subscriptions.isEmpty ? 0 : totalMRR / _subscriptions.values.where((s) => s.isActive).length,
    };
  }

  /// Export pour audit
  List<Map<String, dynamic>> exportSubscriptionsForAudit() {
    return _subscriptions.values.map((s) => s.toJson()).toList();
  }
}
