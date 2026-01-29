import 'package:flutter/material.dart';

class EmailService {
  static void sendWelcomeEmail(String email, String name) {
    _logEmail(
      to: email,
      subject: 'Bienvenue chez Tontetic ! 🌍',
      body: '''
Bonjour $name,

Bienvenue dans la communauté Tontetic ! Nous sommes ravis de vous compter parmi nous.
Votre compte est créé et vous pouvez dès maintenant explorer nos cercles solidaires.

Rappel de nos valeurs :
- Pas d'intérêts (0%)
- Solidarité garantie
- Transparence totale

À très vite sur l'application !
L'équipe Tontetic
      '''
    );
  }

  static void sendAccountValidatedEmail(String email) {
    _logEmail(
      to: email,
      subject: 'Compte Validé ✅',
      body: '''
Félicitations !

Vos documents ont été vérifiés et votre compte est maintenant pleinement activé.
Vous pouvez rejoindre des tontines et commencer à épargner pour vos projets.

Connectez-vous pour voir les opportunités : [Lien App]
      '''
    );
  }

  static void sendPaymentReminderEmail(String email, double amount) {
    _logEmail(
      to: email,
      subject: 'Rappel de cotisation 🔔',
      body: '''
Bonjour,

Ceci est un petit rappel amical pour votre cotisation de ${amount.toStringAsFixed(0)}.
Pour garantir le bon fonctionnement de votre cercle et maintenir votre Score d'Honneur, merci de procéder au paiement rapidement.

Rendez-vous dans votre Portefeuille.
      '''
    );
  }

  static void _logEmail({required String to, required String subject, required String body}) {
    debugPrint('--- SENDING EMAIL ---');
    debugPrint('To: $to');
    debugPrint('Subject: $subject');
    debugPrint('Body: $body');
    debugPrint('---------------------');
  }
}
