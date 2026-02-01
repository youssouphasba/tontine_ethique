import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/models/enterprise_model.dart';

class EnterpriseService {
  final FirebaseFirestore _firestore;

  EnterpriseService(this._firestore);

  /// Creates a new Enterprise document
  Future<void> createEnterprise(EnterpriseModel enterprise) async {
    await _firestore.collection('enterprises').doc(enterprise.id).set(enterprise.toFirestore());
  }

  /// Fetches an Enterprise by ID
  Future<EnterpriseModel?> getEnterprise(String id) async {
    final doc = await _firestore.collection('enterprises').doc(id).get();
    if (doc.exists) {
      return EnterpriseModel.fromFirestore(doc);
    }
    return null;
  }
  
  /// Get Enterprise by Owner ID
  Future<EnterpriseModel?> getEnterpriseByOwner(String ownerId) async {
    final query = await _firestore.collection('enterprises').where('ownerId', isEqualTo: ownerId).limit(1).get();
    if (query.docs.isNotEmpty) {
      return EnterpriseModel.fromFirestore(query.docs.first);
    }
    return null;
  }
}

final enterpriseServiceProvider = Provider<EnterpriseService>((ref) {
  return EnterpriseService(FirebaseFirestore.instance);
});
