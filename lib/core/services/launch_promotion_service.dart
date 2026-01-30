/// V17: Launch Promotion Service - Modèle Créateurs + Invitations
/// Offre de Lancement Exclusive Tontetic
/// - MIGRATED TO FIRESTORE
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum LaunchPromoStatus {
  available,      // Places disponibles
  claimed,        // Offre réclamée
  active,         // 3 mois gratuits en cours
  expired,        // 3 mois écoulés → payant (3,99€/mois)
  locked,         // Tontine démarrée → verrouillé
  cancelled,      // Annulé (avant démarrage tontine uniquement)
}

enum PromoType {
  creator,        // Créateur (1 des 20 premiers)
  invited,        // Invité par un créateur (max 9 par créateur)
}

class LaunchPromoUser {
  final String id;
  final String oderId;
  final PromoType type;
  final String? invitedBy; // ID du créateur si type = invited
  final DateTime claimedAt;
  final DateTime expiresAt; // +3 mois
  final LaunchPromoStatus status;
  final bool tontineStarted; // Si une tontine a démarré
  final int invitesSent; // Nb invitations envoyées (max 9)

  LaunchPromoUser({
    required this.id,
    required this.oderId,
    required this.type,
    this.invitedBy,
    required this.claimedAt,
    required this.expiresAt,
    required this.status,
    this.tontineStarted = false,
    this.invitesSent = 0,
  });

  bool get canCancel => !tontineStarted && status != LaunchPromoStatus.locked;
  bool get isPromoActive => status == LaunchPromoStatus.active && DateTime.now().isBefore(expiresAt);
  int get remainingInvites => type == PromoType.creator ? (9 - invitesSent) : 0;
  
  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': oderId,
    'type': type.name,
    'invited_by': invitedBy,
    'claimed_at': claimedAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'status': status.name,
    'tontine_started': tontineStarted,
    'invites_sent': invitesSent,
  };

  factory LaunchPromoUser.fromJson(Map<String, dynamic> json) => LaunchPromoUser(
    id: json['id'],
    oderId: json['user_id'],
    type: PromoType.values.byName(json['type']),
    invitedBy: json['invited_by'],
    claimedAt: DateTime.parse(json['claimed_at']),
    expiresAt: DateTime.parse(json['expires_at']),
    status: LaunchPromoStatus.values.byName(json['status']),
    tontineStarted: json['tontine_started'] ?? false,
    invitesSent: json['invites_sent'] ?? 0,
  );

  LaunchPromoUser copyWith({
    LaunchPromoStatus? status,
    bool? tontineStarted,
    int? invitesSent,
  }) => LaunchPromoUser(
    id: id,
    oderId: oderId,
    type: type,
    invitedBy: invitedBy,
    claimedAt: claimedAt,
    expiresAt: expiresAt,
    status: status ?? this.status,
    tontineStarted: tontineStarted ?? this.tontineStarted,
    invitesSent: invitesSent ?? this.invitesSent,
  );
}

class LaunchPromotionService {
  final FirebaseFirestore _firestore;
  
  // ============ CONFIGURATION OFFRE ============
  // 20 créateurs × (1 + 9 invités) = 200 utilisateurs max
  static const int maxCreators = 20;          // 20 premiers créateurs
  static const int maxInvitesPerCreator = 9;  // 9 invités par créateur
  static const int freeMonths = 3;            // 3 mois gratuits
  static const String promoTier = 'STARTER';
  static const double priceAfterEuro = 3.99;  // Prix Starter après 3 mois
  static const int priceAfterFcfa = 2500;     // Prix Starter en FCFA

  LaunchPromotionService() : _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => 
      _firestore.collection('launch_promotions');

  // ============ VÉRIFICATIONS ============

  /// Vérifie si l'offre créateur est encore disponible
  Future<bool> isCreatorPromoAvailable() async {
    final count = await _getCreatorCount();
    return count < maxCreators;
  }

  /// Nombre de places créateur restantes (sur 20)
  Future<int> getRemainingCreatorSlots() async {
    final count = await _getCreatorCount();
    return maxCreators - count;
  }

