import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/services/mobile_money_service.dart';
import 'package:tontetic/core/services/stripe_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Service de paiement "Non-Custodial".
// L'argent ne transite JAMAIS sur les comptes de Tontetic.
// Nous utilisons uniquement les API des partenaires (Wave, OM, Stripe).

class PaymentService {
  
  /// Effectue le paiement du Boost (1€ / ~655 FCFA)
  /// Retourne true si le paiement est initié/réussi.
  Future<bool> chargeBoost({
    required String? email,
    required String? userId,
    String? phone,
  }) async {
    const double amountEuro = 1.0;
    const int amountCents = 100;
    
    debugPrint('INITIATING_BOOST_PAYMENT: $amountEuro € for $email');

    if (kIsWeb) {
      // WEB: Stripe Checkout Redirect
      try {
        final checkoutUrl = await StripeService.createCheckoutSession(
          priceId: 'price_boost_1euro', // À configurer dans le dashboard Stripe
          email: email,
          userId: userId,
          planId: 'boost_sponsored',
        );
        
        final url = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return true; // Redirection lancée
        }
        return false;
      } catch (e) {
        debugPrint('WEB_BOOST_ERROR: $e');
        return false;
      }
    } else {
      // MOBILE: Stripe Payment Sheet
      try {
        return await StripeService.processPayment(
          amountCents: amountCents,
          currency: 'eur',
          description: 'Tontetic Boost - Mise en avant',
        );
      } catch (e) {
        debugPrint('MOBILE_BOOST_ERROR: $e');
        return false;
      }
    }
  }

  // Process Payment via Mobile Money Service
  Future<bool> processPayment({
    required String phoneNumber, 
    required double amount,
    String provider = 'Wave', // Default to Wave
  }) async {
    debugPrint('INITIATING_PAYMENT: $amount FCFA via $provider ($phoneNumber)');

    MobileMoneyResult result;
    
    if (provider.toLowerCase().contains('orange')) {
      result = await MobileMoneyService.initiateOrangeMoneyPayment(amount: amount, phoneNumber: phoneNumber);
    } else if (provider.toLowerCase().contains('free')) {
      result = await MobileMoneyService.initiateFreeMoneyPayment(amount: amount, phoneNumber: phoneNumber);
    } else {
      // Default Wave
      result = await MobileMoneyService.initiateWavePayment(amount: amount, phoneNumber: phoneNumber);
    }
    
    if (result.success) {
      debugPrint('PAYMENT_INITIATED: ${result.message}');
      // In a real app, we would wait for Webhook or poll status
      // For now, we return true if the API request was valid (even if pending)
      return true;
    } else {
      debugPrint('PAYMENT_FAILED: ${result.message}');
      return false;
    }
  }
  
  // Real Payout logic would go here
  // For Payouts, providers usually have a dedicated "Disbursement" API
  Future<bool> payoutToWinner({required String winnerPhone, required double amount}) async {
    debugPrint('INITIATING_PAYOUT: $amount FCFA to Winner ($winnerPhone)');
    
    // 1. Security Check
    if (amount > 1000000) {
      debugPrint('SECURITY_CHECK: Large amount, manual approval might be required.');
      // In production: Create a "Payout Request" in Firestore for Admin Approval
      return false; 
    }
    
    // 2. Execution (Placeholder for Disbursement API)
    // We don't have a Disbursement Service implemented yet in MobileMoneyService
    // So we return false to indicate "Not Implemented" instead of Fake Success
    debugPrint('PAYOUT_ERROR: Payout API not implemented yet.');
    return false;
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});
