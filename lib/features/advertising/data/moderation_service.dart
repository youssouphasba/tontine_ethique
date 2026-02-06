import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// V11.3 - Enhanced Moderation Service
// Tag-based reporting with priority suspension and admin filtering

enum ContentStatus {
  active,       // Visible in feed
  underReview,  // Suspended pending admin review
  rejected,     // Permanently removed
  restored,     // Cleared after review
}

/// Report tags with priority levels
enum ReportTag {
  arnaque,        // CRITICAL - 2 reports = immediate suspend
  produitInterdit,// CRITICAL - 2 reports = immediate suspend
  fakeProduct,    // HIGH - 3 reports
  misleading,     // MEDIUM - 3 reports
  inappropriate,  // MEDIUM - 3 reports
  spam,           // LOW - 3 reports
  other,          // LOW - 3 reports
}

extension ReportTagExtension on ReportTag {
  String get label {
    switch (this) {
      case ReportTag.arnaque: return '#Arnaque';
      case ReportTag.produitInterdit: return '#ProduitInterdit';
      case ReportTag.fakeProduct: return '#FauxProduit';
      case ReportTag.misleading: return '#Trompeur';
      case ReportTag.inappropriate: return '#Inapproprié';
      case ReportTag.spam: return '#Spam';
      case ReportTag.other: return '#Autre';
    }
  }

  String get description {
    switch (this) {
      case ReportTag.arnaque: return 'Arnaque / Escroquerie';
      case ReportTag.produitInterdit: return 'Armes, drogues, contrefaçon...';
      case ReportTag.fakeProduct: return 'Produit non conforme aux visuels';
      case ReportTag.misleading: return 'Prix ou infos trompeuses';
      case ReportTag.inappropriate: return 'Contenu violent ou haineux';
      case ReportTag.spam: return 'Publicité abusive / Spam';
      case ReportTag.other: return 'Autre problème';
    }
  }

  String get emoji {
    switch (this) {
      case ReportTag.arnaque: return '🚨';
      case ReportTag.produitInterdit: return '🚫';
      case ReportTag.fakeProduct: return '📷';
      case ReportTag.misleading: return '💰';
      case ReportTag.inappropriate: return '⚠️';
      case ReportTag.spam: return '📢';
      case ReportTag.other: return '❓';
    }
  }

  int get priority {
    switch (this) {
      case ReportTag.arnaque: return 1;       // Highest
      case ReportTag.produitInterdit: return 1;
      case ReportTag.fakeProduct: return 2;
      case ReportTag.misleading: return 3;
      case ReportTag.inappropriate: return 3;
      case ReportTag.spam: return 4;
      case ReportTag.other: return 5;         // Lowest
    }
  }

  bool get isCritical => priority == 1;
  int get suspendThreshold => isCritical ? 2 : 3;
}

class ContentReport {
  final String id;
  final String contentId;
  final String reporterId;
  final ReportTag tag;
  final String? comment;
  final DateTime timestamp;

  ContentReport({
    required this.id,
    required this.contentId,
    required this.reporterId,
    required this.tag,
    this.comment,
    required this.timestamp,
  });
}

class ModerationCase {
  final String contentId;
  final String merchantId;
  final String merchantName;
  final String contentTitle;
  final List<ContentReport> reports;
  final ContentStatus status;
  final DateTime? suspendedAt;
  final String? adminDecision;
  final DateTime? resolvedAt;
  final String? adminId;
  final String? adminNote;

  ModerationCase({
    required this.contentId,
    required this.merchantId,
    required this.merchantName,
    required this.contentTitle,
    required this.reports,
    required this.status,
    this.suspendedAt,
    this.adminDecision,
    this.resolvedAt,
    this.adminId,
    this.adminNote,
  });

  ModerationCase copyWith({
    ContentStatus? status,
    List<ContentReport>? reports,
    DateTime? suspendedAt,
    String? adminDecision,
    DateTime? resolvedAt,
    String? adminId,
    String? adminNote,
  }) {
    return ModerationCase(
      contentId: contentId,
      merchantId: merchantId,
      merchantName: merchantName,
      contentTitle: contentTitle,
      reports: reports ?? this.reports,
      status: status ?? this.status,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      adminDecision: adminDecision ?? this.adminDecision,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      adminId: adminId ?? this.adminId,
      adminNote: adminNote ?? this.adminNote,
    );
  }

  int get reportCount => reports.length;
  
  /// Get count of reports for a specific tag
  int getTagCount(ReportTag tag) => reports.where((r) => r.tag == tag).length;
  
