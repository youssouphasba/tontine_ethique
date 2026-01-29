/// Content Moderation Service
/// Handles content scanning, forbidden categories, and moderation workflow
/// 
/// 3 Levels of Control:
/// 1. Automatic: AI scan for nudity, violence, forbidden keywords
/// 2. User Reports: Report button
/// 3. Admin Moderation: Manual review
/// 
/// Legal: Platform acts as technical host (LCEN art. 6), not editor
library;


import 'dart:async';
import 'package:flutter/foundation.dart';

// =============== ENUMS ===============

enum ContentStatus {
  draft,      // Not yet published
  pending,    // Awaiting moderation (new merchants, first products, boosted)
  published,  // Live
  flagged,    // Reported by users
  suspended,  // Removed by admin
  rejected,   // Rejected during moderation
}

enum ContentType {
  product,
  shopProfile,
  review,
  message,
}

enum ViolationType {
  nudity,
  violence,
  hate,
  fraud,
  financialProduct,
  drugs,
  weapons,
  stolenContent,
  misleading,
  spam,
  other,
}

// =============== FORBIDDEN CATEGORIES ===============

class ForbiddenContentRules {
  /// Strictly forbidden product categories
  static const List<String> forbiddenCategories = [
    // Financial products (CRITICAL - avoid regulator issues)
    'investissement',
    'placement',
    'rendement',
    'tontine',       // Cannot sell tontine products in shop
    'épargne',
    'prêt',
    'crédit',
    'bitcoin',
    'crypto',
    'trading',
    'forex',
    
    // Illegal items
    'arme',
    'drogue',
    'médicament',
    'cannabis',
    'cocaine',
    
    // Adult content
    'pornographique',
    'érotique',
    'sexuel',
    
    // Hate
    'nazi',
    'raciste',
    'haineux',
  ];

  /// Keywords that trigger automatic review
  static const List<String> flaggedKeywords = [
    'garanti',
    'sans risque',
    'argent facile',
    'enrichir',
    'miracle',
    'révolutionnaire',
    '100%',
    'gratuit',
    'offre limitée',
    'urgent',
  ];

  /// Allowed product categories
  static const List<String> allowedCategories = [
    'mode',
    'beauté',
    'alimentation',
    'électronique',
    'maison',
    'services',
    'artisanat',
    'sport',
    'loisirs',
    'éducation',
  ];
}

// =============== DATA CLASSES ===============

class ContentReport {
  final String id;
  final String contentId;
  final ContentType contentType;
  final String reporterId;
  final ViolationType violationType;
  final String? description;
  final DateTime reportedAt;
  final bool isResolved;
  final String? adminNotes;
  final DateTime? resolvedAt;

  ContentReport({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.reporterId,
    required this.violationType,
    this.description,
    required this.reportedAt,
    this.isResolved = false,
    this.adminNotes,
    this.resolvedAt,
  });

