import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// V11.5 - Security Service
/// Implements Triple Layer Security: Financial, User-to-User, and Tontine protection

enum SecurityAlert {
  lowHonorScoreCircleJoin,    // Honor < 50, trying to join 3+ circles
  multipleCircleAttempt,       // Too many circles too fast
  unverifiedCircleAction,      // KYC not verified
  suspiciousPaymentPattern,    // Unusual transaction behavior
  walletFrozen,                // Wallet locked due to debt
}

class FraudAlert {
  final String id;
  final String userId;
  final SecurityAlert type;
  final String description;
  final DateTime timestamp;
  final bool isResolved;

  FraudAlert({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.timestamp,
    this.isResolved = false,
  });
}

class SecurityState {
  final List<FraudAlert> alerts;
  final Set<String> frozenWallets; // User IDs with frozen wallets
  final Map<String, int> activeCircleCount; // userId -> active circles

  SecurityState({
    this.alerts = const [],
    this.frozenWallets = const {},
    this.activeCircleCount = const {},
  });

  SecurityState copyWith({
    List<FraudAlert>? alerts,
    Set<String>? frozenWallets,
    Map<String, int>? activeCircleCount,
  }) {
    return SecurityState(
      alerts: alerts ?? this.alerts,
      frozenWallets: frozenWallets ?? this.frozenWallets,
      activeCircleCount: activeCircleCount ?? this.activeCircleCount,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  static const int maxCirclesLowScore = 3;
  static const int minHonorThreshold = 50;
  static const int honorScoreLatePayment = 200;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _securitySub;

  SecurityNotifier() : super(SecurityState()) {
    _initSync();
  }

  void _initSync() {
    _securitySub = _firestore.collection('fraud_alerts').snapshots().listen((snapshot) {
      final alerts = snapshot.docs.map((doc) {
        final data = doc.data();
        return FraudAlert(
          id: doc.id,
          userId: data['userId'] ?? '',
          type: SecurityAlert.values.firstWhere(
            (e) => e.name == data['type'],
            orElse: () => SecurityAlert.lowHonorScoreCircleJoin
          ),
          description: data['description'] ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isResolved: data['isResolved'] ?? false,
        );
      }).toList();
      
      // Sort: unresolved first, then by timestamp descending
      alerts.sort((a, b) {
        if (a.isResolved != b.isResolved) {
          return a.isResolved ? 1 : -1;
        }
        return b.timestamp.compareTo(a.timestamp);
      });

      state = state.copyWith(alerts: alerts);
    });
  }

  @override
  void dispose() {
    _securitySub?.cancel();
    super.dispose();
  }

  /// Check if user can join a circle (KYC + Score + Wallet status)
  SecurityCheckResult canJoinCircle({
    required String userId,
    required bool isKycVerified,
    required int honorScore,
    required int currentActiveCircles,
  }) {
    // Check 1: KYC Verification (DISABLED by user request V4.0)
    /*
    if (!isKycVerified) {
      return SecurityCheckResult(
        allowed: false,
        reason: SecurityDenialReason.kycRequired,
        message: 'Vérification d\'identité requise avant de rejoindre un cercle.',
      );
    }
    */

    // Check 2: Wallet Frozen
    if (state.frozenWallets.contains(userId)) {
      return SecurityCheckResult(
        allowed: false,
        reason: SecurityDenialReason.walletFrozen,
        message: 'Votre portefeuille est gelé. Régularisez vos paiements en attente.',
      );
    }

    // Check 3: Low Honor Score + Too Many Circles
    if (honorScore < minHonorThreshold && currentActiveCircles >= maxCirclesLowScore) {
      _raiseAlert(
        userId: userId,
        type: SecurityAlert.lowHonorScoreCircleJoin,
        description: 'Tentative de rejoindre un 4ème cercle avec un Score d\'Honneur < 50',
      );
      return SecurityCheckResult(
        allowed: false,
        reason: SecurityDenialReason.lowHonorScore,
        message: 'Votre Score d\'Honneur est trop bas pour rejoindre plus de cercles.',
      );
    }

    // Check 4: Honor Score below late payment threshold
    if (honorScore < honorScoreLatePayment) {
      return SecurityCheckResult(
        allowed: true,
        warning: 'Attention: Votre Score d\'Honneur est bas. Les organisateurs peuvent refuser votre participation.',
      );
    }

    return SecurityCheckResult(allowed: true);
  }

  /// Check mutual follow for invitation permission
  MutualFollowResult checkMutualFollow({
    required String inviterId,
    required String inviteeId,
    required bool inviterFollowsInvitee,
    required bool inviteeFollowsInviter,
  }) {
    final isMutual = inviterFollowsInvitee && inviteeFollowsInviter;
    
    return MutualFollowResult(
      canInvite: isMutual,
      inviterFollowsInvitee: inviterFollowsInvitee,
      inviteeFollowsInviter: inviteeFollowsInviter,
      message: isMutual 
          ? null 
          : _getMutualFollowMessage(inviterFollowsInvitee, inviteeFollowsInviter),
    );
  }

  String _getMutualFollowMessage(bool aFollowsB, bool bFollowsA) {
    if (!aFollowsB && !bFollowsA) {
      return 'Vous devez vous suivre mutuellement pour envoyer une invitation.';
    } else if (!aFollowsB) {
      return 'Vous devez suivre cet utilisateur pour l\'inviter.';
    } else {
      return 'Cet utilisateur doit vous suivre en retour pour recevoir une invitation.';
    }
  }

  /// Freeze wallet due to payment issues
  void freezeWallet(String userId, String reason) {
    final wallets = Set<String>.from(state.frozenWallets);
    wallets.add(userId);
    
    _raiseAlert(
      userId: userId,
      type: SecurityAlert.walletFrozen,
      description: 'Portefeuille gelé: $reason',
    );
    
    state = state.copyWith(frozenWallets: wallets);
  }

  /// Unfreeze wallet after payment regularization
  void unfreezeWallet(String userId) {
    final wallets = Set<String>.from(state.frozenWallets);
    wallets.remove(userId);
    state = state.copyWith(frozenWallets: wallets);
  }

  /// Check if wallet is frozen
  bool isWalletFrozen(String userId) {
    return state.frozenWallets.contains(userId);
  }

  /// Track circle joins for fraud detection
  void trackCircleJoin(String userId) {
    final counts = Map<String, int>.from(state.activeCircleCount);
    counts[userId] = (counts[userId] ?? 0) + 1;
    state = state.copyWith(activeCircleCount: counts);
  }

  /// Remove circle from tracking
  void trackCircleLeave(String userId) {
    final counts = Map<String, int>.from(state.activeCircleCount);
    final current = counts[userId] ?? 0;
    if (current > 0) {
      counts[userId] = current - 1;
    }
    state = state.copyWith(activeCircleCount: counts);
  }

  /// Get user's active circle count
  int getActiveCircleCount(String userId) {
    return state.activeCircleCount[userId] ?? 0;
  }

  /// Raise a security alert
  Future<void> _raiseAlert({
    required String userId,
    required SecurityAlert type,
    required String description,
  }) async {
    await _firestore.collection('fraud_alerts').add({
      'userId': userId,
      'type': type.name,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'isResolved': false,
    });
  }

  /// Get pending alerts for admin
  List<FraudAlert> get pendingAlerts => 
      state.alerts.where((a) => !a.isResolved).toList();

  /// Resolve an alert
  Future<void> resolveAlert(String alertId) async {
    await _firestore.collection('fraud_alerts').doc(alertId).update({
      'isResolved': true,
    });
  }
}

class SecurityCheckResult {
  final bool allowed;
  final SecurityDenialReason? reason;
  final String? message;
  final String? warning;

  SecurityCheckResult({
    required this.allowed,
    this.reason,
    this.message,
    this.warning,
  });
}

enum SecurityDenialReason {
  kycRequired,
  walletFrozen,
  lowHonorScore,
  tooManyCircles,
}

class MutualFollowResult {
  final bool canInvite;
  final bool inviterFollowsInvitee;
  final bool inviteeFollowsInviter;
  final String? message;

  MutualFollowResult({
    required this.canInvite,
    required this.inviterFollowsInvitee,
    required this.inviteeFollowsInviter,
    this.message,
  });
}

final securityProvider = StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier();
});

/// Extension on UserState for security checks
extension UserSecurityExtension on UserState {
  /// Get Honor Score from trust history (simplified calculation)
  int get honorScore {
    int score = 0;
    for (final entry in trustScoreHistory) {
      final match = RegExp(r'([+-]?\d+)').firstMatch(entry);
      if (match != null) {
        score += int.tryParse(match.group(1) ?? '0') ?? 0;
      }
    }
    return score;
  }
}
