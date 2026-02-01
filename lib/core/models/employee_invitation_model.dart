import 'package:cloud_firestore/cloud_firestore.dart';

enum InvitationStatus {
  pending,    // Envoyée, en attente
  opened,     // Lien ouvert
  accepted,   // Compte créé ou lié
  declined,   // Refusé par le salarié
  expired,    // Délai dépassé (7 jours)
}

class EmployeeInvitation {
  final String id;
  final String companyId; // Added to link to company
  final String email;
  final String? name;
  final DateTime sentAt;
  final InvitationStatus status;
  final String token; // Secure token for the link

  EmployeeInvitation({
    required this.id,
    required this.companyId,
    required this.email,
    this.name,
    required this.sentAt,
    this.status = InvitationStatus.pending,
    required this.token,
  });

  factory EmployeeInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeInvitation(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      email: data['email'] ?? '',
      name: data['name'],
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => InvitationStatus.pending,
      ),
      token: data['token'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'email': email,
      'name': name,
      'sentAt': Timestamp.fromDate(sentAt),
      'status': status.name,
      'token': token,
    };
  }
}
