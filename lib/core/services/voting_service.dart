import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// V15: Voting Service for Payout Order
// Implements Borda Count method for democratic ranking
/// 
/// Legal Compliance:
/// - Votes are timestamped and archived
/// - Cannot be modified after submission
/// - Anonymous voting (optional)
/// - Transparent calculation

class VoteRecord {
  final String id;
  final String voterId; // Voter ID
  final String circleId;
  final List<String> ranking; // Ordered list of member IDs (first = top rank)
  final DateTime timestamp;
  final bool isAnonymous;
  final String? deviceFingerprint; // For fraud detection

  VoteRecord({
    required this.id,
    required this.voterId,
    required this.circleId,
    required this.ranking,
    required this.timestamp,
    this.isAnonymous = false,
    this.deviceFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'voterId': isAnonymous ? 'ANONYMOUS' : voterId,
    'circleId': circleId,
    'ranking': ranking,
    'timestamp': timestamp.toIso8601String(),
    'hash': _generateHash(),
  };

  String _generateHash() {
    // In production: Use SHA-256 for tamper-proof archiving
    return 'HASH_${id}_${timestamp.millisecondsSinceEpoch}';
  }
}

class BordaResult {
  final String memberId;
  final String memberName;
  final int totalPoints;
  final int rank;

  BordaResult({
    required this.memberId,
    required this.memberName,
    required this.totalPoints,
    required this.rank,
  });
}

class VotingState {
  final String circleId;
  final List<VoteRecord> votes;
  final bool isVotingOpen;
  final DateTime? votingDeadline;
  final List<BordaResult>? finalOrder;
  final bool isOrderFinalized;

  VotingState({
    required this.circleId,
    this.votes = const [],
    this.isVotingOpen = false,
    this.votingDeadline,
    this.finalOrder,
    this.isOrderFinalized = false,
  });

  VotingState copyWith({
    List<VoteRecord>? votes,
    bool? isVotingOpen,
    DateTime? votingDeadline,
    List<BordaResult>? finalOrder,
    bool? isOrderFinalized,
  }) {
    return VotingState(
      circleId: circleId,
      votes: votes ?? this.votes,
      isVotingOpen: isVotingOpen ?? this.isVotingOpen,
      votingDeadline: votingDeadline ?? this.votingDeadline,
      finalOrder: finalOrder ?? this.finalOrder,
      isOrderFinalized: isOrderFinalized ?? this.isOrderFinalized,
    );
  }

  bool hasVoted(String voterId) => votes.any((v) => v.voterId == voterId);
  int get voteCount => votes.length;
}

class VotingNotifier extends StateNotifier<Map<String, VotingState>> {
  VotingNotifier() : super({});

  /// Initialize voting for a circle
  void openVoting({
    required String circleId,
    required Duration votingDuration,
  }) {
    state = {
      ...state,
      circleId: VotingState(
        circleId: circleId,
        isVotingOpen: true,
        votingDeadline: DateTime.now().add(votingDuration),
      ),
    };
  }

  /// Submit a vote (DEFINITIVE - cannot be changed)
  void submitVote({
    required String circleId,
    required String voterId,
    required List<String> ranking,
    bool anonymous = false,
  }) {
    final circleVoting = state[circleId];
    if (circleVoting == null) return;
    
    // Check if already voted
    if (circleVoting.hasVoted(voterId)) {
      throw Exception('Vous avez déjà voté. Le vote est définitif.');
    }

    // Check if voting is open
    if (!circleVoting.isVotingOpen) {
      throw Exception('Le vote n\'est pas ouvert pour ce cercle.');
    }

    // Check deadline
    if (circleVoting.votingDeadline != null && 
        DateTime.now().isAfter(circleVoting.votingDeadline!)) {
      throw Exception('La période de vote est terminée.');
    }

    final vote = VoteRecord(
      id: 'vote_${DateTime.now().millisecondsSinceEpoch}',
      voterId: voterId,
      circleId: circleId,
      ranking: ranking,
      timestamp: DateTime.now(),
      isAnonymous: anonymous,
    );

    state = {
      ...state,
      circleId: circleVoting.copyWith(
        votes: [...circleVoting.votes, vote],
      ),
    };
  }

