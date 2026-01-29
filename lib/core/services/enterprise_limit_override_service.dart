import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// V17: Enterprise Limit Override Service
/// Permet aux admins de modifier les limites d'abonnement par entreprise
/// 
/// Fonctionnalités:
/// - Override des limites de salariés
/// - Override des limites de tontines
/// - Historique des modifications
/// - Demandes d'ajustement entreprises

class LimitOverride {
  final String id;
  final String companyId;
  final String companyName;
  final int? customMaxEmployees;
  final int? customMaxTontines;
  final String? reason;
  final String approvedBy; // Admin ID
  final DateTime createdAt;
  final DateTime? expiresAt; // Optional expiration

  LimitOverride({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.customMaxEmployees,
    this.customMaxTontines,
    this.reason,
    required this.approvedBy,
    required this.createdAt,
    this.expiresAt,
  });

  bool get hasEmployeeOverride => customMaxEmployees != null;
  bool get hasTontineOverride => customMaxTontines != null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'company_name': companyName,
    'custom_max_employees': customMaxEmployees,
    'custom_max_tontines': customMaxTontines,
    'reason': reason,
    'approved_by': approvedBy,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };

  factory LimitOverride.fromJson(Map<String, dynamic> json) => LimitOverride(
    id: json['id'],
    companyId: json['company_id'],
    companyName: json['company_name'],
    customMaxEmployees: json['custom_max_employees'],
    customMaxTontines: json['custom_max_tontines'],
    reason: json['reason'],
    approvedBy: json['approved_by'],
    createdAt: DateTime.parse(json['created_at']),
    expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
  );
}

class LimitAdjustmentRequest {
  final String id;
  final String companyId;
  final String companyName;
  final String requesterId;
  final int requestedEmployees;
  final int requestedTontines;
  final String reason;
  final DateTime requestedAt;
  final RequestStatus status;
  final String? adminNotes;
  final String? processedBy;
  final DateTime? processedAt;

  LimitAdjustmentRequest({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.requesterId,
    required this.requestedEmployees,
    required this.requestedTontines,
    required this.reason,
    required this.requestedAt,
    required this.status,
    this.adminNotes,
    this.processedBy,
    this.processedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'company_name': companyName,
    'requester_id': requesterId,
    'requested_employees': requestedEmployees,
    'requested_tontines': requestedTontines,
    'reason': reason,
    'requested_at': requestedAt.toIso8601String(),
    'status': status.name,
    'admin_notes': adminNotes,
    'processed_by': processedBy,
    'processed_at': processedAt?.toIso8601String(),
  };
}

enum RequestStatus { pending, approved, rejected }

class EnterpriseLimitOverrideService {
// ============ FIRESTORE IMPLEMENTATION ============

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  EnterpriseLimitOverrideService();

  // ============ ADMIN FUNCTIONS ============

  /// Create or update a limit override for a company
  Future<LimitOverride> setOverride({
    required String companyId,
    required String companyName,
    required String adminId,
    int? maxEmployees,
    int? maxTontines,
    String? reason,
    Duration? expiresIn,
  }) async {
    final id = 'OVR_${DateTime.now().millisecondsSinceEpoch}';
    final override = LimitOverride(
      id: id,
      companyId: companyId,
      companyName: companyName,
      customMaxEmployees: maxEmployees,
      customMaxTontines: maxTontines,
      reason: reason,
      approvedBy: adminId,
      createdAt: DateTime.now(),
      expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null,
    );

    try {
      // Persist to Firestore
      await _firestore
          .collection('enterprise_overrides')
          .doc(companyId)
          .set(override.toJson());

      debugPrint('[OVERRIDE] Set for $companyId: employees=$maxEmployees, tontines=$maxTontines by $adminId');
      return override;
    } catch (e) {
      debugPrint('[OVERRIDE] Error setting override: $e');
      rethrow;
    }
  }

  /// Remove override for a company
  Future<void> removeOverride(String companyId) async {
    try {
      await _firestore.collection('enterprise_overrides').doc(companyId).delete();
      debugPrint('[OVERRIDE] Removed for $companyId');
    } catch (e) {
      debugPrint('[OVERRIDE] Error removing override: $e');
    }
  }

  /// Get override for a company (if any)
  /// Note: Ideally this should be a Stream, but keeping Future for now to match interface
  Future<LimitOverride?> getOverride(String companyId) async {
    try {
      final doc = await _firestore.collection('enterprise_overrides').doc(companyId).get();
      if (!doc.exists) return null;

      final override = LimitOverride.fromJson(doc.data()!);
      if (override.isExpired) {
        // Cleanup expired
        removeOverride(companyId); 
        return null;
      }
      return override;
    } catch (e) {
      debugPrint('[OVERRIDE] Error fetching override: $e');
      return null;
    }
  }