  /// Get the primary (most frequent) tag
  ReportTag get primaryTag {
    if (reports.isEmpty) return ReportTag.other;
    final tagCounts = <ReportTag, int>{};
    for (final r in reports) {
      tagCounts[r.tag] = (tagCounts[r.tag] ?? 0) + 1;
    }
    return tagCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get highest priority tag in reports
  ReportTag get highestPriorityTag {
    if (reports.isEmpty) return ReportTag.other;
    return reports.map((r) => r.tag).reduce((a, b) => a.priority < b.priority ? a : b);
  }

  /// Check if any critical tag reached its threshold
  bool get hasCriticalThreshold {
    return getTagCount(ReportTag.arnaque) >= 2 || 
           getTagCount(ReportTag.produitInterdit) >= 2;
  }

  /// Get all unique tags in this case
  Set<ReportTag> get allTags => reports.map((r) => r.tag).toSet();
}

class ModerationState {
  final Map<String, ModerationCase> cases;
  final List<String> adminNotifications;
  final Map<String, int> merchantPenalties;
  final ReportTag? activeFilter; // Admin filter

  ModerationState({
    this.cases = const {},
    this.adminNotifications = const [],
    this.merchantPenalties = const {},
    this.activeFilter,
  });

  ModerationState copyWith({
    Map<String, ModerationCase>? cases,
    List<String>? adminNotifications,
    Map<String, int>? merchantPenalties,
    ReportTag? activeFilter,
    bool clearFilter = false,
  }) {
    return ModerationState(
      cases: cases ?? this.cases,
      adminNotifications: adminNotifications ?? this.adminNotifications,
      merchantPenalties: merchantPenalties ?? this.merchantPenalties,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
    );
  }

  List<ModerationCase> get pendingCases {
    var pending = cases.values.where((c) => c.status == ContentStatus.underReview).toList();
    
    // Apply filter if active
    if (activeFilter != null) {
      pending = pending.where((c) => c.allTags.contains(activeFilter)).toList();
    }
    
    // Sort by priority (critical first)
    pending.sort((a, b) => a.highestPriorityTag.priority.compareTo(b.highestPriorityTag.priority));
    
    return pending;
  }

