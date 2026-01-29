import 'package:flutter/foundation.dart';

/// With audience targeting and analytics

enum CampaignType { push, email, sms, inAppBanner }
enum CampaignStatus { draft, scheduled, sending, sent, cancelled }

enum TargetAudience {
  all,
  newUsers,          // Registered < 7 days
  inactiveUsers,     // No activity > 30 days
  highScoreUsers,    // Score > 80
  lowScoreUsers,     // Score < 50
  merchants,
  enterprises,
  byRegion,          // Needs region parameter
  byCircleStatus,    // In active circle or not
}

class Campaign {
  final String id;
  final String name;
  final CampaignType type;
  final TargetAudience audience;
  final String? regionFilter;
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

  Campaign copyWith({
    CampaignStatus? status,
    DateTime? scheduledAt,
    DateTime? sentAt,
    CampaignStats? stats,
  }) {
    return Campaign(
      id: id,
      name: name,
      type: type,
      audience: audience,
      regionFilter: regionFilter,
      title: title,
      content: content,
      imageUrl: imageUrl,
      deepLink: deepLink,
      createdAt: createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      createdBy: createdBy,
      stats: stats ?? this.stats,
    );
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

  double get deliveryRate => targetedUsers == 0 ? 0 : delivered / targetedUsers * 100;
  double get openRate => delivered == 0 ? 0 : opened / delivered * 100;
  double get clickRate => opened == 0 ? 0 : clicked / opened * 100;
}

class CampaignTemplate {
  final String id;
  final String name;
  final CampaignType type;
  final String titleTemplate;
  final String contentTemplate;
  final String? imageUrl;

  CampaignTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.titleTemplate,
    required this.contentTemplate,
    this.imageUrl,
  });
}

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final List<Campaign> _campaigns = [];
  final List<CampaignTemplate> _templates = [];

  // Initialize with demo data
  void initDemoData() {
    // Templates
    _templates.addAll([
      CampaignTemplate(
        id: 'tpl_welcome',
        name: 'Bienvenue',
        type: CampaignType.push,
        titleTemplate: '🎉 Bienvenue sur Tontetic !',
        contentTemplate: 'Découvrez comment rejoindre votre première tontine et commencer à atteindre vos objectifs.',
      ),
      CampaignTemplate(
        id: 'tpl_inactive',
        name: 'Réengagement',
        type: CampaignType.push,
        titleTemplate: '👋 Vous nous manquez !',
        contentTemplate: 'Vos amis cotisent sans vous ! Revenez voir les nouveaux cercles disponibles.',
      ),
      CampaignTemplate(
        id: 'tpl_promo',
        name: 'Promotion',
        type: CampaignType.push,
        titleTemplate: '🚀 Offre spéciale !',
        contentTemplate: 'Créez un cercle cette semaine et bénéficiez de 0% de frais pendant 3 mois !',
      ),
      CampaignTemplate(
        id: 'tpl_tabaski',
        name: 'Tabaski',
        type: CampaignType.push,
        titleTemplate: '🐑 Préparez Tabaski !',
        contentTemplate: 'Rejoignez un cercle Tabaski et assurez votre mouton cette année.',
      ),
    ]);

    // PRODUCTION: No demo campaigns - campaigns come from Firestore 'broadcasts' collection
    debugPrint('[Campaign] Service initialized (no demo campaigns)');
  }

  // CRUD Operations
  List<Campaign> getAllCampaigns() => List.unmodifiable(_campaigns);

  List<Campaign> getCampaignsByStatus(CampaignStatus status) =>
    _campaigns.where((c) => c.status == status).toList();

  List<CampaignTemplate> getTemplates() => List.unmodifiable(_templates);

  Campaign? getCampaignById(String id) {
    try {
      return _campaigns.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  String createCampaign({
    required String name,
    required CampaignType type,
    required TargetAudience audience,
    String? regionFilter,
    required String title,
    required String content,
    String? imageUrl,
    String? deepLink,
    DateTime? scheduledAt,
    required String createdBy,
  }) {
    final campaignId = 'camp_${(_campaigns.length + 1).toString().padLeft(3, '0')}';
    final campaign = Campaign(
      id: campaignId,
      name: name,
      type: type,
      audience: audience,
      regionFilter: regionFilter,
      title: title,
      content: content,
      imageUrl: imageUrl,
      deepLink: deepLink,
      createdAt: DateTime.now(),
      scheduledAt: scheduledAt,
      status: scheduledAt != null ? CampaignStatus.scheduled : CampaignStatus.draft,
      createdBy: createdBy,
    );
    _campaigns.add(campaign);
    debugPrint('[Campaign] Created: $campaignId - $name');
    return campaignId;
  }

  void scheduleCampaign(String campaignId, DateTime scheduledAt) {
    final index = _campaigns.indexWhere((c) => c.id == campaignId);
    if (index == -1) return;

    _campaigns[index] = _campaigns[index].copyWith(
      status: CampaignStatus.scheduled,
      scheduledAt: scheduledAt,
    );
    debugPrint('[Campaign] Scheduled: $campaignId for $scheduledAt');
  }

  void sendCampaign(String campaignId) {
    final index = _campaigns.indexWhere((c) => c.id == campaignId);
    if (index == -1) return;

    // Simulate targeting users
    final targetCount = _estimateAudienceSize(_campaigns[index].audience);

    _campaigns[index] = _campaigns[index].copyWith(
      status: CampaignStatus.sent,
      sentAt: DateTime.now(),
      stats: CampaignStats(
        targetedUsers: targetCount,
        delivered: (targetCount * 0.92).round(), // 92% delivery rate simulation
        opened: 0,
        clicked: 0,
        unsubscribed: 0,
      ),
    );
    debugPrint('[Campaign] Sent: $campaignId to $targetCount users');
  }

  void cancelCampaign(String campaignId) {
    final index = _campaigns.indexWhere((c) => c.id == campaignId);
    if (index == -1) return;

    _campaigns[index] = _campaigns[index].copyWith(
      status: CampaignStatus.cancelled,
    );
    debugPrint('[Campaign] Cancelled: $campaignId');
  }

  int _estimateAudienceSize(TargetAudience audience) {
    // Simulated audience sizes
    switch (audience) {
      case TargetAudience.all:
        return 12458;
      case TargetAudience.newUsers:
        return 1250;
      case TargetAudience.inactiveUsers:
        return 3420;
      case TargetAudience.highScoreUsers:
        return 4560;
      case TargetAudience.lowScoreUsers:
        return 890;
      case TargetAudience.merchants:
        return 456;
      case TargetAudience.enterprises:
        return 48;
      case TargetAudience.byRegion:
        return 2500;
      case TargetAudience.byCircleStatus:
        return 5600;
    }
  }

  // Analytics
  Map<String, dynamic> getGlobalStats() {
    final sent = _campaigns.where((c) => c.status == CampaignStatus.sent).toList();
    
    int totalTargeted = 0;
    int totalDelivered = 0;
    int totalOpened = 0;
    int totalClicked = 0;

    for (final c in sent) {
      totalTargeted += c.stats.targetedUsers;
      totalDelivered += c.stats.delivered;
      totalOpened += c.stats.opened;
      totalClicked += c.stats.clicked;
    }

    return {
      'totalCampaigns': _campaigns.length,
      'sentCampaigns': sent.length,
      'scheduledCampaigns': _campaigns.where((c) => c.status == CampaignStatus.scheduled).length,
      'draftCampaigns': _campaigns.where((c) => c.status == CampaignStatus.draft).length,
      'totalTargeted': totalTargeted,
      'totalDelivered': totalDelivered,
      'totalOpened': totalOpened,
      'totalClicked': totalClicked,
      'avgDeliveryRate': totalTargeted == 0 ? 0 : (totalDelivered / totalTargeted * 100).toStringAsFixed(1),
      'avgOpenRate': totalDelivered == 0 ? 0 : (totalOpened / totalDelivered * 100).toStringAsFixed(1),
      'avgClickRate': totalOpened == 0 ? 0 : (totalClicked / totalOpened * 100).toStringAsFixed(1),
    };
  }

  String getAudienceLabel(TargetAudience audience) {
    switch (audience) {
      case TargetAudience.all:
        return 'Tous les utilisateurs';
      case TargetAudience.newUsers:
        return 'Nouveaux utilisateurs (< 7 jours)';
      case TargetAudience.inactiveUsers:
        return 'Utilisateurs inactifs (> 30 jours)';
      case TargetAudience.highScoreUsers:
        return 'Score élevé (> 80%)';
      case TargetAudience.lowScoreUsers:
        return 'Score faible (< 50%)';
      case TargetAudience.merchants:
        return 'Marchands';
      case TargetAudience.enterprises:
        return 'Entreprises';
      case TargetAudience.byRegion:
        return 'Par région';
      case TargetAudience.byCircleStatus:
        return 'Par statut cercle';
    }
  }

  String getCampaignTypeLabel(CampaignType type) {
    switch (type) {
      case CampaignType.push:
        return '📱 Push notification';
      case CampaignType.email:
        return '✉️ Email';
      case CampaignType.sms:
        return '💬 SMS';
      case CampaignType.inAppBanner:
        return '🏷️ Bannière in-app';
    }
  }

  // ============ EXPORT METHODS ============

  /// Export single campaign to JSON
  Map<String, dynamic> campaignToJson(Campaign campaign) {
    return {
      'id': campaign.id,
      'name': campaign.name,
      'type': campaign.type.name,
      'audience': campaign.audience.name,
      'regionFilter': campaign.regionFilter,
      'title': campaign.title,
      'content': campaign.content,
      'createdAt': campaign.createdAt.toIso8601String(),
      'scheduledAt': campaign.scheduledAt?.toIso8601String(),
      'sentAt': campaign.sentAt?.toIso8601String(),
      'status': campaign.status.name,
      'createdBy': campaign.createdBy,
      'stats': {
        'targetedUsers': campaign.stats.targetedUsers,
        'delivered': campaign.stats.delivered,
        'opened': campaign.stats.opened,
        'clicked': campaign.stats.clicked,
        'unsubscribed': campaign.stats.unsubscribed,
        'deliveryRate': campaign.stats.deliveryRate,
        'openRate': campaign.stats.openRate,
        'clickRate': campaign.stats.clickRate,
      },
    };
  }

  /// Export all campaigns to JSON
  List<Map<String, dynamic>> exportToJson() {
    return _campaigns.map(campaignToJson).toList();
  }

  /// Export all campaigns to CSV format
  String exportToCsv() {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('ID,Name,Type,Audience,Title,Status,CreatedAt,SentAt,TargetedUsers,Delivered,Opened,Clicked,DeliveryRate,OpenRate,ClickRate');
    
    // Data rows
    for (final c in _campaigns) {
      buffer.writeln(
        '"${c.id}","${c.name}","${c.type.name}","${c.audience.name}","${c.title.replaceAll('"', '""')}","${c.status.name}","${c.createdAt.toIso8601String()}","${c.sentAt?.toIso8601String() ?? ''}","${c.stats.targetedUsers}","${c.stats.delivered}","${c.stats.opened}","${c.stats.clicked}","${c.stats.deliveryRate.toStringAsFixed(1)}","${c.stats.openRate.toStringAsFixed(1)}","${c.stats.clickRate.toStringAsFixed(1)}"'
      );
    }
    return buffer.toString();
  }

  /// Export global stats to JSON
  Map<String, dynamic> exportStatsToJson() {
    final stats = getGlobalStats();
    stats['exportDate'] = DateTime.now().toIso8601String();
    return stats;
  }
}
