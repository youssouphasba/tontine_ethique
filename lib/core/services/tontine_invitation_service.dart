/// V17: Service de gestion des invitations à rejoindre une tontine
/// 
/// RÈGLES GÉNÉRALES:
/// 1. Tous les membres d'un cercle peuvent envoyer des invitations
/// 2. Les invitations sont soumises à la validation du CRÉATEUR de la tontine
/// 3. Le créateur peut accepter ou refuser les invitations
/// 4. L'invité reçoit une notification quand son invitation est validée
/// - MIGRATED TO FIRESTORE
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/services/notification_service.dart';

enum TontineInvitationStatus {
  pending,    // En attente de validation par le créateur
  approved,   // Approuvée par le créateur
  rejected,   // Refusée par le créateur
  expired,    // Expirée (pas de réponse dans le délai)
  cancelled,  // Annulée par l'inviteur
}

class TontineInvitation {
  final String id;
  final String tontineId;
  final String tontineName;
  final String inviterId;        // Qui a envoyé l'invitation
  final String inviterName;
  final String inviteePhone;     // Numéro de téléphone de l'invité
  final String? inviteeId;       // ID si déjà inscrit
  final String? inviteeName;
  final TontineInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? creatorNote;     // Note du créateur si refusé
  final String type;             // 'join' or 'replacement'
  final String? replacementForId; // ID of the member being replaced

  TontineInvitation({
    required this.id,
    required this.tontineId,
    required this.tontineName,
    required this.inviterId,
    required this.inviterName,
    required this.inviteePhone,
    this.inviteeId,
    this.inviteeName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.creatorNote,
    this.type = 'join',
    this.replacementForId,
  });

  bool get isPending => status == TontineInvitationStatus.pending;
  bool get isApproved => status == TontineInvitationStatus.approved;
  bool get isExpired => DateTime.now().isAfter(expiresAt) && isPending;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tontine_id': tontineId,
    'tontine_name': tontineName,
    'inviter_id': inviterId,
    'inviter_name': inviterName,
    'invitee_phone': inviteePhone,
    'invitee_id': inviteeId,
    'invitee_name': inviteeName,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'creator_note': creatorNote,
    'type': type,
    'replacement_for_id': replacementForId,
  };

  factory TontineInvitation.fromJson(Map<String, dynamic> json) => TontineInvitation(
    id: json['id'],
    tontineId: json['tontine_id'],
    tontineName: json['tontine_name'] ?? 'Tontine',
    inviterId: json['inviter_id'],
    inviterName: json['inviter_name'] ?? 'Membre',
    inviteePhone: json['invitee_phone'],
    inviteeId: json['invitee_id'],
    inviteeName: json['invitee_name'],
    status: TontineInvitationStatus.values.byName(json['status']),
    createdAt: DateTime.parse(json['created_at']),
    expiresAt: DateTime.parse(json['expires_at']),
    creatorNote: json['creator_note'],
    type: json['type'] ?? 'join',
    replacementForId: json['replacement_for_id'],
  );
}

class TontineInvitationService {
  final FirebaseFirestore _firestore;

  // Durée de validité d'une invitation (7 jours)
  static const int invitationExpiryDays = 7;

  TontineInvitationService() : _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => 
      _firestore.collection('tontine_invitations');

  // ============ ENVOI D'INVITATION (TOUT MEMBRE) ============

