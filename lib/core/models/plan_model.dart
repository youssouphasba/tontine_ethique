import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanType { user, enterprise, merchant }
enum PlanStatus { active, draft, archived }

class Plan {
  final String id;
  final String code; // e.g., USER_STARTER
  final PlanType type;
  final String name;
  final String? emoji;
  final String? description;
  final String? stripePriceId;
  final bool isRecommended;
  final PlanStatus status;
  final bool isActive;
  final int sortOrder;
  final String countryScope; // e.g. "ALL"
  final Map<String, double> prices; // e.g., {"EUR": 4.99, "XOF": 3250}
  final Map<String, dynamic> limits; // e.g., {"maxCircles": 5, "maxMembers": 20}
  final List<String> features;
  final String? supportLevel;
  final String billingPeriod; // e.g., month, year, once, none

  Plan({
    required this.id,
    required this.code,
    required this.type,
    required this.name,
    this.emoji,
    this.description,
    this.stripePriceId,
    this.isRecommended = false,
    this.status = PlanStatus.active,
    this.isActive = true,
    this.sortOrder = 0,
    this.countryScope = 'ALL',
    required this.prices,
    required this.limits,
    this.features = const [],
    this.supportLevel,
    this.billingPeriod = 'month',
  });

  factory Plan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Plan(
      id: doc.id,
      code: data['code'] ?? doc.id.toUpperCase(),
      type: PlanType.values.firstWhere((e) => e.name == data['type'], orElse: () => PlanType.user),
      name: data['name'] ?? '',
      emoji: data['emoji'],
      description: data['description'],
      stripePriceId: data['stripePriceId'],
      isRecommended: data['isRecommended'] ?? false,
      status: PlanStatus.values.firstWhere((e) => e.name == data['status'], orElse: () => PlanStatus.active),
      isActive: data['isActive'] ?? data['is_active'] ?? true,
      sortOrder: data['sortOrder'] ?? data['sort_order'] ?? 0,
      countryScope: data['countryScope'] ?? data['country_scope'] ?? 'ALL',
      prices: (data['prices'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      limits: Map<String, dynamic>.from(data['limits'] ?? {}),
      features: List<String>.from(data['features'] ?? []),
      supportLevel: data['supportLevel'],
      billingPeriod: data['billingPeriod'] ?? data['billing_period'] ?? 'month',
    );
  }

  factory Plan.free() {
    return Plan(
      id: 'plan_gratuit',
      code: 'plan_gratuit',
      type: PlanType.user,
      name: 'Gratuit',
      prices: {'EUR': 0.0, 'XOF': 0.0},
      limits: {'maxCircles': 1, 'maxMembers': 5},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'type': type.name,
      'name': name,
      'emoji': emoji,
      'description': description,
      'stripePriceId': stripePriceId,
      'isRecommended': isRecommended,
      'status': status.name,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'countryScope': countryScope,
      'prices': prices,
      'limits': limits,
      'features': features,
      'supportLevel': supportLevel,
      'billingPeriod': billingPeriod,
    };
  }

  double getPrice(String currency) => prices[currency] ?? 0.0;
  
  T getLimit<T>(String key, T defaultValue) {
    final value = limits[key];
    if (value == null) return defaultValue;
    
    // Safely handle int to double conversion
    if (T == double && value is int) {
      return value.toDouble() as T;
    }
    
    // Safely handle double to int conversion
    if (T == int && value is double) {
      return value.toInt() as T;
    }

    try {
      return (value as T?) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }
}