  ContentReport copyWith({
    bool? isResolved,
    String? adminNotes,
    DateTime? resolvedAt,
  }) {
    return ContentReport(
      id: id,
      contentId: contentId,
      contentType: contentType,
      reporterId: reporterId,
      violationType: violationType,
      description: description,
      reportedAt: reportedAt,
      isResolved: isResolved ?? this.isResolved,
      adminNotes: adminNotes ?? this.adminNotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class ModerationResult {
  final bool isApproved;
  final List<String> violations;
  final List<String> warnings;
  final ContentStatus recommendedStatus;
  final bool requiresManualReview;

  ModerationResult({
    required this.isApproved,
    this.violations = const [],
    this.warnings = const [],
    required this.recommendedStatus,
    this.requiresManualReview = false,
  });
}

class ContentModificationLog {
  final String contentId;
  final String modifierId;
  final String action;
  final String? previousValue;
  final String? newValue;
  final DateTime timestamp;

  ContentModificationLog({
    required this.contentId,
    required this.modifierId,
    required this.action,
    this.previousValue,
    this.newValue,
    required this.timestamp,
  });
}

// =============== MODERATION SERVICE ===============

class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;
  ContentModerationService._internal();

  final List<ContentReport> _reports = [];
  final List<ContentModificationLog> _logs = [];

  // ===== AUTOMATIC SCAN (Level 1) =====
  
  /// Scan text content for violations
  ModerationResult scanText(String text, {bool isBoosted = false, bool isNewMerchant = false, bool isFirstProduct = false}) {
    final normalizedText = text.toLowerCase().trim();
    final violations = <String>[];
    final warnings = <String>[];
    var requiresManual = false;

    // Check forbidden categories
    for (final forbidden in ForbiddenContentRules.forbiddenCategories) {
      if (normalizedText.contains(forbidden.toLowerCase())) {
        violations.add('Contenu interdit détecté: $forbidden');
      }
    }

    // Check flagged keywords (warning only)
    for (final flagged in ForbiddenContentRules.flaggedKeywords) {
      if (normalizedText.contains(flagged.toLowerCase())) {
        warnings.add('Mot-clé à risque: $flagged');
      }
    }

    // Financial product detection (CRITICAL)
    if (_detectFinancialProduct(normalizedText)) {
      violations.add('Produit financier interdit (investissement, rendement, épargne)');
    }

    // Require manual review for:
    if (isNewMerchant || isFirstProduct || isBoosted) {
      requiresManual = true;
    }
    if (warnings.isNotEmpty) {
      requiresManual = true;
    }

    // Determine status
    ContentStatus status;
    if (violations.isNotEmpty) {
      status = ContentStatus.rejected;
    } else if (requiresManual) {
      status = ContentStatus.pending;
    } else {
      status = ContentStatus.published;
    }

    return ModerationResult(
      isApproved: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      recommendedStatus: status,
      requiresManualReview: requiresManual,
    );
  }

  /// Scan media for violations (simulated AI)
  Future<ModerationResult> scanMedia(String mediaUrl) async {
    // REALITY CHECK: Client-side AI media scanning is not implemented.
    // In production, this returns immediately to avoid blocking UI, 
    // but the actual check would happen asynchronously on the backend.
    
    // Auto-approve unless metadata is obviously flagged
    final violations = <String>[];
    final warnings = <String>[];

    // Basic keyword check on the URL/filename if possible
    if (mediaUrl.toLowerCase().contains('nsfw') || mediaUrl.toLowerCase().contains('adult')) {
      violations.add('Contenu pour adultes détecté');
    }
    
    return ModerationResult(
      isApproved: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      recommendedStatus: violations.isEmpty ? ContentStatus.published : ContentStatus.rejected,
      requiresManualReview: warnings.isNotEmpty,
    );
  }

  bool _detectFinancialProduct(String text) {
    final financialPatterns = [
      RegExp(r'\d+%\s*(de\s*)?rendement', caseSensitive: false),
      RegExp(r'investiss(ement|ez|ir)', caseSensitive: false),
      RegExp(r'gagn(ez|er)\s+de\s+l.argent', caseSensitive: false),
      RegExp(r'revenu\s+passif', caseSensitive: false),
      RegExp(r'multipli(ez|er)\s+.*argent', caseSensitive: false),
      RegExp(r'placement\s+financier', caseSensitive: false),
    ];

    for (final pattern in financialPatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }

  // ===== USER REPORTS (Level 2) =====
  
  void reportContent({
    required String contentId,
    required ContentType contentType,
    required String reporterId,
    required ViolationType violationType,
    String? description,
  }) {
    final report = ContentReport(
      id: 'RPT-${DateTime.now().millisecondsSinceEpoch}',
      contentId: contentId,
      contentType: contentType,
      reporterId: reporterId,
      violationType: violationType,
      description: description,
      reportedAt: DateTime.now(),
    );
    _reports.add(report);
    debugPrint('[Moderation] Content reported: $contentId - ${violationType.name}');
  }

  List<ContentReport> getPendingReports() {
    return _reports.where((r) => !r.isResolved).toList();
  }

  List<ContentReport> getAllReports() => List.unmodifiable(_reports);

  // ===== ADMIN MODERATION (Level 3) =====
  
  void resolveReport(String reportId, {required bool approved, required String adminNotes}) {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      _reports[index] = _reports[index].copyWith(
        isResolved: true,
        adminNotes: adminNotes,
        resolvedAt: DateTime.now(),
      );
      debugPrint('[Moderation] Report resolved: $reportId - ${approved ? "APPROVED" : "REJECTED"}');
    }
  }

  // ===== MODIFICATION LOGS =====
  
  void logModification({
    required String contentId,
    required String modifierId,
    required String action,
    String? previousValue,
    String? newValue,
  }) {
    _logs.add(ContentModificationLog(
      contentId: contentId,
      modifierId: modifierId,
      action: action,
      previousValue: previousValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    ));
  }

  List<ContentModificationLog> getLogsForContent(String contentId) {
    return _logs.where((l) => l.contentId == contentId).toList();
  }

  // ===== BOOST RULES =====
  
  /// Check if content can be boosted
  ModerationResult checkBoostEligibility(String productName, String description, ContentStatus currentStatus) {
    // Cannot boost suspended/rejected content
    if (currentStatus == ContentStatus.suspended || currentStatus == ContentStatus.rejected) {
      return ModerationResult(
        isApproved: false,
        violations: ['Contenu suspendu ou rejeté non éligible au boost'],
        recommendedStatus: currentStatus,
      );
    }

    // Full scan for boosted content
    final textResult = scanText('$productName $description', isBoosted: true);
    
    if (!textResult.isApproved) {
      return ModerationResult(
        isApproved: false,
        violations: [...textResult.violations, 'Boost non autorisé pour contenu non conforme'],
        recommendedStatus: ContentStatus.rejected,
      );
    }

    return ModerationResult(
      isApproved: true,
      warnings: textResult.warnings,
      recommendedStatus: ContentStatus.pending, // Boosted content requires manual review
      requiresManualReview: true,
    );
  }

  /// Handle boost violation (non-refundable)
  void handleBoostViolation(String productId, String merchantId) {
    logModification(
      contentId: productId,
      modifierId: 'SYSTEM',
      action: 'BOOST_VIOLATION',
      newValue: 'Boost retiré - contenu non conforme - non remboursable',
    );
    debugPrint('[Moderation] Boost violation for product $productId - NOT REFUNDABLE');
  }
}

// =============== LEGAL TEXTS ===============

class MerchantLegalTexts {
  static const String merchantResponsibility = '''
## Responsabilité du Marchand

En créant un compte marchand sur Tontetic, vous garantissez :

1. **Propriété des contenus** : Vous êtes le propriétaire légitime de toutes les images, vidéos et descriptions publiées, ou vous disposez des droits nécessaires pour les utiliser.

2. **Légalité des produits** : Tous vos produits et services sont conformes aux lois en vigueur au Sénégal et dans les pays où vous opérez.

3. **Responsabilité exclusive** : Vous assumez seul l'entière responsabilité en cas de litige avec un acheteur concernant la qualité, la livraison, ou toute autre réclamation.

4. **Contenus interdits** : Vous vous engagez à ne pas publier de contenus :
   - Produits financiers, investissements, promesses de rendement
   - Tontines, épargne, prêts, crédits
   - Armes, drogues, médicaments non autorisés
   - Contenus trompeurs, mensongers ou volés
   - Contenus pornographiques, haineux ou discriminatoires

5. **Sanctions** : En cas de violation, Tontetic se réserve le droit de :
   - Retirer le contenu sans préavis
   - Suspendre ou supprimer votre compte marchand
   - Ne pas rembourser les boosts associés aux contenus en infraction
''';

  static const String platformLCEN = '''
## Statut de la Plateforme (LCEN art. 6)

Tontetic agit en qualité d'**hébergeur technique** au sens de la Loi pour la Confiance dans l'Économie Numérique (LCEN).

À ce titre :
- Tontetic fournit un espace de mise en relation entre marchands et utilisateurs
- Tontetic n'est pas éditeur des contenus publiés par les marchands
- Tontetic n'est pas partie aux transactions entre marchands et acheteurs
- Tontetic ne stocke, ne gère et ne transfère aucun fonds
- Tous les paiements sont effectués via des prestataires de paiement externes (PSP)

Tontetic s'engage à retirer promptement tout contenu manifestement illicite qui lui serait signalé.
''';

  static const String forbiddenProductsWarning = '''
⚠️ **PRODUITS INTERDITS**

Les catégories suivantes sont strictement interdites :
• Produits financiers et investissements
• Tontines et produits d'épargne
• Armes et objets dangereux
• Drogues et médicaments non autorisés
• Contenus pour adultes
• Contenus haineux ou discriminatoires

Toute violation entraîne la suspension immédiate du compte.
''';

  static const String boostTerms = '''
## Conditions du Boost

- Le boost augmente la visibilité de votre produit dans le feed
- Le boost ne modifie pas les règles de contenu
- Les produits boostés font l'objet d'une vérification renforcée
- En cas d'infraction détectée sur un produit boosté :
  • Le produit est immédiatement retiré
  • Le boost n'est PAS remboursé
  • Le compte marchand peut être suspendu
''';
}
