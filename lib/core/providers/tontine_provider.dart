import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/tontine_model.dart';

import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/services/circle_service.dart';


class CircleState {
  final List<TontineCircle> myCircles;
  final List<TontineCircle> explorerCircles;
  final List<JoinRequest> pendingInvitations;
  final List<JoinRequest> myJoinRequests; // V15: Requests I've sent to join circles

  CircleState({
    this.myCircles = const [],
    this.explorerCircles = const [],
    this.pendingInvitations = const [],
    this.myJoinRequests = const [],
  });

  CircleState copyWith({
    List<TontineCircle>? myCircles,
    List<TontineCircle>? explorerCircles,
    List<JoinRequest>? pendingInvitations,
    List<JoinRequest>? myJoinRequests,
  }) {
    return CircleState(
      myCircles: myCircles ?? this.myCircles,
      explorerCircles: explorerCircles ?? this.explorerCircles,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      myJoinRequests: myJoinRequests ?? this.myJoinRequests,
    );
  }
}


// (Enums and Models stay the same, but let's ensure the classes are available)

/// Service provider for CircleService
final circleServiceProvider = Provider<CircleService>((ref) => CircleService());

class CircleNotifier extends StateNotifier<CircleState> {
  final Ref ref;
  StreamSubscription? _myCirclesSub;
  StreamSubscription? _explorerCirclesSub;
  StreamSubscription? _myRequestsSub;

  CircleNotifier(this.ref) : super(CircleState()) {
    _initListeners();
  }

  void _initListeners() {
    final authState = ref.watch(authStateProvider);
    final circleService = ref.read(circleServiceProvider);

    // Explorer (Public Circles) should always be visible, even for guests
    _explorerCirclesSub?.cancel();
    _explorerCirclesSub = circleService.getPublicCircles().listen((circles) {
      if (mounted) {
        state = state.copyWith(explorerCircles: circles);
      }
    });

    authState.whenData((user) {
      if (user != null) {
        // Écouter mes cercles
        _myCirclesSub?.cancel();
        _myCirclesSub = circleService.getMyCircles(user.uid).listen((circles) {
          if (mounted) {
            state = state.copyWith(myCircles: circles);
          }
        });
        
        // V16: Listen to my requests
        _myRequestsSub?.cancel();
        _myRequestsSub = circleService.getMyJoinRequests(user.uid).listen((requests) {
          if (mounted) {
            state = state.copyWith(myJoinRequests: requests);
          }
        });
      } else {
        _myCirclesSub?.cancel();
        _myRequestsSub?.cancel();
        state = state.copyWith(myCircles: [], myJoinRequests: []);
      }
    });
  }

  String _generateCode() {
    final now = DateTime.now();
    return 'TONT-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  Future<String?> createCircle({
    required String name,
    required String objective,
    required double amount,
    required int maxParticipants,
    required String frequency,
    required int payoutDay,
    required String orderType,
    required String creatorId,
    required String creatorName,
    required bool isPublic,
    required bool isSponsored,
    List<String> invitedContacts = const [],
    String? currency, // V15: Explicit currency
    String? enterpriseId, // V18: Corporate Link
  }) async {
    final user = ref.read(userProvider);
    final newCircle = TontineCircle(
      id: '', // Sera généré par Firestore
      name: name,
      objective: objective,
      amount: amount,
      maxParticipants: maxParticipants,
      frequency: frequency,
      payoutDay: payoutDay,
      orderType: orderType,
      creatorId: creatorId,
      creatorName: creatorName,
      invitationCode: _generateCode(),
      isPublic: isPublic,
      isSponsored: isSponsored,
      createdAt: DateTime.now(),
      memberIds: [creatorId, ...invitedContacts],
      currency: currency ?? user.zone.currency,
      enterpriseId: enterpriseId,
    );

    final circleId = await ref.read(circleServiceProvider).createCircle(newCircle);
    
    // Inrémenter le compteur d'ACL dans le UserProvider
    ref.read(userProvider.notifier).incrementActiveCircles();

    return circleId;
  }

  Future<void> requestToJoin({
    required String circleId,
    required String circleName,
    required String requesterId,
    required String requesterName,
    String? message,
  }) async {
    await ref.read(circleServiceProvider).requestToJoin(
      circleId: circleId,
      circleName: circleName,
      requesterId: requesterId,
      requesterName: requesterName,
      message: message,
    );
  }

  Future<void> approveJoinRequest(String requestId, String circleId, String userId) async {
    await ref.read(circleServiceProvider).approveRequest(requestId, circleId, userId);
  }

  Future<void> rejectJoinRequest(String requestId) async {
    await ref.read(circleServiceProvider).rejectRequest(requestId);
  }

  Future<void> finalizeMembership(String circleId, String userId) async {
    await ref.read(circleServiceProvider).finalizeMembership(circleId, userId);
  }

  // Debug/Sandbox methods
  Future<void> advanceCycle(String circleId) async {
    // In a real app, this would increment currentCycle in Firestore
    debugPrint('🔄 Sandbox: Advance cycle for $circleId');
  }


  // Les autres méthodes (joinByCode, etc.) devront aussi être migrées vers CircleService
  // pour une persistance réelle.

  @override
  void dispose() {
    _myCirclesSub?.cancel();
    _explorerCirclesSub?.cancel();
    super.dispose();
  }
}

final circleProvider = StateNotifierProvider<CircleNotifier, CircleState>((ref) {
  return CircleNotifier(ref);
});

