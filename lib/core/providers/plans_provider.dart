import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/models/plan_model.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// Provider for the Firestore collection
final plansCollectionProvider = Provider((ref) => FirebaseFirestore.instance.collection('plans'));

/// Stream of all active plans ordered by 'order'
final activePlansProvider = StreamProvider<List<Plan>>((ref) {
  final collection = ref.read(plansCollectionProvider);
  return collection
      .where('status', isEqualTo: PlanStatus.active.name)
      .snapshots()
      .map((snapshot) {
        final plans = snapshot.docs.map((doc) => Plan.fromFirestore(doc)).toList();
        // Sort in memory to avoid requiring a composite index in Firestore
        plans.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return plans;
      });
});

/// Stream of user-targeted plans
final userPlansProvider = Provider<AsyncValue<List<Plan>>>((ref) {
  final plans = ref.watch(activePlansProvider);
  return plans.whenData((list) => list.where((p) => p.type == PlanType.user).toList());
});

/// Stream of merchant-targeted plans
final merchantPlansProvider = Provider<AsyncValue<List<Plan>>>((ref) {
  final plans = ref.watch(activePlansProvider);
  return plans.whenData((list) => list.where((p) => p.type == PlanType.merchant).toList());
});

/// Stream of enterprise-targeted plans
final enterprisePlansProvider = Provider<AsyncValue<List<Plan>>>((ref) {
  final plans = ref.watch(activePlansProvider);
  return plans.whenData((list) => list.where((p) => p.type == PlanType.enterprise).toList());
});

/// Provider for the user's current plan details
final currentUserPlanProvider = FutureProvider<Plan?>((ref) async {
  final user = ref.watch(userProvider);
  if (user.planId == null || user.planId!.isEmpty) {
    // Return the default/free plan if handled specifically, 
    // or search for the one marked isDefault
    final collection = ref.read(plansCollectionProvider);
    final snapshot = await collection.where('isDefault', isEqualTo: true).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return Plan.fromFirestore(snapshot.docs.first);
    }
    return null;
  }
  
  final doc = await ref.read(plansCollectionProvider).doc(user.planId).get();
  if (doc.exists) {
    return Plan.fromFirestore(doc);
  }
  return null;
});