  /// Get count of cases by tag for filter badges
  Map<ReportTag, int> get tagCounts {
    final counts = <ReportTag, int>{};
    for (final c in cases.values.where((c) => c.status == ContentStatus.underReview)) {
      for (final tag in c.allTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }
}

class ModerationNotifier extends StateNotifier<ModerationState> {
  static const int honorPenalty = 30;
  static const int criticalPenalty = 50;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _moderationSub;

  ModerationNotifier() : super(ModerationState()) {
    _initSync();
  }

  void _initSync() {
    _moderationSub = _firestore.collection('moderation_cases').snapshots().listen((snapshot) {
      final cases = <String, ModerationCase>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawReports = data['reports'] as List? ?? [];
        
        cases[doc.id] = ModerationCase(
          contentId: doc.id,
          merchantId: data['merchantId'] ?? '',
          merchantName: data['merchantName'] ?? '',
          contentTitle: data['contentTitle'] ?? '',
          status: ContentStatus.values.firstWhere(
            (e) => e.name == data['status'], 
            orElse: () => ContentStatus.underReview
          ),
          suspendedAt: (data['suspendedAt'] as Timestamp?)?.toDate(),
          adminDecision: data['adminDecision'],
          resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
          adminId: data['adminId'],
          adminNote: data['adminNote'],
          reports: rawReports.map((r) {
            final rData = r as Map<String, dynamic>;
            return ContentReport(
              id: rData['id'] ?? '',
              contentId: doc.id,
              reporterId: rData['reporterId'] ?? '',
              tag: ReportTag.values.firstWhere(
                (e) => e.name == rData['tag'], 
                orElse: () => ReportTag.other
              ),
              comment: rData['comment'],
              timestamp: (rData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          }).toList(),
        );
      }
      state = state.copyWith(cases: cases);
    });
  }

  @override
  void dispose() {
    _moderationSub?.cancel();
    super.dispose();
  }

  /// Submit a report with tag
  Future<bool> reportContent({
    required String contentId,
    required String reporterId,
    required ReportTag tag,
    String? comment,
    required String merchantId,
    required String merchantName,
    required String contentTitle,
  }) async {
    final cases = Map<String, ModerationCase>.from(state.cases);
    
    final existingCase = cases[contentId];
    final newReport = ContentReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contentId: contentId,
      reporterId: reporterId,
      tag: tag,
      comment: comment,
      timestamp: DateTime.now(),
    );

    if (existingCase != null) {
      // Check if this user already reported
      if (existingCase.reports.any((r) => r.reporterId == reporterId)) {
        return false;
      }
      
      final updatedCase = existingCase.copyWith(
        reports: [...existingCase.reports, newReport],
      );
      cases[contentId] = updatedCase;
      
      // Check thresholds
      if (updatedCase.status == ContentStatus.active) {
        // CRITICAL: Immediate suspend for 2 #Arnaque or #ProduitInterdit
        if (updatedCase.hasCriticalThreshold) {
          return _suspendContent(contentId, merchantId, isCritical: true);
        }
        // NORMAL: 3 reports of any kind
        if (updatedCase.reportCount >= 3) {
          return _suspendContent(contentId, merchantId, isCritical: false);
        }
      }
    } else {
      cases[contentId] = ModerationCase(
        contentId: contentId,
        merchantId: merchantId,
        merchantName: merchantName,
        contentTitle: contentTitle,
        reports: [newReport],
        status: ContentStatus.active,
      );
    }

    state = state.copyWith(cases: cases);
    return false;
  }

  Future<bool> _suspendContent(String contentId, String merchantId, {required bool isCritical}) async {
    final existingCase = state.cases[contentId];
    if (existingCase == null) return false;

    // Apply penalty (higher for critical)
    final penalty = isCritical ? criticalPenalty : honorPenalty;

    await _firestore.collection('moderation_cases').doc(contentId).set({
      'merchantId': merchantId,
      'merchantName': existingCase.merchantName,
      'contentTitle': existingCase.contentTitle,
      'status': ContentStatus.underReview.name,
      'suspendedAt': FieldValue.serverTimestamp(),
      'reports': existingCase.reports.map((r) => {
        'id': r.id,
        'reporterId': r.reporterId,
        'tag': r.tag.name,
        'comment': r.comment,
        'timestamp': r.timestamp,
      }).toList(),
    }, SetOptions(merge: true));

    // In a real app, we would also update the merchant's honor score in 'users' collection
    await _firestore.collection('users').doc(merchantId).update({
      'honorScore': FieldValue.increment(-penalty),
    });

    return true;
  }

  Future<void> restoreContent(String contentId, {String? adminId, String? note}) async {
    final existingCase = state.cases[contentId];
    if (existingCase == null) return;

    final refund = existingCase.hasCriticalThreshold ? criticalPenalty : honorPenalty;

    await _firestore.collection('moderation_cases').doc(contentId).update({
      'status': ContentStatus.restored.name,
      'adminDecision': 'restored',
      'resolvedAt': FieldValue.serverTimestamp(),
      'adminId': adminId,
      'adminNote': note,
    });

    // Restore penalty
    await _firestore.collection('users').doc(existingCase.merchantId).update({
      'honorScore': FieldValue.increment(refund),
    });
  }

  Future<void> rejectContent(String contentId, {String? adminId, String? note}) async {
    final existingCase = state.cases[contentId];
    if (existingCase == null) return;

    await _firestore.collection('moderation_cases').doc(contentId).update({
      'status': ContentStatus.rejected.name,
      'adminDecision': 'rejected',
      'resolvedAt': FieldValue.serverTimestamp(),
      'adminId': adminId,
      'adminNote': note,
    });
  }

  Future<void> ignoreCase(String contentId, {String? adminId}) async {
    final existingCase = state.cases[contentId];
    if (existingCase == null) return;

    await _firestore.collection('moderation_cases').doc(contentId).update({
      'adminDecision': 'ignored',
      'resolvedAt': FieldValue.serverTimestamp(),
      'adminId': adminId,
    });
  }

  /// Set admin filter by tag
  void setFilter(ReportTag? tag) {
    state = state.copyWith(activeFilter: tag, clearFilter: tag == null);
  }

  ContentStatus getContentStatus(String contentId) {
    return state.cases[contentId]?.status ?? ContentStatus.active;
  }

  int getMerchantPenalty(String merchantId) {
    return state.merchantPenalties[merchantId] ?? 0;
  }

  String generateWarningMessage(String contentId) {
    final moderationCase = state.cases[contentId];
    if (moderationCase == null) return '';
    
    final penalty = moderationCase.hasCriticalThreshold ? criticalPenalty : honorPenalty;
    final criticalNote = moderationCase.hasCriticalThreshold 
        ? '\n\n🚨 **ALERTE CRITIQUE** : Votre contenu a été signalé pour ${moderationCase.primaryTag.label}, une catégorie à risque élevé.'
        : '';

    return '''
Bonjour ${moderationCase.merchantName},

Notre système de sécurité a détecté que votre récente publication (Réf : #$contentId) a fait l'objet de plusieurs signalements par la communauté Tontetic.$criticalNote

Conformément à la Charte de Modération Marchand que vous avez signée, nous vous informons que :

🔴 **Suspension Temporaire** : Votre publication "${moderationCase.contentTitle}" a été retirée du flux public.

📋 **Tag principal** : ${moderationCase.primaryTag.emoji} ${moderationCase.primaryTag.label}

⚠️ **Impact Score d'Honneur** : -$penalty points

**Que pouvez-vous faire ?**

• Répondez à ce message pour contester ou fournir des preuves.
• Consultez la charte avant de republier.

Cordialement,
L'équipe de Modération Tontetic
''';
  }
}

final moderationProvider = StateNotifierProvider<ModerationNotifier, ModerationState>((ref) {
  return ModerationNotifier();
});
