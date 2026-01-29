import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/services/launch_promotion_service.dart';

/// Hook d'intégration pour l'offre de lancement
/// À appeler aux moments clés du parcours utilisateur

class LaunchPromoIntegration {
  final Ref _ref;

  LaunchPromoIntegration(this._ref);

  LaunchPromotionService get _promoService => _ref.read(launchPromotionServiceProvider);

  /// À appeler lors de la CRÉATION d'une tontine
  /// Retourne true si l'utilisateur a obtenu l'offre créateur
  Future<PromoClaimResult> onTontineCreated({
    required String userId,
    required String tontineId,
  }) async {
    // Vérifier si l'offre créateur est disponible
    if (!await _promoService.isCreatorPromoAvailable()) {
      return PromoClaimResult(
        claimed: false,
        message: null,
      );
    }

    // Vérifier si déjà bénéficiaire
    final existing = await _promoService.getUserPromo(userId);
    if (existing != null) {
      return PromoClaimResult(
        claimed: false,
        message: null,
      );
    }

    // Réclamer l'offre
    final result = await _promoService.claimCreatorPromo(userId);
    
    if (result.success) {
      debugPrint('[PROMO-HOOK] Tontine $tontineId: User $userId claimed creator promo');
    }

    return PromoClaimResult(
      claimed: result.success,
      message: result.success ? result.message : null,
    );
  }

  /// À appeler lors du DÉMARRAGE d'une tontine (status = active)
  /// Verrouille les abonnements de tous les participants
  Future<void> onTontineStarted({
    required String tontineId,
    required String creatorId,
    required List<String> memberIds,
  }) async {
    debugPrint('[PROMO-HOOK] Tontine $tontineId started - Locking subscriptions');

    // Verrouiller le créateur
    await _promoService.lockSubscriptionOnTontineStart(creatorId);

    // Verrouiller tous les membres
    for (final memberId in memberIds) {
      await _promoService.lockSubscriptionOnTontineStart(memberId);
    }

    debugPrint('[PROMO-HOOK] Locked ${memberIds.length + 1} subscriptions');
  }

  /// À appeler lors de la tentative d'ANNULATION d'abonnement
  /// Retourne null si annulation autorisée, sinon le message de blocage
  Future<String?> onCancelAttempt({required String userId}) async {
    final result = await _promoService.canCancelSubscription(userId);
    return result.canCancel ? null : result.reason;
  }

  /// À appeler lors de l'inscription avec un CODE D'INVITATION
  Future<InviteJoinResult> onJoinWithInviteCode({
    required String inviteeId,
    required String inviteCode,
  }) async {
    // Extraire l'ID du créateur depuis le code
    // Format: TONTETIC_XXXXXX où XXXXXX = userId.substring(0,6)
    if (!inviteCode.startsWith('TONTETIC_')) {
      return InviteJoinResult(
        success: false,
        message: 'Code d\'invitation invalide.',
      );
    }

    final creatorIdPrefix = inviteCode.replaceFirst('TONTETIC_', '').toLowerCase();
    
    // Trouver le créateur correspondant
    // Note: En production, faire une recherche Supabase
    // Ici on simule avec un lookup
    final creatorId = await _findCreatorByPrefix(creatorIdPrefix);
    
    if (creatorId == null) {
      return InviteJoinResult(
        success: false,
        message: 'Code d\'invitation expiré ou invalide.',
      );
    }

    // Enregistrer l'invitation
    final result = await _promoService.inviteUser(
      creatorId: creatorId,
      inviteeId: inviteeId,
    );

    return InviteJoinResult(
      success: result.success,
      message: result.message,
      remainingInvites: result.remainingInvites,
    );
  }

  /// Recherche le créateur par préfixe d'ID
  Future<String?> _findCreatorByPrefix(String prefix) async {
    // TODO: Implémenter la recherche Supabase
    // SELECT user_id FROM launch_promotions 
    // WHERE type = 'creator' AND LOWER(user_id) LIKE 'prefix%'
    return null; // Placeholder
  }

  /// Vérifier le statut promo pour affichage UI
  Future<PromoDisplayInfo> getPromoDisplayInfo(String userId) async {
    final promo = await _promoService.getUserPromo(userId);
    final slotsRemaining = await _promoService.getRemainingCreatorSlots();

    if (promo == null) {
      return PromoDisplayInfo(
        hasPromo: false,
        isCreator: false,
        canGetCreatorPromo: slotsRemaining > 0,
        slotsRemaining: slotsRemaining,
        daysRemaining: 0,
        invitesRemaining: 0,
        showBanner: slotsRemaining > 0,
        showInviteWidget: false,
      );
    }

    return PromoDisplayInfo(
      hasPromo: true,
      isCreator: promo.type == PromoType.creator,
      canGetCreatorPromo: false,
      slotsRemaining: slotsRemaining,
      daysRemaining: promo.daysRemaining,
      invitesRemaining: promo.remainingInvites,
      showBanner: false,
      showInviteWidget: promo.type == PromoType.creator && promo.remainingInvites > 0,
      isLocked: promo.status == LaunchPromoStatus.locked,
    );
  }
}

// ============ RESULT CLASSES ============

class PromoClaimResult {
  final bool claimed;
  final String? message;

  PromoClaimResult({required this.claimed, this.message});
}

class InviteJoinResult {
  final bool success;
  final String message;
  final int? remainingInvites;

  InviteJoinResult({
    required this.success,
    required this.message,
    this.remainingInvites,
  });
}

class PromoDisplayInfo {
  final bool hasPromo;
  final bool isCreator;
  final bool canGetCreatorPromo;
  final int slotsRemaining;
  final int daysRemaining;
  final int invitesRemaining;
  final bool showBanner;
  final bool showInviteWidget;
  final bool isLocked;

  PromoDisplayInfo({
    required this.hasPromo,
    required this.isCreator,
    required this.canGetCreatorPromo,
    required this.slotsRemaining,
    required this.daysRemaining,
    required this.invitesRemaining,
    required this.showBanner,
    required this.showInviteWidget,
    this.isLocked = false,
  });
}

// ============ PROVIDER ============

final launchPromoIntegrationProvider = Provider<LaunchPromoIntegration>((ref) {
  return LaunchPromoIntegration(ref);
});
