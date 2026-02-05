import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service client pour l'API Mangopay
///
/// Ce service gère les appels API vers les Cloud Functions Mangopay.
/// Les opérations sensibles (création wallet, paiements) sont exécutées
/// côté serveur pour protéger les clés API.
///
/// Documentation Mangopay : https://docs.mangopay.com
class MangopayService {
  // URL des Cloud Functions
  static const String _functionsBaseUrl =
      'https://europe-west1-tontetic-admin.cloudfunctions.net';

  /// Singleton
  static final MangopayService _instance = MangopayService._internal();
  factory MangopayService() => _instance;
  MangopayService._internal();

  // ============================================================
  // USERS
  // ============================================================

  /// Crée un utilisateur Natural (particulier) dans Mangopay
  /// Requis avant de pouvoir créer un wallet
  Future<MangopayResult<MangopayUser>> createNaturalUser({
    required String odooUserId,
    required String email,
    required String firstName,
    required String lastName,
    required DateTime birthday,
    required String nationality, // ISO 3166-1 alpha-2 (FR, SN, etc.)
    required String countryOfResidence,
  }) async {
    try {
      debugPrint('[Mangopay] Creating natural user for $email');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreateNaturalUser'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': odooUserId,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'birthday': birthday.millisecondsSinceEpoch ~/ 1000, // Unix timestamp
          'nationality': nationality,
          'countryOfResidence': countryOfResidence,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ User created: ${data['mangopayUserId']}');
        return MangopayResult.success(MangopayUser.fromJson(data));
      } else {
        final error = jsonDecode(response.body);
        debugPrint('[Mangopay] ❌ Error: ${error['error']}');
        return MangopayResult.failure(error['error'] ?? 'Erreur serveur');
      }
    } catch (e) {
      debugPrint('[Mangopay] ❌ Exception: $e');
      return MangopayResult.failure('Erreur de connexion: $e');
    }
  }

  /// Récupère un utilisateur Mangopay par son ID Firestore
  Future<MangopayResult<MangopayUser>> getUser(String odooUserId) async {
    try {
      final response = await http.get(
        Uri.parse('$_functionsBaseUrl/mangopayGetUser?userId=$odooUserId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MangopayResult.success(MangopayUser.fromJson(data));
      } else {
        return MangopayResult.failure('Utilisateur non trouvé');
      }
    } catch (e) {
      return MangopayResult.failure('Erreur: $e');
    }
  }

  // ============================================================
  // WALLETS
  // ============================================================

  /// Crée un wallet pour un utilisateur
  /// Chaque utilisateur doit avoir au moins un wallet pour participer aux tontines
  Future<MangopayResult<MangopayWallet>> createWallet({
    required String odooUserId,
    required String mangopayUserId,
    String currency = 'EUR',
    String description = 'Wallet Tontine',
  }) async {
    try {
      debugPrint('[Mangopay] Creating wallet for user $mangopayUserId');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreateWallet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': odooUserId,
          'mangopayUserId': mangopayUserId,
          'currency': currency,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ Wallet created: ${data['walletId']}');
        return MangopayResult.success(MangopayWallet.fromJson(data));
      } else {
        final error = jsonDecode(response.body);
        return MangopayResult.failure(error['error'] ?? 'Erreur création wallet');
      }
    } catch (e) {
      return MangopayResult.failure('Erreur: $e');
    }
  }

  /// Récupère le solde d'un wallet
  Future<MangopayResult<MangopayWallet>> getWallet(String walletId) async {
    try {
      final response = await http.get(
        Uri.parse('$_functionsBaseUrl/mangopayGetWallet?walletId=$walletId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MangopayResult.success(MangopayWallet.fromJson(data));
      } else {
        return MangopayResult.failure('Wallet non trouvé');
      }
    } catch (e) {
      return MangopayResult.failure('Erreur: $e');
    }
  }

  // ============================================================
  // BANK ACCOUNTS
  // ============================================================

  /// Enregistre un compte bancaire IBAN pour un utilisateur
  /// Nécessaire pour les PayOut (retraits vers compte bancaire)
  Future<MangopayResult<MangopayBankAccount>> createBankAccountIban({
    required String mangopayUserId,
    required String ownerName,
    required String iban,
    required String ownerAddressLine1,
    required String ownerCity,
    required String ownerPostalCode,
    required String ownerCountry, // ISO 3166-1 alpha-2
  }) async {
    try {
      debugPrint('[Mangopay] Registering IBAN for user $mangopayUserId');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreateBankAccount'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mangopayUserId': mangopayUserId,
          'type': 'IBAN',
          'ownerName': ownerName,
          'iban': iban,
          'ownerAddress': {
            'addressLine1': ownerAddressLine1,
            'city': ownerCity,
            'postalCode': ownerPostalCode,
            'country': ownerCountry,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ Bank account created: ${data['bankAccountId']}');
        return MangopayResult.success(MangopayBankAccount.fromJson(data));
      } else {
        final error = jsonDecode(response.body);
        return MangopayResult.failure(error['error'] ?? 'Erreur IBAN');
      }
    } catch (e) {
      return MangopayResult.failure('Erreur: $e');
    }
  }

  // ============================================================
  // MANDATES (SEPA Direct Debit)
  // ============================================================

  /// Crée un mandat SEPA Direct Debit
  /// Permet de prélever automatiquement sur le compte bancaire
  Future<MangopayResult<MangopayMandate>> createMandate({
    required String mangopayUserId,
    required String bankAccountId,
    String culture = 'FR',
  }) async {
    try {
      debugPrint('[Mangopay] Creating SEPA mandate for bank account $bankAccountId');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopayCreateMandate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mangopayUserId': mangopayUserId,
          'bankAccountId': bankAccountId,
          'culture': culture,
          'returnUrl': kIsWeb
              ? 'https://tontetic-app.web.app/mandate/complete'
              : 'tontetic://mandate/complete',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ Mandate created: ${data['mandateId']}');
        return MangopayResult.success(MangopayMandate.fromJson(data));
      } else {
        final error = jsonDecode(response.body);
        return MangopayResult.failure(error['error'] ?? 'Erreur mandat');
      }
    } catch (e) {
      return MangopayResult.failure('Erreur: $e');
    }
  }

  // ============================================================
  // KYC
  // ============================================================

  /// Soumet les documents KYC pour vérification
  /// Requis pour les PayOut > 150€
  Future<MangopayResult<String>> submitKycDocument({
    required String mangopayUserId,
    required String documentType, // IDENTITY_PROOF, ADDRESS_PROOF, etc.
    required List<String> base64Pages,
  }) async {
    try {
      debugPrint('[Mangopay] Submitting KYC document: $documentType');

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mangopaySubmitKyc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mangopayUserId': mangopayUserId,
          'documentType': documentType,
          'pages': base64Pages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[Mangopay] ✅ KYC submitted: ${data['kycDocumentId']}');
        return MangopayResult.success(data['kycDocumentId']);
      } else {
        final error = jsonDecode(response.body);
        return MangopayResult.failure(error['error'] ?? 'Erreur KYC');
      }
    } catch (e) {
      return MangopayResult.failure('Erreur: $e');
    }
  }
}

