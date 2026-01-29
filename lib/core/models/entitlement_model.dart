import 'package:cloud_firestore/cloud_firestore.dart';

class Entitlement {
  final String userId;
  final String currentPlanCode;
  final String planSource; // stripe, admin, trial
  final String status; // active, past_due, canceled, trialing, free
  final DateTime? currentPeriodEnd;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime updatedAt;

  Entitlement({
    required this.userId,
    required this.currentPlanCode,
    required this.planSource,
    required this.status,
    this.currentPeriodEnd,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    required this.updatedAt,
  });

  factory Entitlement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Entitlement(
      userId: doc.id,
      currentPlanCode: data['current_plan_code'] ?? 'USER_FREE',
      planSource: data['plan_source'] ?? 'system',
      status: data['status'] ?? 'free',
      currentPeriodEnd: data['current_period_end'] != null 
          ? (data['current_period_end'] as Timestamp).toDate() 
          : null,
      stripeCustomerId: data['stripe_customer_id'],
      stripeSubscriptionId: data['stripe_subscription_id'],
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'current_plan_code': currentPlanCode,
      'plan_source': planSource,
      'status': status,
      'current_period_end': currentPeriodEnd != null ? Timestamp.fromDate(currentPeriodEnd!) : null,
      'stripe_customer_id': stripeCustomerId,
      'stripe_subscription_id': stripeSubscriptionId,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  bool get isActive => ['active', 'trialing', 'free'].contains(status);
}