  /// Envoyer une invitation à rejoindre une tontine
  /// Tous les membres peuvent inviter, mais le créateur doit valider
  Future<InvitationResult> sendInvitation({
    required String tontineId,
    required String tontineName,
    required String inviterId,
    required String inviterName,
    required String inviteePhone,
    String? inviteeName,
  }) async {
    try {
      // Vérifier si une invitation existe déjà pour ce numéro
      final existingSnapshot = await _collection
          .where('tontine_id', isEqualTo: tontineId)
          .where('invitee_phone', isEqualTo: inviteePhone)
          .where('status', whereIn: ['pending', 'approved'])
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        return InvitationResult(
          success: false,
          message: 'Une invitation est déjà en cours pour ce numéro.',
        );
      }

      // Créer l'invitation
      final now = DateTime.now();
      final invitation = TontineInvitation(
        id: 'inv_${now.millisecondsSinceEpoch}',
        tontineId: tontineId,
        tontineName: tontineName,
        inviterId: inviterId,
        inviterName: inviterName,
        inviteePhone: inviteePhone,
        inviteeName: inviteeName,
        status: TontineInvitationStatus.pending,
        createdAt: now,
        expiresAt: now.add(Duration(days: invitationExpiryDays)),
        type: 'join',
      );

      await _collection.doc(invitation.id).set(invitation.toJson());

      debugPrint('[INVITATION] $inviterName invited $inviteePhone to $tontineName (pending validation)');

      return InvitationResult(
        success: true,
        message: 'Invitation envoyée ! Elle sera soumise à la validation du créateur de la tontine.',
        invitation: invitation,
      );
    } catch (e) {
      debugPrint('[INVITATION] Error: $e');
      return InvitationResult(
        success: false,
        message: 'Erreur lors de l\'envoi de l\'invitation.',
      );
    }
  }

  /// Envoyer une invitation de REMPLACEMENT
  Future<InvitationResult> sendReplacementInvitation({
    required String tontineId,
    required String tontineName,
    required String inviterId,
    required String inviterName,
    required String inviteePhone,
    String? inviteeId, // Optional if known (mutual follower)
    String? inviteeName,
  }) async {
    try {
      final now = DateTime.now();
      final invitation = TontineInvitation(
        id: 'rep_${now.millisecondsSinceEpoch}',
        tontineId: tontineId,
        tontineName: tontineName,
        inviterId: inviterId,
        inviterName: inviterName,
        inviteePhone: inviteePhone,
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        status: TontineInvitationStatus.pending, // Needs creator approval? Usually yes for replacement
        createdAt: now,
        expiresAt: now.add(Duration(days: invitationExpiryDays)),
        type: 'replacement',
        replacementForId: inviterId,
      );

      await _collection.doc(invitation.id).set(invitation.toJson());
      
      // Also potentially notify the CREATOR here if we had a NotificationService handy

      return InvitationResult(
        success: true,
        message: 'Invitation de remplacement envoyée !',
        invitation: invitation,
      );
    } catch (e) {
       return InvitationResult(success: false, message: 'Erreur technique: $e');
    }
  }

  // ============ VALIDATION PAR LE CRÉATEUR ============

  /// Récupérer les invitations en attente pour une tontine (créateur uniquement)
  Future<List<TontineInvitation>> getPendingInvitations(String tontineId) async {
    final snapshot = await _collection
        .where('tontine_id', isEqualTo: tontineId)
        .where('status', isEqualTo: TontineInvitationStatus.pending.name)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TontineInvitation.fromJson(doc.data()))
        .toList();
  }

  /// Approuver une invitation (créateur uniquement)
  Future<ValidationResult> approveInvitation({
    required String invitationId,
    required String creatorId,
    required String tontineCreatorId,
  }) async {
    // Vérifier que c'est bien le créateur
    if (creatorId != tontineCreatorId) {
      return ValidationResult(
        success: false,
        message: 'Seul le créateur de la tontine peut valider les invitations.',
      );
    }

    await _collection.doc(invitationId).update({
      'status': TontineInvitationStatus.approved.name,
    });

    debugPrint('[INVITATION] Invitation $invitationId approved');

    return ValidationResult(
      success: true,
      message: 'Invitation approuvée ! L\'invité recevra une notification.',
    );
  }

  /// Refuser une invitation (créateur uniquement)
  Future<ValidationResult> rejectInvitation({
    required String invitationId,
    required String creatorId,
    required String tontineCreatorId,
    String? reason,
  }) async {
    // Vérifier que c'est bien le créateur
    if (creatorId != tontineCreatorId) {
      return ValidationResult(
        success: false,
        message: 'Seul le créateur de la tontine peut refuser les invitations.',
      );
    }

    await _collection.doc(invitationId).update({
      'status': TontineInvitationStatus.rejected.name,
      'creator_note': reason,
    });

    debugPrint('[INVITATION] Invitation $invitationId rejected: $reason');

    return ValidationResult(
      success: true,
      message: 'Invitation refusée.',
    );
  }

  // ============ POUR L'INVITÉ ============

  /// Récupérer les invitations reçues par un utilisateur
  Future<List<TontineInvitation>> getReceivedInvitations(String userPhone) async {
    final snapshot = await _collection
        .where('invitee_phone', isEqualTo: userPhone)
        .where('status', isEqualTo: TontineInvitationStatus.approved.name)
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TontineInvitation.fromJson(doc.data()))
        .toList();
  }

  // ============ NETTOYAGE ============

  /// Marquer les invitations expirées (appeler via CRON)
  Future<void> expireOldInvitations() async {
    final now = DateTime.now();
    
    final snapshot = await _collection
        .where('status', isEqualTo: TontineInvitationStatus.pending.name)
        .where('expires_at', isLessThan: now.toIso8601String())
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({'status': TontineInvitationStatus.expired.name});
    }

    debugPrint('[INVITATION] Expired ${snapshot.docs.length} old pending invitations');
  }

  // ============ STATS ============

  Future<InvitationStats> getStats(String tontineId) async {
    final snapshot = await _collection
        .where('tontine_id', isEqualTo: tontineId)
        .get();

    final list = snapshot.docs.map((d) => d.data()).toList();
    
    return InvitationStats(
      total: list.length,
      pending: list.where((i) => i['status'] == 'pending').length,
      approved: list.where((i) => i['status'] == 'approved').length,
      rejected: list.where((i) => i['status'] == 'rejected').length,
    );
  }
}

// ============ RESULT CLASSES ============

class InvitationResult {
  final bool success;
  final String message;
  final TontineInvitation? invitation;

  InvitationResult({required this.success, required this.message, this.invitation});
}

class ValidationResult {
  final bool success;
  final String message;

  ValidationResult({required this.success, required this.message});
}

class InvitationStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  InvitationStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });
}

// ============ PROVIDER ============

final tontineInvitationServiceProvider = Provider<TontineInvitationService>((ref) {
  return TontineInvitationService();
});
