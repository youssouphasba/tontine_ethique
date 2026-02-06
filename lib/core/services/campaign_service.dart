import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/services/notification_service.dart';

/// Campaign Service - 100% Firestore Driven (No Mocks)
/// Handles creation, scheduling, and stats for communication campaigns.

enum CampaignType { push, email, sms, inAppBanner }
enum CampaignStatus { draft, scheduled, sending, sent, cancelled }

enum TargetAudience {
  all,
  newUsers,          // Registered < 7 days
  inactiveUsers,     // No activity > 30 days
  highScoreUsers,    // Score > 80
  lowScoreUsers,     // Score < 50
  merchants,         // Role = merchant
  enterprises,       // Role = enterprise
  byRegion,          // Needs region parameter
  byCircleStatus,    // In active circle or not
}

class Campaign {
  final String id;
  final String name;
  final CampaignType type;
  final TargetAudience audience;
  final String? regionFilter;
  final List<String>? specificUserIds; // For specific targeting
  final String title;
  final String content;
  final String? imageUrl;
  final String? deepLink;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final CampaignStatus status;
  final String createdBy;
  final CampaignStats stats;

  Campaign({
    required this.id,
    required this.name,
    required this.type,
    required this.audience,
    this.regionFilter,
    this.specificUserIds,
    required this.title,
    required this.content,
    this.imageUrl,
    this.deepLink,
    required this.createdAt,
    this.scheduledAt,
    this.sentAt,
    this.status = CampaignStatus.draft,
    required this.createdBy,
    CampaignStats? stats,
  }) : stats = stats ?? CampaignStats.empty();

  factory Campaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Campaign(
      id: doc.id,
      name: data['name'] ?? '',
      type: CampaignType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'push'), orElse: () => CampaignType.push),
      audience: TargetAudience.values.firstWhere(
        (e) => e.name == (data['audience'] ?? 'all'), orElse: () => TargetAudience.all),
      regionFilter: data['regionFilter'],
      specificUserIds: (data['specificUserIds'] as List?)?.map((e) => e.toString()).toList(),
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      deepLink: data['deepLink'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'draft'), orElse: () => CampaignStatus.draft),
      createdBy: data['createdBy'] ?? '',
      stats: CampaignStats.fromMap(data['stats'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'audience': audience.name,
      'regionFilter': regionFilter,
      'specificUserIds': specificUserIds,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'status': status.name,
      'createdBy': createdBy,
      'stats': stats.toMap(),
    };
  }
}

class CampaignStats {
  final int targetedUsers;
  final int delivered;
  final int opened;
  final int clicked;
  final int unsubscribed;

  CampaignStats({
    required this.targetedUsers,
    required this.delivered,
    required this.opened,
    required this.clicked,
    required this.unsubscribed,
  });

  factory CampaignStats.empty() => CampaignStats(
    targetedUsers: 0,
    delivered: 0,
    opened: 0,
    clicked: 0,
    unsubscribed: 0,
  );

  factory CampaignStats.fromMap(Map<String, dynamic> map) => CampaignStats(
    targetedUsers: map['targetedUsers'] ?? 0,
    delivered: map['delivered'] ?? 0,
    opened: map['opened'] ?? 0,
    clicked: map['clicked'] ?? 0,
    unsubscribed: map['unsubscribed'] ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'targetedUsers': targetedUsers,
    'delivered': delivered,
    'opened': opened,
    'clicked': clicked,
    'unsubscribed': unsubscribed,
  };
}

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final CollectionReference _collection = FirebaseFirestore.instance.collection('campaigns');

  /// Get live stream of all campaigns
  Stream<List<Campaign>> getCampaignsStream() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList());
  }

  /// Get live stream of campaigns by status
  Stream<List<Campaign>> getCampaignsByStatusStream(CampaignStatus status) {
    return _collection
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Campaign.fromFirestore(doc)).toList());
  }

  /// Create a new campaign (Draft or Scheduled)
  Future<String> createCampaign({
    required String name,
    required CampaignType type,
    required TargetAudience audience,
    String? regionFilter,
    List<String>? specificUserIds,
    required String title,
    required String content,
    String? imageUrl,
    String? deepLink,
    DateTime? scheduledAt,
    required String createdBy,
  }) async {
    final status = scheduledAt != null ? CampaignStatus.scheduled : CampaignStatus.draft;
    
    final docRef = await _collection.add({
      'name': name,
      'type': type.name,
      'audience': audience.name,
      'regionFilter': regionFilter,
      'specificUserIds': specificUserIds,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'deepLink': deepLink,
      'createdAt': FieldValue.serverTimestamp(), // Use server timestamp
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt) : null,
      'status': status.name,
      'createdBy': createdBy,
      'stats': CampaignStats.empty().toMap(),
    });

    debugPrint('[Campaign] Created real document: ${docRef.id}');
    return docRef.id;
  }

  /// Send a campaign immediately (REAL)
  /// Note: This updates the status to 'sending'. 
  /// A Cloud Function MUST listen to this change to perform the actual dispatch via FCM/Email provider.
  Future<void> sendCampaign(String campaignId) async {
    await _collection.doc(campaignId).update({
      'status': CampaignStatus.sending.name,
      'sentAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[Campaign] Mark as sending (Cloud Function trigger): $campaignId');
  }

  /// Schedule a campaign (REAL)
  Future<void> scheduleCampaign(String campaignId, DateTime scheduledAt) async {
    await _collection.doc(campaignId).update({
      'status': CampaignStatus.scheduled.name,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
    });
  }

  /// Cancel a campaign (REAL)
  Future<void> cancelCampaign(String campaignId) async {
    await _collection.doc(campaignId).update({
      'status': CampaignStatus.cancelled.name,
    });
  }

  /// Delete a campaign (REAL)
  Future<void> deleteCampaign(String campaignId) async {
    await _collection.doc(campaignId).delete();
  }

  // ============ HELPERS ============

  String getAudienceLabel(TargetAudience audience) {
    switch (audience) {
      case TargetAudience.all: return 'Tous';
      case TargetAudience.newUsers: return 'Nouveaux';
      case TargetAudience.inactiveUsers: return 'Inactifs';
      case TargetAudience.highScoreUsers: return 'Top Score';
      case TargetAudience.lowScoreUsers: return 'Low Score';
      case TargetAudience.merchants: return 'Marchands';
      case TargetAudience.enterprises: return 'Entreprises';
      case TargetAudience.byRegion: return 'Région';
      case TargetAudience.byCircleStatus: return 'Statut Cercle';
    }
  }

  String getCampaignTypeLabel(CampaignType type) {
    switch (type) {
      case CampaignType.push: return '📱 Push';
      case CampaignType.email: return '✉️ Email';
      case CampaignType.sms: return '💬 SMS';
      case CampaignType.inAppBanner: return '🏷️ In-App';
    }
  }
}