  /// Vérifie si un utilisateur a déjà réclamé l'offre
  Future<LaunchPromoUser?> getUserPromo(String oderId) async {
    final snapshot = await _collection
        .where('user_id', isEqualTo: oderId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return LaunchPromoUser.fromJson(snapshot.docs.first.data());
  }

  /// Vérifie si un utilisateur peut annuler son abonnement
  Future<CancelResult> canCancelSubscription(String oderId) async {
    final promo = await getUserPromo(oderId);
    
    if (promo == null) {
      // Pas dans l'offre de lancement → règles normales
      return CancelResult(canCancel: true, reason: null);
    }

    if (promo.tontineStarted || promo.status == LaunchPromoStatus.locked) {
      return CancelResult(
        canCancel: false,
        reason: 'Impossible d\'annuler : une tontine est en cours. '
                'Conformément aux conditions de l\'offre de lancement, '
                'l\'abonnement reste actif jusqu\'à la fin de toutes vos tontines.',
      );
    }

    return CancelResult(canCancel: true, reason: null);
  }

  // ============ RÉCLAMATION OFFRE ============

  /// Réclamer l'offre créateur (1 des 20 premiers)
  Future<ClaimResult> claimCreatorPromo(String userId) async {
    // Vérifier disponibilité
    if (!await isCreatorPromoAvailable()) {
      return ClaimResult(
        success: false,
        message: 'Désolé, les $maxCreators places créateur sont déjà prises.',
      );
    }

    // Vérifier si déjà réclamé
    final existing = await getUserPromo(userId);
    if (existing != null) {
      return ClaimResult(
        success: false,
        message: 'Vous avez déjà bénéficié de l\'offre de lancement.',
      );
    }

    // Créer l'entrée
    final now = DateTime.now();
    final promo = LaunchPromoUser(
      id: 'promo_${now.millisecondsSinceEpoch}',
      oderId: userId,
      type: PromoType.creator,
      claimedAt: now,
      expiresAt: now.add(Duration(days: freeMonths * 30)),
      status: LaunchPromoStatus.active,
    );

    await _collection.doc(promo.id).set(promo.toJson());

    debugPrint('[PROMO] Creator slot claimed by $userId');

    return ClaimResult(
      success: true,
      message: 'Félicitations ! Vous faites partie des $maxCreators premiers créateurs. '
               'Profitez de $freeMonths mois d\'abonnement Starter GRATUIT ! '
               'Invitez jusqu\'à $maxInvitesPerCreator personnes pour leur offrir la même offre.',
      promo: promo,
    );
  }

  /// Inviter quelqu'un (créateur uniquement, max 9)
  Future<InviteResult> inviteUser({
    required String creatorId,
    required String inviteeId,
  }) async {
    // Vérifier que le créateur a l'offre
    final creatorPromo = await getUserPromo(creatorId);
    if (creatorPromo == null || creatorPromo.type != PromoType.creator) {
      return InviteResult(
        success: false,
        message: 'Seuls les créateurs de l\'offre peuvent inviter.',
      );
    }

    // Vérifier le quota d'invitations
    if (creatorPromo.invitesSent >= maxInvitesPerCreator) {
      return InviteResult(
        success: false,
        message: 'Vous avez atteint votre limite de $maxInvitesPerCreator invitations.',
      );
    }

    // Vérifier que l'invité n'a pas déjà l'offre
    final existingInvitee = await getUserPromo(inviteeId);
    if (existingInvitee != null) {
      return InviteResult(
        success: false,
        message: 'Cette personne bénéficie déjà de l\'offre de lancement.',
      );
    }

    // Créer l'entrée pour l'invité
    final now = DateTime.now();
    final inviteePromo = LaunchPromoUser(
      id: 'promo_inv_${now.millisecondsSinceEpoch}',
      oderId: inviteeId,
      type: PromoType.invited,
      invitedBy: creatorId,
      claimedAt: now,
      expiresAt: now.add(Duration(days: freeMonths * 30)),
      status: LaunchPromoStatus.active,
    );

    // Transaction pour l'atomicité
    await _firestore.runTransaction((transaction) async {
        transaction.set(_collection.doc(inviteePromo.id), inviteePromo.toJson());
        
        // Update creator invites sent. IMPORTANT: Need doc reference, assuming generic query logic
        // For simplicity using update directly here without transaction context if we don't have docRef handy
        // But better is to get docRef first.
        final creatorDocRef = _collection.doc(creatorPromo.id);
        transaction.update(creatorDocRef, {
            'invites_sent': creatorPromo.invitesSent + 1,
        });
    });

    debugPrint('[PROMO] $creatorId invited $inviteeId (${creatorPromo.invitesSent + 1}/$maxInvitesPerCreator)');

    return InviteResult(
      success: true,
      message: 'Invitation envoyée ! Votre ami bénéficiera de $freeMonths mois Starter gratuits.',
      remainingInvites: maxInvitesPerCreator - creatorPromo.invitesSent - 1,
    );
  }

  // ============ VERROUILLAGE ============

  /// Verrouiller l'abonnement quand une tontine démarre
  /// APPELER CETTE MÉTHODE QUAND UNE TONTINE PASSE EN STATUT "ACTIVE"
  Future<void> lockSubscriptionOnTontineStart(String userId) async {
    final snapshot = await _collection.where('user_id', isEqualTo: userId).limit(1).get();
    if (snapshot.docs.isEmpty) return;

    await snapshot.docs.first.reference.update({
      'tontine_started': true,
      'status': LaunchPromoStatus.locked.name,
    });

    debugPrint('[PROMO] Subscription LOCKED for $userId - Tontine started');
  }

  // ============ EXPIRATION ============

  /// Vérifier et mettre à jour les promos expirées (appeler via CRON)
  /// Après 3 mois: bascule automatique sur Starter payant (3,99€/mois)
  Future<void> checkExpirations() async {
    final now = DateTime.now();
    
    final snapshot = await _collection
        .where('status', isEqualTo: LaunchPromoStatus.active.name)
        .where('expires_at', isLessThan: now.toIso8601String())
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({
        'status': LaunchPromoStatus.expired.name,
      });
      debugPrint('[PROMO] Promo expired for ${doc.data()['user_id']} - Now $priceAfterEuro€/mois');
    }
  }

