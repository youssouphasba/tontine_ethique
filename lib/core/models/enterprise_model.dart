import 'package:cloud_firestore/cloud_firestore.dart';

class EnterpriseModel {
  final String id;
  final String name; // Raison sociale
  final String nif; // Siret/Ninea
  final String country; // FR, SN
  final String address;
  final String contactEmail;
  final String contactPhone;
  final String representativeName;
  final bool isVerified;
  final String? logoUrl;
  final DateTime createdAt;
  final String ownerId; // UID of the admin user who created it

  EnterpriseModel({
    required this.id,
    required this.name,
    required this.nif,
    required this.country,
    required this.address,
    required this.contactEmail,
    required this.contactPhone,
    required this.representativeName,
    this.isVerified = false,
    this.logoUrl,
    required this.createdAt,
    required this.ownerId,
  });

  factory EnterpriseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EnterpriseModel(
      id: doc.id,
      name: data['name'] ?? '',
      nif: data['nif'] ?? '',
      country: data['country'] ?? 'SN',
      address: data['address'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      representativeName: data['representativeName'] ?? '',
      isVerified: data['isVerified'] ?? false,
      logoUrl: data['logoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      ownerId: data['ownerId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'nif': nif,
      'country': country,
      'address': address,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'representativeName': representativeName,
      'isVerified': isVerified,
      'logoUrl': logoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerId': ownerId,
    };
  }
}