  /// Calculate final order using Borda Count method
  /// Points: N points for 1st place, N-1 for 2nd, etc.
  List<BordaResult> calculateBordaOrder({
    required String circleId,
    required Map<String, String> memberNames, // memberId -> name
  }) {
    final circleVoting = state[circleId];
    if (circleVoting == null || circleVoting.votes.isEmpty) {
      return [];
    }

    final int n = memberNames.length; // Number of members
    final Map<String, int> points = {};

    // Initialize points
    for (final memberId in memberNames.keys) {
      points[memberId] = 0;
    }

    // Calculate points from each vote
    for (final vote in circleVoting.votes) {
      for (int i = 0; i < vote.ranking.length; i++) {
        final memberId = vote.ranking[i];
        final rankPoints = n - i; // 1st place gets N points, 2nd gets N-1, etc.
        points[memberId] = (points[memberId] ?? 0) + rankPoints;
      }
    }

    // Sort by points (descending)
    final sortedMembers = points.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Handle ties with random selection
    final List<BordaResult> results = [];
    int currentRank = 1;
    
    for (int i = 0; i < sortedMembers.length; i++) {
      final entry = sortedMembers[i];
      
      // Check for tie with previous
      if (i > 0 && entry.value == sortedMembers[i - 1].value) {
        // Tie - keep same rank (in production: use random tiebreaker)
      } else {
        currentRank = i + 1;
      }
      
      results.add(BordaResult(
        memberId: entry.key,
        memberName: memberNames[entry.key] ?? 'Unknown',
        totalPoints: entry.value,
        rank: currentRank,
      ));
    }

    return results;
  }

  /// Finalize order and send to PSP
  void finalizeOrder({
    required String circleId,
    required Map<String, String> memberNames,
  }) {
    final circleVoting = state[circleId];
    if (circleVoting == null) return;

    final finalOrder = calculateBordaOrder(
      circleId: circleId,
      memberNames: memberNames,
    );

    state = {
      ...state,
      circleId: circleVoting.copyWith(
        isVotingOpen: false,
        isOrderFinalized: true,
        finalOrder: finalOrder,
      ),
    };

    // In production: Send order to PSP for scheduling
    _sendOrderToPSP(circleId, finalOrder);
  }

  /// Send final order to PSP for payment scheduling
  void _sendOrderToPSP(String circleId, List<BordaResult> order) {
    // In production: API call to PSP
    // This is where we communicate the order without handling funds
    debugPrint('[PSP] Sending payout order for circle $circleId:');
    for (final result in order) {
      debugPrint('  Tour ${result.rank}: ${result.memberName} (${result.totalPoints} pts)');
    }
  }

  /// Get voting state for a circle
  VotingState? getVotingState(String circleId) => state[circleId];

  /// Archive votes for legal compliance
  Map<String, dynamic> exportVotingArchive(String circleId) {
    final circleVoting = state[circleId];
    if (circleVoting == null) return {};

    return {
      'circleId': circleId,
      'votingPeriod': {
        'deadline': circleVoting.votingDeadline?.toIso8601String(),
        'isFinalized': circleVoting.isOrderFinalized,
      },
      'votes': circleVoting.votes.map((v) => v.toJson()).toList(),
      'finalOrder': circleVoting.finalOrder?.map((r) => {
        'rank': r.rank,
        'memberId': r.memberId,
        'memberName': r.memberName,
        'totalPoints': r.totalPoints,
      }).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'method': 'BORDA_COUNT',
      'disclaimer': 'Cet ordre a été calculé automatiquement par la méthode Borda. '
                    'Tontetic n\'intervient pas dans l\'exécution financière.',
    };
  }
}

final votingProvider = StateNotifierProvider<VotingNotifier, Map<String, VotingState>>((ref) {
  return VotingNotifier();
});
