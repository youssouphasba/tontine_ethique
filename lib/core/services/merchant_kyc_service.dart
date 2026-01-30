import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// V16: Merchant KYC Service
/// Handles Know Your Customer verification for marketplace sellers
/// 
/// Verification levels:
/// - basic: Charter signed only (default)
/// - verified: Documents submitted and approved
/// - premium: Full business verification
/// - MIGRATED TO FIRESTORE

enum MerchantKYCStatus {
  notStarted,       // No documents submitted
  documentsSubmitted, // Waiting for review
  underReview,      // Admin is reviewing
  verified,         // Approved
  rejected,         // Rejected with reason
  expired,          // Needs re-verification
}

enum MerchantKYCLevel {
  basic,    // Charter signed
  verified, // ID verified
  premium,  // Full business verification
}

class MerchantKYCDocument {
  final String id;
  final String merchantId;
  final String type; // 'id_document', 'selfie', 'business_registration'
  final String url;
  final DateTime uploadedAt;
  final String? reviewNotes;
  final bool isApproved;

  MerchantKYCDocument({
    required this.id,
    required this.merchantId,
    required this.type,
    required this.url,
    required this.uploadedAt,
    this.reviewNotes,
    this.isApproved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant_id': merchantId,
    'type': type,
    'url': url,
    'uploaded_at': uploadedAt.toIso8601String(),
    'review_notes': reviewNotes,
    'is_approved': isApproved,
  };

  factory MerchantKYCDocument.fromJson(Map<String, dynamic> json) => MerchantKYCDocument(
    id: json['id'],
    merchantId: json['merchant_id'],
    type: json['type'],
    url: json['url'],
    uploadedAt: DateTime.parse(json['uploaded_at']),
    reviewNotes: json['review_notes'],
    isApproved: json['is_approved'] ?? false,
  );
}

class MerchantKYCApplication {
  final String id;
  final String merchantId;
  final MerchantKYCStatus status;
  final MerchantKYCLevel level;
  final List<MerchantKYCDocument> documents;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  MerchantKYCApplication({
    required this.id,
    required this.merchantId,
    required this.status,
    required this.level,
    required this.documents,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant_id': merchantId,
    'status': status.name,
    'level': level.name,
    'submitted_at': submittedAt.toIso8601String(),
    'reviewed_at': reviewedAt?.toIso8601String(),
    'reviewed_by': reviewedBy,
    'rejection_reason': rejectionReason,
  };

  factory MerchantKYCApplication.fromJson(Map<String, dynamic> json) => MerchantKYCApplication(
    id: json['id'],
    merchantId: json['merchant_id'],
    status: MerchantKYCStatus.values.byName(json['status']),
    level: MerchantKYCLevel.values.byName(json['level'] ?? 'basic'),
    documents: [],
    submittedAt: DateTime.parse(json['submitted_at']),
    reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']) : null,
    reviewedBy: json['reviewed_by'],
    rejectionReason: json['rejection_reason'],
  );
}

class MerchantKYCService {
  final FirebaseFirestore _firestore;

  MerchantKYCService() : _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _kycCollection => 
      _firestore.collection('merchant_kyc');
      
  CollectionReference<Map<String, dynamic>> get _docsCollection => 
      _firestore.collection('merchant_kyc_documents');

  /// Check if merchant can publish products
  Future<bool> canPublishProducts(String merchantId) async {
    final application = await getApplication(merchantId);
    
    // At minimum, merchant must have signed charter (basic level)
    // For full marketplace, require verified status
    if (application == null) return false;
    return application.status == MerchantKYCStatus.verified;
  }

  /// Check merchant's current KYC status
  Future<MerchantKYCStatus> getStatus(String merchantId) async {
    final application = await getApplication(merchantId);
    return application?.status ?? MerchantKYCStatus.notStarted;
  }

