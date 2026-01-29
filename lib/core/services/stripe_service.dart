import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service Stripe pour paiements RÉELS via Firebase Cloud Functions
/// 
/// Ce service appelle les Cloud Functions qui gèrent la Secret Key
/// de manière sécurisée côté serveur.
class StripeService {
  // ============ CONFIGURATION ============
  
  // URL des Cloud Functions (sera configurée après déploiement)
  // Format: https://us-central1-PROJECT_ID.cloudfunctions.net
  static const String _functionsBaseUrl = 
      'https://europe-west1-tontetic-admin.cloudfunctions.net';
  
  // Clé publique TEST
  static const String _publishableKeyTest = 
      'pk_test_51Sn77kCpguZvNb1UQ8Ibz8GlpkssFBHC6ob7z0AqiwBbeJE13MYeQVmasKi1OL2vT1qEzHwDTVfZ6o4GubvxsvNE00LKsvjda0';
  
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;
  static bool get isTestMode => true;
  
  /// Initialise Stripe avec la clé publique
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // WEB: Skip flutter_stripe SDK
    if (kIsWeb) {
      _isInitialized = true;
      debugPrint('[STRIPE] ✅ Mode WEB - SDK natif ignoré');
      return;
    }
    
    try {
      // Prioritize key from .env
      final envKey = dotenv.env['STRIPE_PUBLIC_KEY'];
      Stripe.publishableKey = envKey ?? _publishableKeyTest;
      Stripe.merchantIdentifier = 'merchant.com.tontetic';
      
      await Stripe.instance.applySettings();
      
      _isInitialized = true;
      debugPrint('[STRIPE] ✅ Initialisé (Mode: ${envKey?.startsWith('pk_live') == true ? 'PROD' : 'TEST'})');
    } catch (e, stack) {
      debugPrint('[STRIPE] ❌ Erreur initialisation: $e');
      rethrow;
    }
  }
  
  /// Crée un PaymentIntent via Cloud Functions (RÉEL)
  static Future<Map<String, dynamic>> createPaymentIntent({
    required int amountCents,
    String currency = 'eur',
    String description = 'Paiement Tontetic',
  }) async {
    try {
      debugPrint('[STRIPE] 📡 Appel Cloud Function: createPaymentIntent');
      debugPrint('[STRIPE] Montant: ${amountCents / 100} $currency');
      
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createPaymentIntent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountCents,
          'currency': currency,
          'description': description,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[STRIPE] ✅ PaymentIntent créé: ${data['paymentIntentId']}');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erreur serveur');
      }
    } catch (e) {
      debugPrint('[STRIPE] ❌ Erreur création PaymentIntent: $e');
      rethrow;
    }
  }
  
  /// Affiche la feuille de paiement avec un PaymentIntent réel
  /// NOTE: Cette méthode est UNIQUEMENT disponible sur Mobile (flutter_stripe SDK)
  static Future<bool> processPayment({
    required int amountCents,
    String currency = 'eur',
    String description = 'Paiement Tontetic',
  }) async {
    // WEB: Not supported - use Checkout redirect instead
    if (kIsWeb) {
      debugPrint('[STRIPE] ⚠️ processPayment() non disponible sur WEB - utiliser Checkout redirect');
      throw UnsupportedError('processPayment() n\'est pas disponible sur Web. Utilisez createCheckoutSession().');
    }
    
    if (!_isInitialized) {
      throw Exception('Stripe non initialisé');
    }
    
    try {
      // 1. Créer le PaymentIntent via Cloud Function
      final paymentData = await createPaymentIntent(
        amountCents: amountCents,
        currency: currency,
        description: description,
      );
      
      final clientSecret = paymentData['clientSecret'];
      
      // 2. Configurer la feuille de paiement
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Tontetic',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF0A1628),
            ),
          ),
        ),
      );
      
      // 3. Afficher la feuille de paiement
      await Stripe.instance.presentPaymentSheet();
      
      debugPrint('[STRIPE] ✅ Paiement réussi !');
      return true;
      
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[STRIPE] ⚠️ Paiement annulé par l\'utilisateur');
        return false;
      }
      debugPrint('[STRIPE] ❌ Erreur Stripe: ${e.error.message}');
      rethrow;
    } catch (e) {
      debugPrint('[STRIPE] ❌ Erreur: $e');
      rethrow;
    }
  }
  
  /// Initialise un mandat SEPA (prélèvement) via un SetupIntent
  /// NOTE: Cette méthode est UNIQUEMENT disponible sur Mobile (flutter_stripe SDK)
  static Future<String?> setupSepaMandate({
    required String? email,
    String? customerId,
  }) async {
    // WEB: Not supported
    if (kIsWeb) {
      debugPrint('[STRIPE] ⚠️ setupSepaMandate() non disponible sur WEB');
      throw UnsupportedError('setupSepaMandate() n\'est pas disponible sur Web.');
    }
    
    if (!_isInitialized) {
      throw Exception('Stripe non initialisé');
    }

    try {
      debugPrint('[STRIPE] 📡 Appel Cloud Function: createSetupIntent');
      
      // 1. Créer le SetupIntent via Cloud Function
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createSetupIntent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'customerId': customerId,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erreur serveur');
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];
      final stripeCustomerId = data['customerId'];

      // 2. Configurer la feuille de paiement pour un SetupIntent
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          customerId: stripeCustomerId,
          merchantDisplayName: 'Tontetic',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF0A1628),
            ),
          ),
          billingDetails: BillingDetails(
            email: email,
          ),
        ),
      );

      // 3. Afficher la feuille de paiement
      await Stripe.instance.presentPaymentSheet();
      
      debugPrint('[STRIPE] ✅ Mandat SEPA configuré avec succès !');
      
      return stripeCustomerId;
      
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[STRIPE] ⚠️ Configuration mandat annulée');
        return null;
      }
      debugPrint('[STRIPE] ❌ Erreur Stripe SEPA: ${e.error.message}');
      rethrow;
    } catch (e) {
      debugPrint('[STRIPE] ❌ Erreur SEPA: $e');
      rethrow;
    }
  }

  /// Crée une session Stripe Checkout pour un abonnement
  /// Fonctionne sur TOUTES les plateformes (Web + Mobile)
  static Future<String> createCheckoutSession({
    required String priceId,
    required String? email,
    String? customerId,
    String? successUrl,
    String? cancelUrl,
    String? userId,
    String? planId,
  }) async {
    try {
      debugPrint('[CALL_createCheckoutSession] priceId=$priceId, email=$email, userId=$userId');
      
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createCheckoutSession'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'priceId': priceId,
          'email': email,
          'customerId': customerId,
          'successUrl': successUrl ?? 'https://tontetic-app.web.app/payment/success${kIsWeb ? "?source=web" : ""}',
          'cancelUrl': cancelUrl ?? 'https://tontetic-app.web.app/payment/cancel${kIsWeb ? "?source=web" : ""}',
          'userId': userId,
          'planId': planId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['url'];
        debugPrint('[FUNCTION_OK] sessionId=${data['sessionId']}, sessionUrl=$url');
        return url;
      } else {
        final error = jsonDecode(response.body);
        debugPrint('[FUNCTION_ERROR] ${response.statusCode}: ${error['error']}');
        throw Exception(error['error'] ?? 'Erreur serveur');
      }
    } catch (e, stack) {
      debugPrint('[STRIPE] ❌ Erreur création Checkout Session: $e');
      debugPrint('[STRIPE] Stack: $stack');
      rethrow;
    }
  }

  // ============================================================
  // STRIPE CONNECT - Comptes Express pour Tontines
  // ============================================================

  /// Crée un compte Connect Express pour l'utilisateur
  static Future<String> createConnectAccount({
    required String email,
    String? userId,
    String? firstName,
    String? lastName,
  }) async {
    try {
      debugPrint('[STRIPE CONNECT] 📡 Création compte Express...');
      
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createConnectAccount'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'userId': userId,
          'firstName': firstName,
          'lastName': lastName,
          'businessType': 'individual',
          'website': 'https://tontetic-app.web.app', // For backward compat
          'business_profile': {
            'url': 'https://tontetic-app.web.app',
            'product_description': 'Organisation de cercles d\'entraide communautaire (Tontine)',
          },
          'businessDescription': 'Organisation de cercles d\'entraide communautaire (Tontine)',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[STRIPE CONNECT] ✅ Compte créé: ${data['accountId']}');
        return data['accountId'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erreur serveur');
      }
    } catch (e) {
      debugPrint('[STRIPE CONNECT] ❌ Erreur: $e');
      rethrow;
    }
  }

  /// Génère le lien d'onboarding Stripe Connect Express
  static Future<String> createConnectAccountLink({
    required String accountId,
    String? refreshUrl,
    String? returnUrl,
  }) async {
    try {
      debugPrint('[STRIPE CONNECT] 📡 Génération lien onboarding...');
      
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createConnectAccountLink'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': accountId,
          'refreshUrl': refreshUrl ?? 'https://tontetic-admin.firebaseapp.com/redirect.html?target=connect/refresh&error=true',
          'returnUrl': returnUrl ?? 'https://tontetic-admin.firebaseapp.com/redirect.html?target=connect/success',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[STRIPE CONNECT] ✅ Lien généré');
        return data['url'];
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erreur serveur');
      }
    } catch (e) {
      debugPrint('[STRIPE CONNECT] ❌ Erreur: $e');
      rethrow;
    }
  }

  /// Vérifie le statut d'un compte Connect
  static Future<Map<String, dynamic>> getConnectAccountStatus({
    required String accountId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_functionsBaseUrl/getConnectAccountStatus?accountId=$accountId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Erreur serveur');
      }
    } catch (e) {
      debugPrint('[STRIPE CONNECT] ❌ Erreur statut: $e');
      rethrow;
    }
  }

  /// Cartes de test Stripe
  static Map<String, String> get testCards => {
    'Succès': '4242 4242 4242 4242',
    'Refusée': '4000 0000 0000 0002',
    '3D Secure': '4000 0025 0000 3155',
    'Fonds insuffisants': '4000 0000 0000 9995',
  };
  
  /// Affiche les cartes de test dans les logs
  static void printTestCards() {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('       🧪 CARTES DE TEST STRIPE            ');
    debugPrint('═══════════════════════════════════════════');
    testCards.forEach((name, number) {
      debugPrint('  $name: $number');
    });
    debugPrint('  Date: N\'importe quelle date future');
    debugPrint('  CVC: N\'importe quels 3 chiffres');
    debugPrint('═══════════════════════════════════════════');
  }
}