// ============================================================
// MODELS
// ============================================================

/// Résultat générique pour les opérations Mangopay
class MangopayResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  MangopayResult._({required this.isSuccess, this.data, this.error});

  factory MangopayResult.success(T data) =>
      MangopayResult._(isSuccess: true, data: data);

  factory MangopayResult.failure(String error) =>
      MangopayResult._(isSuccess: false, error: error);
}

/// Utilisateur Mangopay
class MangopayUser {
  final String id;
  final String odooUserId;
  final String email;
  final String firstName;
  final String lastName;
  final String? kycLevel; // LIGHT, REGULAR

  MangopayUser({
    required this.id,
    required this.odooUserId,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.kycLevel,
  });

  factory MangopayUser.fromJson(Map<String, dynamic> json) => MangopayUser(
        id: json['mangopayUserId'] ?? json['Id'],
        odooUserId: json['userId'] ?? '',
        email: json['email'] ?? json['Email'] ?? '',
        firstName: json['firstName'] ?? json['FirstName'] ?? '',
        lastName: json['lastName'] ?? json['LastName'] ?? '',
        kycLevel: json['kycLevel'] ?? json['KYCLevel'],
      );
}

/// Wallet Mangopay
class MangopayWallet {
  final String id;
  final String ownerId;
  final int balance; // En centimes
  final String currency;
  final String description;

  MangopayWallet({
    required this.id,
    required this.ownerId,
    required this.balance,
    required this.currency,
    required this.description,
  });

  double get balanceInUnits => balance / 100;

  factory MangopayWallet.fromJson(Map<String, dynamic> json) => MangopayWallet(
        id: json['walletId'] ?? json['Id'],
        ownerId: json['ownerId'] ?? json['Owners']?[0] ?? '',
        balance: json['balance'] ?? json['Balance']?['Amount'] ?? 0,
        currency: json['currency'] ?? json['Balance']?['Currency'] ?? 'EUR',
        description: json['description'] ?? json['Description'] ?? '',
      );
}

/// Compte bancaire Mangopay
class MangopayBankAccount {
  final String id;
  final String ownerName;
  final String iban;
  final bool active;

  MangopayBankAccount({
    required this.id,
    required this.ownerName,
    required this.iban,
    required this.active,
  });

  factory MangopayBankAccount.fromJson(Map<String, dynamic> json) =>
      MangopayBankAccount(
        id: json['bankAccountId'] ?? json['Id'],
        ownerName: json['ownerName'] ?? json['OwnerName'] ?? '',
        iban: json['iban'] ?? json['IBAN'] ?? '',
        active: json['active'] ?? json['Active'] ?? true,
      );
}

/// Mandat SEPA Mangopay
class MangopayMandate {
  final String id;
  final String bankAccountId;
  final String status; // CREATED, SUBMITTED, ACTIVE, FAILED
  final String? redirectUrl; // URL pour signature électronique

  MangopayMandate({
    required this.id,
    required this.bankAccountId,
    required this.status,
    this.redirectUrl,
  });

  bool get isActive => status == 'ACTIVE';
  bool get needsSignature => status == 'CREATED' && redirectUrl != null;

  factory MangopayMandate.fromJson(Map<String, dynamic> json) => MangopayMandate(
        id: json['mandateId'] ?? json['Id'],
        bankAccountId: json['bankAccountId'] ?? json['BankAccountId'] ?? '',
        status: json['status'] ?? json['Status'] ?? 'CREATED',
        redirectUrl: json['redirectUrl'] ?? json['RedirectURL'],
      );
}
