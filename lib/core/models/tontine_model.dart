
/// Join request status
enum JoinRequestStatus { pending, approved, rejected }

/// Join request model
class JoinRequest {
  final String id;
  final String circleId;
  final String circleName;
  final String requesterId;
  final String requesterName;
  final DateTime requestedAt;
  final JoinRequestStatus status;
  final String? message; // Optional message from requester

  JoinRequest({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.requesterId,
    required this.requesterName,
    required this.requestedAt,
    this.status = JoinRequestStatus.pending,
    this.message,
  });

  JoinRequest copyWith({JoinRequestStatus? status}) {
    return JoinRequest(
      id: id,
      circleId: circleId,
      circleName: circleName,
      requesterId: requesterId,
      requesterName: requesterName,
      requestedAt: requestedAt,
      status: status ?? this.status,
      message: message,
    );
  }
}

class TontineCircle {
  final String id;
  final String name;
  final String objective;
  final double amount;
  final int maxParticipants;
  final String frequency;
  final int payoutDay;
  final String orderType;
  final String creatorId;
  final String creatorName;
  final String invitationCode;
  final bool isPublic;
  final bool isSponsored;
  final DateTime createdAt;
  final List<String> memberIds;
  final int currentCycle;
  final String currency; // V15: Dynamic Currency Support
  final List<JoinRequest> joinRequests; // V16: Requests to join
  final List<String> pendingSignatureIds; // V16: Approved but not signed yet

  TontineCircle({
    required this.id,
    required this.name,
    required this.objective,
    required this.amount,
    required this.maxParticipants,
    required this.frequency,
    required this.payoutDay,
    required this.orderType,
    required this.creatorId,
    required this.creatorName,
    required this.invitationCode,
    required this.isPublic,
    required this.isSponsored,
    required this.createdAt,
    required this.memberIds,
    this.currency = 'FCFA',
    this.currentCycle = 1,
    this.joinRequests = const [],
    this.pendingSignatureIds = const [],
  });

  TontineCircle copyWith({
    String? id,
    int? currentCycle,
    String? currency,
    List<String>? memberIds,
    List<JoinRequest>? joinRequests,
    List<String>? pendingSignatureIds,
  }) {
    return TontineCircle(
      id: id ?? this.id,
      name: name,
      objective: objective,
      amount: amount,
      maxParticipants: maxParticipants,
      frequency: frequency,
      payoutDay: payoutDay,
      orderType: orderType,
      creatorId: creatorId,
      creatorName: creatorName,
      invitationCode: invitationCode,
      isPublic: isPublic,
      isSponsored: isSponsored,
      createdAt: createdAt,
      memberIds: memberIds ?? this.memberIds,
      currency: currency ?? this.currency,
      currentCycle: currentCycle ?? this.currentCycle,
      joinRequests: joinRequests ?? this.joinRequests,
      pendingSignatureIds: pendingSignatureIds ?? this.pendingSignatureIds,
    );
  }

  double get progress => currentCycle / maxParticipants;
  bool get isFull => memberIds.length >= maxParticipants;
  bool get isComplete => memberIds.length >= maxParticipants;
  bool get isFinished => currentCycle > maxParticipants;
  int get pendingRequestsCount => joinRequests.where((r) => r.status == JoinRequestStatus.pending).length;
}
