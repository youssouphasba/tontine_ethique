import 'package:flutter/material.dart';
import 'package:tontetic/core/services/webhook_log_service.dart';

/// V11.6 - Notification Service (SMS & Email)
/// Provides additional proof of transaction via external channels

class NotificationService {
  
  /// Sends a proof of transaction via Email
  static Future<bool> sendEmailProof({
    required String email,
    required WebhookLogEntry log,
  }) async {
    // In production: Use SendGrid, Mailjet, or Firebase Auth Emails
    debugPrint('[NOTIFICATION] EMAIL envoyée à $email');
    debugPrint('Sujet: Preuve de transaction Tontetic - ${log.id}');
    debugPrint('Message: Votre paiement de ${log.amount} ${log.currency} a été certifié cryptographiquement.');
    
    return true;
  }

  /// Sends a proof of transaction via SMS
  static Future<bool> sendSMSProof({
    required String phoneNumber,
    required WebhookLogEntry log,
  }) async {
    // In production: Use Twilio, Vonage, or local African SMS gateways (e.g. Orange SMS API)
    final shortId = log.id.substring(log.id.length - 6);
    final message = 'Tontetic: Paiement RECU. Ref: $shortId. Montant: ${log.amount}${log.currency}. Preuve technique dispo dans l\'app.';
    
    debugPrint('[NOTIFICATION] SMS envoyé à $phoneNumber');
    debugPrint('Message: $message');

    return true;
  }

  /// Global static method to trigger proofs after a successful transaction
  static void triggerAllProofs(BuildContext context, {
    required String email,
    required String phone,
    required WebhookLogEntry log,
  }) {
    sendEmailProof(email: email, log: log).then((success) {
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preuve envoyée par Email 📧'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    sendSMSProof(phoneNumber: phone, log: log).then((success) {
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preuve envoyée par SMS 📱'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// V10.1: Displays an alert when a new member joins a circle
  static void showNewMemberAlert({
    required String memberName,
    required String circleName,
  }) {
    debugPrint('[NOTIFICATION] Alerte : $memberName a rejoint le cercle "$circleName" ! 🎉');
    // In a real app: Trigger local notification or FCM push
  }

  // ============================================================
  // V18: Pot-specific Notifications
  // ============================================================

  /// Shows a pot reminder notification (24h before pot collection)
  static void showPotReminder({
    required BuildContext context,
    required String circleName,
    required double amount,
    required String currency,
  }) {
    debugPrint('[NOTIFICATION] ⏰ Pot demain pour "$circleName" - $amount$currency');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alarm, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Pot de "$circleName" demain ! Préparez $amount$currency'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Shows a pot received celebration notification
  static void showPotReceived({
    required BuildContext context,
    required String circleName,
    required double amount,
    required String currency,
  }) {
    debugPrint('[NOTIFICATION] 🎉 Pot reçu ! "$circleName" - $amount$currency');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Félicitations !', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Vous avez reçu $amount$currency de "$circleName"'),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  /// Shows a payment failed alert notification
  static void showPaymentFailed({
    required BuildContext context,
    required String circleName,
    required String reason,
  }) {
    debugPrint('[NOTIFICATION] ⚠️ Paiement échoué pour "$circleName": $reason');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Échec de prélèvement', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('$circleName - $reason'),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'VOIR',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to payment history or wallet
            },
          ),
        ),
      );
    }
  }

  /// Shows a local notification for pot events (when app is in background)
  static Future<void> showLocalPotNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // In production: use flutter_local_notifications
    debugPrint('[LOCAL NOTIFICATION] $title: $body');
    // await flutterLocalNotificationsPlugin.show(...)
  }
}