  // ============ HELPERS PRIVÉS ============

  Future<int> _getCreatorCount() async {
    final snapshot = await _collection.where('type', isEqualTo: PromoType.creator.name).count().get();
    return snapshot.count ?? 0;
  }

  /// Recherche un créateur par le début de son ID (pour les codes d'invitation)
  Future<String?> findCreatorByIdPrefix(String prefix) async {
    // Firestore range query for prefix
    final snapshot = await _collection
        .where('type', isEqualTo: PromoType.creator.name)
        .where('user_id', isGreaterThanOrEqualTo: prefix)
        .where('user_id', isLessThan: '$prefix\uf8ff')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data()['user_id'] as String?;
  }

  // ============ STATS ADMIN ============

  Future<PromoStats> getStats() async {
    final snapshot = await _collection.get();
    final list = snapshot.docs.map((d) => d.data()).toList();

    final creators = list.where((p) => p['type'] == PromoType.creator.name).length;
    final invited = list.where((p) => p['type'] == PromoType.invited.name).length;
    final locked = list.where((p) => p['status'] == LaunchPromoStatus.locked.name).length;
    final expired = list.where((p) => p['status'] == LaunchPromoStatus.expired.name).length;

    return PromoStats(
      creatorsUsed: creators,
      creatorsRemaining: maxCreators - creators,
      totalInvited: invited,
      totalLocked: locked,
      totalExpired: expired,
      totalActive: list.length - locked - expired,
    );
  }
}

// ============ RESULT CLASSES ============

class CancelResult {
  final bool canCancel;
  final String? reason;

  CancelResult({required this.canCancel, this.reason});
}

class ClaimResult {
  final bool success;
  final String message;
  final LaunchPromoUser? promo;

  ClaimResult({required this.success, required this.message, this.promo});
}

class InviteResult {
  final bool success;
  final String message;
  final int? remainingInvites;

  InviteResult({required this.success, required this.message, this.remainingInvites});
}

class PromoStats {
  final int creatorsUsed;
  final int creatorsRemaining;
  final int totalInvited;
  final int totalLocked;
  final int totalExpired;
  final int totalActive;

  PromoStats({
    required this.creatorsUsed,
    required this.creatorsRemaining,
    required this.totalInvited,
    required this.totalLocked,
    required this.totalExpired,
    required this.totalActive,
  });

  int get totalUsers => creatorsUsed + totalInvited;
  int get maxPossibleUsers => LaunchPromotionService.maxCreators * 
                              (1 + LaunchPromotionService.maxInvitesPerCreator); // 20 × 10 = 200
}

// ============ PROVIDER ============

final launchPromotionServiceProvider = Provider<LaunchPromotionService>((ref) {
  return LaunchPromotionService();
});
