import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive Referral Service - Sponsorship Campaign Management
/// 
/// Handles referral/sponsorship system with:
/// - User referral codes and links
/// - Campaign management (admin)
/// - Reward tracking
/// - Statistics and analytics

/// Reward types compatible with technical platform status (no payment handling)
enum ReferralRewardType { 
  subscriptionMonth, // Mois d'abonnement offerts (Enterprise/Premium)
  freeContribution,  // Une cotisation offerte (Tontine)
  priorityAccess,    // Accès prioritaire
  badgeParrain,      // Badge sur le profil
}

enum ReferralStatus { pending, validated, rewarded, expired, cancelled }

class ReferralCampaign {
  final String id;
  final String name;
  final String description;
  final ReferralRewardType rewardType;
  final double rewardValue; // Number of months OR Value in EUR
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final int maxReferralsPerUser;
  final int minCirclesToValidate; // Referree must join X circles to validate
  final int totalReferrals;
  final double totalRewardsDistributed; // Value in EUR or Months
  final List<String> targetAudience; // 'all', 'merchants', 'enterprises', 'users'

  ReferralCampaign({
    required this.id,
    required this.name,
    required this.description,
    required this.rewardType,
    required this.rewardValue,
    required this.isActive,
    required this.startDate,
    this.endDate,
    this.maxReferralsPerUser = 50,
    this.minCirclesToValidate = 1,
    this.totalReferrals = 0,
    this.totalRewardsDistributed = 0,
    this.targetAudience = const ['all'],
  });

  ReferralCampaign copyWith({
    bool? isActive,
    int? totalReferrals,
    double? totalRewardsDistributed,
    List<String>? targetAudience,
  }) {
    return ReferralCampaign(
      id: id,
      name: name,
      description: description,
      rewardType: rewardType,
      rewardValue: rewardValue,
      isActive: isActive ?? this.isActive,
      startDate: startDate,
      endDate: endDate,
      maxReferralsPerUser: maxReferralsPerUser,
      minCirclesToValidate: minCirclesToValidate,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      totalRewardsDistributed: totalRewardsDistributed ?? this.totalRewardsDistributed,
      targetAudience: targetAudience ?? this.targetAudience,
    );
  }
}

class Referral {
  final String id;
  final String referrerId; // Who referred
  final String referrerName;
  final String referreeId; // Who was referred
  final String refereeName;
  final String referralCode;
  final String campaignId;
  final ReferralStatus status;
  final DateTime createdAt;
  final DateTime? validatedAt;
  final DateTime? rewardedAt;
  final double? rewardValue;
  final ReferralRewardType? rewardType;

  Referral({
    required this.id,
    required this.referrerId,
    required this.referrerName,
    required this.referreeId,
    required this.refereeName,
    required this.referralCode,
    required this.campaignId,
    this.status = ReferralStatus.pending,
    required this.createdAt,
    this.validatedAt,
    this.rewardedAt,
    this.rewardValue,
    this.rewardType,
  });

  Referral copyWith({
    ReferralStatus? status,
    DateTime? validatedAt,
    DateTime? rewardedAt,
    double? rewardValue,
    ReferralRewardType? rewardType,
  }) {
    return Referral(
      id: id,
      referrerId: referrerId,
      referrerName: referrerName,
      referreeId: referreeId,
      refereeName: refereeName,
      referralCode: referralCode,
      campaignId: campaignId,
      status: status ?? this.status,
      createdAt: createdAt,
      validatedAt: validatedAt ?? this.validatedAt,
      rewardedAt: rewardedAt ?? this.rewardedAt,
      rewardValue: rewardValue ?? this.rewardValue,
      rewardType: rewardType ?? this.rewardType,
    );
  }
}

class UserReferralInfo {
  final String referralCode;
  final String referralLink;
  final int totalReferrals;
  final int pendingReferrals;
  final int validatedReferrals;
  final double totalRewardsValue; // In EUR or Months
  final List<Referral> referralHistory;

