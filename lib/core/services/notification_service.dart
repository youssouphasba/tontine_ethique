import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tontetic/core/services/webhook_log_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service de gestion des Notifications RÉELLES
/// - Push: Via Firebase Cloud Messaging (FCM)
/// - SMS/Email: Via Intention Système (le user envoie avec son app)
/// - Local: Via flutter_local_notifications
class NotificationService {
  
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;

  /// Initialise le service de notifications (FCM + Local)
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Demander la permission (iOS / Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[NOTIFICATION] Permission status: ${settings.authorizationStatus}');

    // 2. Configurer les notifs locales
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // ignore: prefer_const_constructors
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // 3. Listen to Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NOTIFICATION] Message reçu en premier plan : ${message.notification?.title}');
      
      // Afficher une notification locale "Heads-up" si l'app est ouverte
      if (message.notification != null) {
        _showLocalNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'Notification',
          body: message.notification!.body ?? '',
          payload: message.data.toString(),
        );
      }
    });

    // 4. Background Message Handler (Must be static or top-level, defined in main usually)
    // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _isInitialized = true;
  }

  /// Sauvegarde le token FCM de l'utilisateur dans Firestore pour recevoir des pushs
  static Future<void> saveUserToken(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('[NOTIFICATION] Token FCM sauvegardé pour $userId');
      }
    } catch (e) {
      debugPrint('[NOTIFICATION] Erreur sauvegarde token: $e');
    }
  }

  /// Affiche une notification locale (Heads-up)
  static Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tontetic_channel', 
      'Notifications Tontetic',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ============================================================
  // ACTIONS RÉELLES (SMS / EMAIL)
  // ============================================================

  /// Ouvre l'application Email par défaut du téléphone
  static Future<bool> sendEmailProof({
    required String email,
    required WebhookLogEntry log,
  }) async {
    if (email.isEmpty) return false;

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Preuve de transaction Tontetic - ${log.id}',
        'body': 'Bonjour,\n\nVoici la preuve de votre transaction Tontetic.\n\n'
                'Réf: ${log.id}\n'
                'Montant: ${log.amount} ${log.currency}\n'
                'Statut: RÉUSSI\n\n'
                'Cordialement,\nL\'équipe Tontetic'
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
        return true;
      }
    } catch (e) {
      debugPrint("Impossible d'ouvrir l'app email: $e");
    }
    return false;
  }

  /// Ouvre l'application SMS du téléphone
  static Future<bool> sendSMSProof({
    required String phoneNumber,
    required WebhookLogEntry log,
  }) async {
    if (phoneNumber.isEmpty) return false;

    final shortId = log.id.substring(log.id.length - 6);
    final body = 'Tontetic: Paiement RECU. Ref: $shortId. Montant: ${log.amount}${log.currency}.';
    
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: <String, String>{
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
        return true;
      }
    } catch (e) {
      debugPrint("Impossible d'ouvrir l'app SMS: $e");
    }
    return false;
  }

  static String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Déclenche les actions utilisateur réelles
  static void triggerAllProofs(BuildContext context, {
    required String email,
    required String phone,
    required WebhookLogEntry log,
  }) {
    // On demande à l'utilisateur ce qu'il préfère car on ne peut pas tout ouvrir en même temps
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Envoyer la preuve via...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email'),
              subtitle: Text(email),
              onTap: () {
                Navigator.pop(ctx);
                sendEmailProof(email: email, log: log);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.green),
              title: const Text('SMS'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                sendSMSProof(phoneNumber: phone, log: log);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATIONS LOCALES / UI
  // ============================================================

  /// Affiche une alerte Snack bar (In-App)
  static void showNewMemberAlert({
    required String memberName,
    required String circleName,
  }) {
    // Cette méthode sert pour l'UI immédiate, mais le backend devrait envoyer un push aussi
    debugPrint('[EVENT] $memberName a rejoint $circleName');
  }

  /// Déclenche un push notification au créateur (via Backend Cloud Function idéalement)
  /// Ici, on ne peut que logger l'intention côté client.
  /// Le VRAI envoi se fait par le trigger Firestore `onCreate` dans les Cloud Functions.
  static void sendJoinRequestNotification({
    required String creatorId,
    required String requesterName,
    required String circleName,
  }) {
    // Note: C'est le BACKEND (Cloud Functions) qui doit écouter la création
    // du document 'join_requests' et envoyer le FCM au creatorId.
    // Le client ne fait rien ici pour éviter de "faker".
  }

  static void sendJoinApprovalNotification({
    required String requesterId,
    required String circleName,
  }) {
     // Idem: Le Backend écoute l'update du statut et envoie le push.
  }

  // Affiche un rappel local planifié (TODO: Implémenter zonedSchedule si besoin)
  static void showPotReminder({
    required BuildContext context,
    required String circleName,
    required double amount,
    required String currency,
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('N\'oubliez pas le pot de "$circleName" ($amount $currency) demain !')),
      );
    }
  }

  static void showPotReceived({
    required BuildContext context,
    required String circleName,
    required double amount,
    required String currency,
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text('Vous avez reçu $amount $currency du cercle "$circleName" !')),
      );
    }
  }

  static void showPaymentFailed({
    required BuildContext context,
    required String circleName,
    required String reason,
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Échec paiement "$circleName": $reason')),
      );
    }
  }
}