  /// Get merchant's KYC application
  Future<MerchantKYCApplication?> getApplication(String merchantId) async {
    final snapshot = await _kycCollection
        .where('merchant_id', isEqualTo: merchantId)
        .orderBy('submitted_at', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return MerchantKYCApplication.fromJson(snapshot.docs.first.data());
  }

  /// Submit KYC documents
  Future<bool> submitDocuments({
    required String merchantId,
    required String idDocumentUrl,
    required String selfieUrl,
    String? businessRegistrationUrl,
  }) async {
    final now = DateTime.now();
    final applicationId = 'kyc_${merchantId}_${now.millisecondsSinceEpoch}';

    // Create application
    await _kycCollection.doc(applicationId).set({
      'id': applicationId,
      'merchant_id': merchantId,
      'status': MerchantKYCStatus.documentsSubmitted.name,
      'level': businessRegistrationUrl != null 
          ? MerchantKYCLevel.premium.name 
          : MerchantKYCLevel.verified.name,
      'submitted_at': now.toIso8601String(),
    });

    // Save documents
    final documents = [
      {'type': 'id_document', 'url': idDocumentUrl},
      {'type': 'selfie', 'url': selfieUrl},
    ];
    
    if (businessRegistrationUrl != null) {
      documents.add({'type': 'business_registration', 'url': businessRegistrationUrl});
    }

    for (final doc in documents) {
      final docId = '${applicationId}_${doc['type']}';
      await _docsCollection.doc(docId).set({
        'id': docId,
        'merchant_id': merchantId,
        'application_id': applicationId,
        'type': doc['type'],
        'url': doc['url'],
        'uploaded_at': now.toIso8601String(),
        'is_approved': false,
      });
    }

    // Create admin notification (Support Ticket)
    await _firestore.collection('support_tickets').doc('ticket_kyc_$applicationId').set({
      'id': 'ticket_kyc_$applicationId',
      'user_id': merchantId,
      'category': 'kyc',
      'subject': 'Nouvelle demande KYC Marchand',
      'description': 'Documents soumis pour vérification',
      'status': 'open',
      'created_at': now.toIso8601String(),
    });

    debugPrint('[KYC] Documents submitted for merchant $merchantId');
    return true;
  }

  /// Admin: Approve KYC application
  Future<bool> approveApplication({
    required String applicationId,
    required String reviewerId,
    String? notes,
  }) async {
    await _kycCollection.doc(applicationId).update({
      'status': MerchantKYCStatus.verified.name,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': reviewerId,
    });

    // Approve all documents
    // Note: requires batch update or multiple writes
    final docsSnapshot = await _docsCollection.where('application_id', isEqualTo: applicationId).get();
    final batch = _firestore.batch();
    
    for (var doc in docsSnapshot.docs) {
      batch.update(doc.reference, {
        'is_approved': true,
        'review_notes': notes,
      });
    }
    await batch.commit();

    debugPrint('[KYC] Application $applicationId approved by $reviewerId');
    return true;
  }

  /// Admin: Reject KYC application
  Future<bool> rejectApplication({
    required String applicationId,
    required String reviewerId,
    required String reason,
  }) async {
    await _kycCollection.doc(applicationId).update({
      'status': MerchantKYCStatus.rejected.name,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': reviewerId,
      'rejection_reason': reason,
    });

    debugPrint('[KYC] Application $applicationId rejected: $reason');
    return true;
  }

  /// Get pending applications (admin)
  Future<List<MerchantKYCApplication>> getPendingApplications() async {
    final snapshot = await _kycCollection
        .where('status', whereIn: [
          MerchantKYCStatus.documentsSubmitted.name,
          MerchantKYCStatus.underReview.name,
        ])
        .orderBy('submitted_at', descending: false)
        .get();

    return snapshot.docs
        .map((e) => MerchantKYCApplication.fromJson(e.data()))
        .toList();
  }

  /// Get KYC statistics (admin dashboard)
  Future<Map<String, int>> getStatistics() async {
    final snapshot = await _kycCollection.get();

    final stats = <String, int>{
      'total': 0,
      'pending': 0,
      'verified': 0,
      'rejected': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      stats['total'] = (stats['total'] ?? 0) + 1;
      final status = data['status'] as String;
      if (status == MerchantKYCStatus.documentsSubmitted.name || 
          status == MerchantKYCStatus.underReview.name) {
        stats['pending'] = (stats['pending'] ?? 0) + 1;
      } else if (status == MerchantKYCStatus.verified.name) {
        stats['verified'] = (stats['verified'] ?? 0) + 1;
      } else if (status == MerchantKYCStatus.rejected.name) {
        stats['rejected'] = (stats['rejected'] ?? 0) + 1;
      }
    }

    return stats;
  }
}

// ============ PROVIDER ============

final merchantKYCServiceProvider = Provider<MerchantKYCService>((ref) {
  return MerchantKYCService();
});