  UserReferralInfo({
    required this.referralCode,
    required this.referralLink,
    required this.totalReferrals,
    required this.pendingReferrals,
    required this.validatedReferrals,
    required this.totalRewardsValue,
    required this.referralHistory,
  });
}

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final List<ReferralCampaign> _campaigns = [];
  final List<Referral> _referrals = [];
  final Map<String, String> _userCodes = {}; // userId -> code

  static const String _baseUrl = 'https://tontetic-app.web.app/join';

  // Initialize - no demo data, all data from Firestore
  void initDemoData() {
    // PRODUCTION: No demo data - all referral data comes from Firestore
    // The isReferralActive() method queries Firestore directly
    debugPrint('[Referral] Service initialized (no demo data)');
  }

  // ============ USER METHODS ============

  /// Generate or get existing referral code for user
  String getReferralCode(String userId, String userName) {
    if (_userCodes.containsKey(userId)) {
      return _userCodes[userId]!;
    }
    
    // Generate new code based on name
    final namePart = userName.toUpperCase().split(' ').first.substring(0, 
      userName.split(' ').first.length > 6 ? 6 : userName.split(' ').first.length);
    final randomPart = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    final code = '$namePart$randomPart';
    
    _userCodes[userId] = code;
    debugPrint('[Referral] Generated code: $code for $userName');
    return code;
  }

  /// Get referral link for sharing
  String getReferralLink(String referralCode) {
    return '$_baseUrl?ref=$referralCode';
  }

  /// Get user's referral info
  UserReferralInfo getUserReferralInfo(String userId, String userName) {
    final code = getReferralCode(userId, userName);
    final userReferrals = _referrals.where((r) => r.referrerId == userId).toList();
    
    return UserReferralInfo(
      referralCode: code,
      referralLink: getReferralLink(code),
      totalReferrals: userReferrals.length,
      pendingReferrals: userReferrals.where((r) => r.status == ReferralStatus.pending).length,
      validatedReferrals: userReferrals.where((r) => r.status == ReferralStatus.validated || r.status == ReferralStatus.rewarded).length,
      totalRewardsValue: userReferrals.where((r) => r.status == ReferralStatus.rewarded).fold(0, (total, r) => total + (r.rewardValue ?? 0)),
      referralHistory: userReferrals,
    );
  }

  /// Check if referral program is active (checks Firestore for active campaigns)
  Future<bool> isReferralActive() async {
    try {
      // Query Firestore for campaigns that are visible in app and active
      final snapshot = await FirebaseFirestore.instance
          .collection('referral_campaigns')
          .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      final hasActiveCampaign = snapshot.docs.isNotEmpty;
      debugPrint('[Referral] isReferralActive from Firestore: $hasActiveCampaign');
      return hasActiveCampaign;
    } catch (e) {
      debugPrint('[Referral] Error checking Firestore: $e');
      // Fallback to local check if Firestore fails
      return _campaigns.any((c) => c.isActive);
    }
  }

  /// Get active campaign from Firestore
  Future<ReferralCampaign?> getActiveCampaign() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('referral_campaigns')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: DateTime.now())
          .orderBy('endDate') // Get the one ending soonest or latest created
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      // Parse Reward Type safely
      ReferralRewardType rewardType = ReferralRewardType.subscriptionMonth;
      try {
        rewardType = ReferralRewardType.values.firstWhere(
            (e) => e.name == (data['rewardType'] as String? ?? 'subscriptionMonth'));
      } catch (_) {}

      return ReferralCampaign(
        id: doc.id,
        name: data['name'] ?? 'Campagne',
        description: data['description'] ?? '',
        rewardType: rewardType,
        rewardValue: (data['rewardValue'] as num?)?.toDouble() ?? 0.0,
        isActive: true,
        startDate: (data['startDate'] as Timestamp).toDate(),
        endDate: (data['endDate'] as Timestamp?)?.toDate(),
        maxReferralsPerUser: data['maxReferralsPerUser'] ?? 50,
        minCirclesToValidate: data['minCirclesToValidate'] ?? 1,
        targetAudience: List<String>.from(data['targetAudience'] ?? ['all']),
      );

    } catch (e) {
      debugPrint('[Referral] Error fetching active campaign: $e');
      return null;
    }
  }

  /// Register a new referral
  Future<void> registerReferral({
    required String referrerId,
    required String referrerName,
    required String referreeId,
    required String refereeName,
    required String referralCode,
  }) async {
    final campaign = await getActiveCampaign();
    if (campaign == null) {
      debugPrint('[Referral] No active campaign');
      return;
    }

    final referral = Referral(
      id: 'ref_${_referrals.length + 1}',
      referrerId: referrerId,
      referrerName: referrerName,
      referreeId: referreeId,
      refereeName: refereeName,
      referralCode: referralCode,
      campaignId: campaign.id,
      createdAt: DateTime.now(),
    );

    _referrals.add(referral);
    debugPrint('[Referral] Registered: $refereeName referred by $referrerName');
  }

  // ============ ADMIN METHODS ============

  /// Get all campaigns
  List<ReferralCampaign> getAllCampaigns() => List.unmodifiable(_campaigns);

  /// Get all referrals
  List<Referral> getAllReferrals() => List.unmodifiable(_referrals);

  /// Get referrals by status
  List<Referral> getReferralsByStatus(ReferralStatus status) =>
    _referrals.where((r) => r.status == status).toList();

  /// Validate a referral
  void validateReferral(String referralId) {
    final index = _referrals.indexWhere((r) => r.id == referralId);
    if (index == -1) return;

    _referrals[index] = _referrals[index].copyWith(
      status: ReferralStatus.validated,
      validatedAt: DateTime.now(),
    );
    debugPrint('[Referral] Validated: $referralId');
  }

  /// Reward a referral
  void rewardReferral(String referralId) {
    final index = _referrals.indexWhere((r) => r.id == referralId);
    if (index == -1) return;

    final referral = _referrals[index];
    
    // Safe lookup - return early if campaign not found
    final campaignIndex = _campaigns.indexWhere((c) => c.id == referral.campaignId);
    if (campaignIndex == -1) {
      debugPrint('[Referral] Campaign not found for referral: $referralId');
      return;
    }
    final campaign = _campaigns[campaignIndex];

    _referrals[index] = referral.copyWith(
      status: ReferralStatus.rewarded,
      rewardedAt: DateTime.now(),
      rewardValue: campaign.rewardValue,
      rewardType: campaign.rewardType,
    );

    // Update campaign stats
    _campaigns[campaignIndex] = campaign.copyWith(
      totalReferrals: campaign.totalReferrals + 1,
      totalRewardsDistributed: campaign.totalRewardsDistributed + campaign.rewardValue,
    );

    debugPrint('[Referral] Rewarded: $referralId with ${campaign.rewardValue}');
  }

  /// Cancel a referral
  void cancelReferral(String referralId, String reason) {
    final index = _referrals.indexWhere((r) => r.id == referralId);
    if (index == -1) return;

    _referrals[index] = _referrals[index].copyWith(
      status: ReferralStatus.cancelled,
    );
    debugPrint('[Referral] Cancelled: $referralId - $reason');
  }

  /// Toggle campaign active status
  void toggleCampaignStatus(String campaignId) {
    final index = _campaigns.indexWhere((c) => c.id == campaignId);
    if (index == -1) return;

    _campaigns[index] = _campaigns[index].copyWith(
      isActive: !_campaigns[index].isActive,
    );
    debugPrint('[Referral] Campaign ${_campaigns[index].name} is now ${_campaigns[index].isActive ? 'active' : 'inactive'}');
  }

  /// Create new campaign
  String createCampaign({
    required String name,
    required String description,
    required ReferralRewardType rewardType,
    required double rewardValue,
    required DateTime startDate,
    DateTime? endDate,
    int maxReferralsPerUser = 50,
    int minCirclesToValidate = 1,
    List<String> targetAudience = const ['all'],
  }) {
    final id = 'camp_ref_${(_campaigns.length + 1).toString().padLeft(3, '0')}';
    
    _campaigns.add(ReferralCampaign(
      id: id,
      name: name,
      description: description,
      rewardType: rewardType,
      rewardValue: rewardValue,
      isActive: false,
      startDate: startDate,
      endDate: endDate,
      maxReferralsPerUser: maxReferralsPerUser,
      minCirclesToValidate: minCirclesToValidate,
      targetAudience: targetAudience,
    ));

    debugPrint('[Referral] Campaign created: $name');
    return id;
  }

  // ============ STATISTICS ============

  Map<String, dynamic> getStats() {
    final pending = _referrals.where((r) => r.status == ReferralStatus.pending).length;
    final validated = _referrals.where((r) => r.status == ReferralStatus.validated).length;
    final rewarded = _referrals.where((r) => r.status == ReferralStatus.rewarded).length;
    final cancelled = _referrals.where((r) => r.status == ReferralStatus.cancelled).length;
    
    final totalRewards = _referrals
      .where((r) => r.status == ReferralStatus.rewarded)
      .fold<double>(0, (total, r) => total + (r.rewardValue ?? 0));

    final activeCampaigns = _campaigns.where((c) => c.isActive).length;

    // Top referrers
    final referrerCounts = <String, int>{};
    for (final r in _referrals.where((r) => r.status == ReferralStatus.rewarded)) {
      referrerCounts[r.referrerName] = (referrerCounts[r.referrerName] ?? 0) + 1;
    }
    final topReferrers = referrerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalReferrals': _referrals.length,
      'pendingReferrals': pending,
      'validatedReferrals': validated,
      'rewardedReferrals': rewarded,
      'cancelledReferrals': cancelled,
      'totalRewardsDistributed': totalRewards,
      'activeCampaigns': activeCampaigns,
      'totalCampaigns': _campaigns.length,
      'conversionRate': _referrals.isEmpty ? 0 : ((rewarded / _referrals.length) * 100).toStringAsFixed(1),
      'topReferrers': topReferrers.take(5).map((e) => {'name': e.key, 'count': e.value}).toList(),
    };
  }

  // ============ EXPORT ============

  List<Map<String, dynamic>> exportReferralsToJson() {
    return _referrals.map((r) => {
      'id': r.id,
      'referrerId': r.referrerId,
      'referrerName': r.referrerName,
      'referreeId': r.referreeId,
      'refereeName': r.refereeName,
      'referralCode': r.referralCode,
      'campaignId': r.campaignId,
      'status': r.status.name,
      'createdAt': r.createdAt.toIso8601String(),
      'validatedAt': r.validatedAt?.toIso8601String(),
      'rewardedAt': r.rewardedAt?.toIso8601String(),
      'rewardValue': r.rewardValue,
      'rewardType': r.rewardType?.name,
    }).toList();
  }

  String exportReferralsToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('ID,ReferrerName,RefereeName,ReferralCode,CampaignId,Status,CreatedAt,ValidatedAt,RewardedAt,RewardValue,RewardType');
    
    for (final r in _referrals) {
      buffer.writeln(
        '"${r.id}","${r.referrerName}","${r.refereeName}","${r.referralCode}","${r.campaignId}","${r.status.name}","${r.createdAt.toIso8601String()}","${r.validatedAt?.toIso8601String() ?? ''}","${r.rewardedAt?.toIso8601String() ?? ''}","${r.rewardValue ?? ''}","${r.rewardType?.name ?? ''}"'
      );
    }
    return buffer.toString();
  }

  // Helper methods
  String getRewardTypeLabel(ReferralRewardType type) {
    switch (type) {
      case ReferralRewardType.subscriptionMonth:
        return '📅 Mois d\'abonnement offerts';
      case ReferralRewardType.freeContribution:
        return '🎁 Cotisation offerte';
      case ReferralRewardType.priorityAccess:
        return '⚡ Accès prioritaire';
      case ReferralRewardType.badgeParrain:
        return '🏅 Badge Parrain';
    }
  }

  String getStatusLabel(ReferralStatus status) {
    switch (status) {
      case ReferralStatus.pending:
        return 'En attente';
      case ReferralStatus.validated:
        return 'Validé';
      case ReferralStatus.rewarded:
        return 'Récompensé';
      case ReferralStatus.expired:
        return 'Expiré';
      case ReferralStatus.cancelled:
        return 'Annulé';
    }
  }
}