  /// Get effective employee limit (with override)
  Future<int> getEffectiveEmployeeLimit(String companyId, int baseLimit) async {
    final override = await getOverride(companyId);
    if (override != null && override.hasEmployeeOverride) {
      return override.customMaxEmployees!;
    }
    return baseLimit;
  }

  /// Get effective tontine limit (with override)
  Future<int> getEffectiveTontineLimit(String companyId, int baseLimit) async {
    final override = await getOverride(companyId);
    if (override != null && override.hasTontineOverride) {
      return override.customMaxTontines!;
    }
    return baseLimit;
  }

  /// Get all active overrides (for admin panel)
  Future<List<LimitOverride>> getAllOverrides() async {
    try {
      final snapshot = await _firestore.collection('enterprise_overrides').get();
      return snapshot.docs
          .map((doc) => LimitOverride.fromJson(doc.data()))
          .where((o) => !o.isExpired)
          .toList();
    } catch (e) {
      debugPrint('[OVERRIDE] Error fetching all overrides: $e');
      return [];
    }
  }

  // ============ ENTERPRISE REQUEST FUNCTIONS ============

  /// Submit a limit adjustment request (from enterprise dashboard)
  Future<LimitAdjustmentRequest> requestAdjustment({
    required String companyId,
    required String companyName,
    required String requesterId,
    required int requestedEmployees,
    required int requestedTontines,
    required String reason,
  }) async {
    final id = 'REQ_${DateTime.now().millisecondsSinceEpoch}';
    final request = LimitAdjustmentRequest(
      id: id,
      companyId: companyId,
      companyName: companyName,
      requesterId: requesterId,
      requestedEmployees: requestedEmployees,
      requestedTontines: requestedTontines,
      reason: reason,
      requestedAt: DateTime.now(),
      status: RequestStatus.pending,
    );

    try {
       await _firestore.collection('limit_requests').doc(id).set(request.toJson());
       debugPrint('[LIMIT REQUEST] $companyName requests $requestedEmployees employees, $requestedTontines tontines');
       return request;
    } catch (e) {
      debugPrint('[LIMIT REQUEST] Error submitting request: $e');
      rethrow;
    }
  }

  /// Get pending requests (for admin panel)
  Stream<List<LimitAdjustmentRequest>> getPendingRequests() {
    return _firestore
        .collection('limit_requests')
        .where('status', isEqualTo: RequestStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LimitAdjustmentRequest(
                id: doc['id'],
                companyId: doc['company_id'],
                companyName: doc['company_name'],
                requesterId: doc['requester_id'],
                requestedEmployees: doc['requested_employees'],
                requestedTontines: doc['requested_tontines'],
                reason: doc['reason'],
                requestedAt: DateTime.parse(doc['requested_at']),
                status: RequestStatus.values.byName(doc['status']),
                adminNotes: doc['admin_notes'],
                processedBy: doc['processed_by'],
                processedAt: doc['processed_at'] != null ? DateTime.parse(doc['processed_at']) : null,
            ))
            .toList());
  }

  /// Process a request (admin action)
  Future<void> processRequest({
    required String requestId,
    required bool approve,
    required String adminId,
    String? adminNotes,
  }) async {
    try {
      final docRef = _firestore.collection('limit_requests').doc(requestId);
      final doc = await docRef.get();
      
      if (!doc.exists) return;

      final requestData = doc.data()!;
      
      if (approve) {
        // Create override
        await setOverride(
          companyId: requestData['company_id'],
          companyName: requestData['company_name'],
          adminId: adminId,
          maxEmployees: requestData['requested_employees'],
          maxTontines: requestData['requested_tontines'],
          reason: 'Approved: ${requestData['reason']}',
        );
      }

      // Update request status
      await docRef.update({
        'status': approve ? RequestStatus.approved.name : RequestStatus.rejected.name,
        'admin_notes': adminNotes,
        'processed_by': adminId,
        'processed_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[LIMIT REQUEST] $requestId ${approve ? "APPROVED" : "REJECTED"} by $adminId');
    } catch (e) {
      debugPrint('[LIMIT REQUEST] Error processing request: $e');
    }
  }
}

// ============ PROVIDERS ============

final enterpriseLimitOverrideServiceProvider = Provider<EnterpriseLimitOverrideService>((ref) {
  return EnterpriseLimitOverrideService();
});

