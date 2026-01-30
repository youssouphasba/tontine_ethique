import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/services/security_service.dart';

final suggestionServiceProvider = Provider((ref) => SuggestionService());

class SuggestionResult {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? jobTitle;
  final int mutualFriendsCount;
  final int mutualCirclesCount;
  final String reason; // "2 amis en commun", "Membre de [Tontine]"

  SuggestionResult({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.jobTitle,
    this.mutualFriendsCount = 0,
    this.mutualCirclesCount = 0,
    required this.reason,
  });
}

class SuggestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<SuggestionResult>> getSuggestions(String currentUserId) async {
    // 1. Get current user's data (friends & circles)
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!userDoc.exists) return [];

    final userData = userDoc.data()!;
    final List<String> myFriendIds = []; // TODO: Fetch from subcollection 'following' if meaningful
    final List<String> myCircleIds = List<String>.from(userData['activeCircleIds'] ?? []);

    // Fetch actual friends (following)
    final followingSnap = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .get();
    
    myFriendIds.addAll(followingSnap.docs.map((d) => d.id));

    // 2. Find Candidate Pool
    // Potential candidates: 
    // - Friends of friends
    // - Members of my circles
    // - (Optimization) Limit to 50 active users to avoid full DB scan
    
    final Map<String, int> candidateScores = {};
    final Map<String, String> candidateReasons = {};

    // A. Scan Co-members (Strong signal)
    if (myCircleIds.isNotEmpty) {
      // Limit to last 5 circles to avoid massive reads
      final recentCircles = myCircleIds.take(5).toList();
      for (final circleId in recentCircles) {
        final circleDoc = await _firestore.collection('tontines').doc(circleId).get();
        if (!circleDoc.exists) continue;
        
        final List<String> members = List<String>.from(circleDoc.data()?['memberIds'] ?? []);
        final circleName = circleDoc.data()?['name'] ?? 'Tontine';
        
        for (final memberId in members) {
          if (memberId == currentUserId || myFriendIds.contains(memberId)) continue;
          
          candidateScores[memberId] = (candidateScores[memberId] ?? 0) + 5; // +5 points for co-membership
          candidateReasons[memberId] = "Membre de $circleName";
        }
      }
    }

    // B. Scan Friends of Friends (Social Proof)
    // For each friend, get their friends (limited to top 5 friends to optimise)
    for (final friendId in myFriendIds.take(10)) {
      final fofSnap = await _firestore
          .collection('users')
          .doc(friendId)
          .collection('following')
          .limit(20)
          .get();
      
      for (final doc in fofSnap.docs) {
        final fofId = doc.id;
        if (fofId == currentUserId || myFriendIds.contains(fofId)) continue;

        candidateScores[fofId] = (candidateScores[fofId] ?? 0) + 1; // +1 point per mutual friend
        
        // If > 1 mutual friend, update reason
        if ((candidateScores[fofId] ?? 0) > 1 && (candidateScores[fofId] ?? 0) < 5) {
             candidateReasons[fofId] = "${candidateScores[fofId]} amis en commun";
        } else if (candidateScores[fofId] == 1) {
             candidateReasons[fofId] = "Ami avec ${doc.data()['displayName'] ?? 'un contact'}"; // Approximation
        }
      }
    }

    // 3. Keep Top 20 Candidates
    final sortedIds = candidateScores.keys.toList()
      ..sort((a, b) => candidateScores[b]!.compareTo(candidateScores[a]!));
    
    final topIds = sortedIds.take(20).toList();
    
    // If list is empty/small, fill with random active users (Discovery)
    if (topIds.length < 5) {
      final randomSnap = await _firestore
          .collection('users')
          .where('activeCirclesCount', isGreaterThan: 0)
          .limit(10)
          .get();
          
      for (final doc in randomSnap.docs) {
        if (doc.id == currentUserId || myFriendIds.contains(doc.id) || topIds.contains(doc.id)) continue;
        topIds.add(doc.id);
        candidateReasons[doc.id] = "Actif sur Tontetic";
      }
    }

    // 4. Fetch Details for Candidates
    final List<SuggestionResult> results = [];
    
    // Batch fetch (Firestore whereIn constrained to 10, so loop)
    // For simplicity here, separate gets (optimized in prod with chunks)
    for (final id in topIds) {
      final doc = await _firestore.collection('users').doc(id).get();
      if (!doc.exists) continue;
      
      final data = doc.data()!;
      
      // Name Resolution
      final fullName = data['fullName'] as String?;
      final dispName = data['displayName'] as String?;
      final pseudo = data['pseudo'] as String?;
      final email = data['email'] as String?;
      final encrypted = data['encryptedName'] as String?;

      String name = '';
      if (fullName != null && fullName.isNotEmpty && !fullName.contains('Utilisateur')) {
        name = fullName;
      } else if (dispName != null && dispName.isNotEmpty && !dispName.contains('Utilisateur')) {
        name = dispName;
      } else if (pseudo != null && pseudo.isNotEmpty) {
        name = pseudo;
      } else if (encrypted != null) {
        try {
          final decrypted = SecurityService.decryptData(encrypted);
          if (decrypted.isNotEmpty && !decrypted.contains('Utilisateur')) name = decrypted;
        } catch (_) {}
      }
      
      if (name.isEmpty && email != null) name = email.split('@').first;
      if (name.isEmpty) name = 'Membre-${id.substring(0,4)}';

      results.add(SuggestionResult(
        userId: id,
        userName: name,
        userAvatar: data['photoUrl'],
        jobTitle: data['jobTitle'],
        mutualFriendsCount: candidateScores[id] ?? 0,
        reason: candidateReasons[id] ?? 'Nouveau membre',
      ));
    }

    return results;
  }
}
