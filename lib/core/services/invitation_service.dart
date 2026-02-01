import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/models/employee_invitation_model.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class InvitationService {
  final FirebaseFirestore _firestore;

  InvitationService(this._firestore);

  /// Generates a secure random token
  String _generateToken(String email) {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final hash = sha256.convert(utf8.encode('$email-${DateTime.now()}-${base64Url.encode(values)}'));
    return hash.toString().substring(0, 32); 
  }

  /// Sends an invitation (creates document)
  Future<String> sendInvitation(String companyId, String email, String? name) async {
    final token = _generateToken(email);
    final id = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    
    final invitation = EmployeeInvitation(
      id: id,
      companyId: companyId,
      email: email,
      name: name,
      sentAt: DateTime.now(),
      status: InvitationStatus.pending,
      token: token,
    );

    // Store in a top-level collection for easier querying by token, 
    // or subcollection if we only query by company. 
    // Top-level 'invitations' is better for validation by token.
    await _firestore.collection('invitations').doc(id).set(invitation.toFirestore());
    
    return token;
  }

  /// Get invitations for a company
  Stream<List<EmployeeInvitation>> getCompanyInvitations(String companyId) {
    return _firestore.collection('invitations')
        .where('companyId', isEqualTo: companyId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => EmployeeInvitation.fromFirestore(doc)).toList());
  }

  /// Validate token and get invitation info
  Future<EmployeeInvitation?> validateToken(String token) async {
    final query = await _firestore.collection('invitations')
        .where('token', isEqualTo: token)
        .limit(1)
        .get();
        
    if (query.docs.isNotEmpty) {
      return EmployeeInvitation.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Accept invitation
  Future<void> acceptInvitation(String invitationId) async {
    await _firestore.collection('invitations').doc(invitationId).update({
      'status': InvitationStatus.accepted.name,
    });
  }
}

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService(FirebaseFirestore.instance);
});
