/// V17: Service de gestion des invitations à rejoindre une tontine
/// 
/// RÈGLES GÉNÉRALES:
/// 1. Tous les membres d'un cercle peuvent envoyer des invitations
/// 2. Les invitations sont soumises à la validation du CRÉATEUR de la tontine
/// 3. Le créateur peut accepter ou refuser les invitations
/// 4. L'invité reçoit une notification quand son invitation est validée
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  );
}

class TontineInvitationService {
  final SupabaseClient _client;

  // Durée de validité d'une invitation (7 jours)
  static const int invitationExpiryDays = 7;

  TontineInvitationService() : _client = Supabase.instance.client;

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
      final existing = await _client
          .from('tontine_invitations')
          .select()
          .eq('tontine_id', tontineId)
          .eq('invitee_phone', inviteePhone)
          .inFilter('status', ['pending', 'approved'])
          .maybeSingle();

      if (existing != null) {
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
      );

      await _client.from('tontine_invitations').insert(invitation.toJson());

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

  // ============ VALIDATION PAR LE CRÉATEUR ============

  /// Récupérer les invitations en attente pour une tontine (créateur uniquement)
  Future<List<TontineInvitation>> getPendingInvitations(String tontineId) async {
    final response = await _client
        .from('tontine_invitations')
        .select()
        .eq('tontine_id', tontineId)
        .eq('status', TontineInvitationStatus.pending.name)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => TontineInvitation.fromJson(json))
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

    await _client.from('tontine_invitations').update({
      'status': TontineInvitationStatus.approved.name,
    }).eq('id', invitationId);

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

    await _client.from('tontine_invitations').update({
      'status': TontineInvitationStatus.rejected.name,
      'creator_note': reason,
    }).eq('id', invitationId);

    debugPrint('[INVITATION] Invitation $invitationId rejected: $reason');

    return ValidationResult(
      success: true,
      message: 'Invitation refusée.',
    );
  }

  // ============ POUR L'INVITÉ ============

  /// Récupérer les invitations reçues par un utilisateur
  Future<List<TontineInvitation>> getReceivedInvitations(String userPhone) async {
    final response = await _client
        .from('tontine_invitations')
        .select()
        .eq('invitee_phone', userPhone)
        .eq('status', TontineInvitationStatus.approved.name)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => TontineInvitation.fromJson(json))
        .toList();
  }

  // ============ NETTOYAGE ============

  /// Marquer les invitations expirées (appeler via CRON)
  Future<void> expireOldInvitations() async {
    final now = DateTime.now();
    
    await _client.from('tontine_invitations').update({
      'status': TontineInvitationStatus.expired.name,
    })
    .eq('status', TontineInvitationStatus.pending.name)
    .lt('expires_at', now.toIso8601String());

    debugPrint('[INVITATION] Expired old pending invitations');
  }

  // ============ STATS ============

  Future<InvitationStats> getStats(String tontineId) async {
    final all = await _client
        .from('tontine_invitations')
        .select()
        .eq('tontine_id', tontineId);

    final list = all as List;
    
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
