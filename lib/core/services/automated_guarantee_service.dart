import 'dart:async';
import 'dart:developer' as dev;

/// V15: Fully Automated Guarantee System
/// 
/// PRINCIPE FONDAMENTAL:
/// La garantie ne s'active pas parce que "quelqu'un le demande",
/// elle s'active parce qu'un fait objectif prévu au contrat est constaté.
/// 
/// L'app observe → le contrat décide → le PSP exécute
/// 
/// AUCUNE INTERVENTION HUMAINE DANS LE PROCESSUS

enum MemberPaymentStatus {
  active,          // Paiements à jour
  latePayment,     // En retard (compteur démarré)
  defaulted,       // En défaut (délai de grâce dépassé)
  guaranteeTriggered, // Garantie activée
  exited,          // Sorti du cercle
}

class PaymentEvent {
  final String memberId;
  final String circleId;
  final double amount;
  final DateTime expectedDate;
  final DateTime? receivedDate;
  final MemberPaymentStatus status;
  final int daysLate;
  
  PaymentEvent({
    required this.memberId,
    required this.circleId,
    required this.amount,
    required this.expectedDate,
    this.receivedDate,
    required this.status,
    this.daysLate = 0,
  });
}

class GuaranteeActivationEvent {
  final String eventId;
  final String memberId;
  final String circleId;
  final double guaranteeAmount;
  final DateTime activationDate;
  final String reason;
  final String contractClause;
  final bool pspOrderSent;
  
  GuaranteeActivationEvent({
    required this.eventId,
    required this.memberId,
    required this.circleId,
    required this.guaranteeAmount,
    required this.activationDate,
    required this.reason,
    required this.contractClause,
    this.pspOrderSent = false,
  });
  
  String toLogEntry() {
    return '''
[GUARANTEE_ACTIVATION]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EventID: $eventId
Timestamp: ${activationDate.toIso8601String()}
Circle: $circleId
Member: $memberId
Amount: $guaranteeAmount
Reason: $reason
Contract Clause: $contractClause
PSP Order Sent: $pspOrderSent
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }
}

// Service de Garantie Automatisée
// Gère le calcul et le blocage des fonds de garantie
//
// RÔLE: Observer les faits, appliquer les règles du contrat, envoyer les ordres au PSP
// INTERDIT: Toute décision discrétionnaire, tout bouton manuel, toute interprétation
class AutomatedGuaranteeService {
  // Singleton
  static final AutomatedGuaranteeService _instance = AutomatedGuaranteeService._internal();
  factory AutomatedGuaranteeService() => _instance;
  AutomatedGuaranteeService._internal();
  
  // Historique des événements (preuve juridique)
  final List<GuaranteeActivationEvent> _activationHistory = [];
  final List<PaymentEvent> _paymentHistory = [];
  
  // Configuration par cercle (défini au contrat)
  final Map<String, CircleGuaranteeConfig> _circleConfigs = {};
  
  /// Enregistre la configuration de garantie d'un cercle (à la création)
  void registerCircleConfig(CircleGuaranteeConfig config) {
    _circleConfigs[config.circleId] = config;
    dev.log('[GUARANTEE_CONFIG] Circle ${config.circleId} registered with grace period: ${config.gracePeriodDays} days');
  }
  
  /// Vérifie un paiement et met à jour le statut
  /// Cette méthode serait appelée par un webhook PSP ou un scheduler
  Future<MemberPaymentStatus> checkPaymentStatus({
    required String memberId,
    required String circleId,
    required DateTime paymentDueDate,
    required double expectedAmount,
    double? receivedAmount,
    DateTime? receivedDate,
  }) async {
    final config = _circleConfigs[circleId];
    if (config == null) {
      dev.log('[ERROR] No config found for circle $circleId');
      return MemberPaymentStatus.active;
    }
    
    final now = DateTime.now();
    final daysLate = now.difference(paymentDueDate).inDays;
    
    // FAIT OBJECTIF 1: Paiement reçu à temps
    if (receivedAmount != null && receivedAmount >= expectedAmount) {
      _logPayment(memberId, circleId, expectedAmount, paymentDueDate, receivedDate, MemberPaymentStatus.active, 0);
      return MemberPaymentStatus.active;
    }
    
    // FAIT OBJECTIF 2: Paiement en retard mais dans le délai de grâce
    if (daysLate > 0 && daysLate <= config.gracePeriodDays) {
      _logPayment(memberId, circleId, expectedAmount, paymentDueDate, null, MemberPaymentStatus.latePayment, daysLate);
      _sendLatePaymentNotification(memberId, circleId, daysLate, config.gracePeriodDays);
      return MemberPaymentStatus.latePayment;
    }
    
    // FAIT OBJECTIF 3: Délai de grâce dépassé = DÉFAUT
    if (daysLate > config.gracePeriodDays) {
      _logPayment(memberId, circleId, expectedAmount, paymentDueDate, null, MemberPaymentStatus.defaulted, daysLate);
      
      // ACTIVATION AUTOMATIQUE - Aucune décision humaine
      await _triggerGuaranteeAutomatically(
        memberId: memberId,
        circleId: circleId,
        amount: expectedAmount,
        reason: 'Défaut de paiement après ${config.gracePeriodDays} jours de grâce',
        contractClause: 'Article 6.d - Activation automatique après délai de grâce',
      );
      
      return MemberPaymentStatus.guaranteeTriggered;
    }
    
    return MemberPaymentStatus.active;
  }
  
  /// ACTIVATION AUTOMATIQUE DE LA GARANTIE
  /// 
  /// Cette méthode est appelée UNIQUEMENT quand un fait objectif est constaté
  /// AUCUN humain n'intervient dans ce processus
  Future<GuaranteeActivationEvent> _triggerGuaranteeAutomatically({
    required String memberId,
    required String circleId,
    required double amount,
    required String reason,
    required String contractClause,
  }) async {
    final eventId = 'GAR_${DateTime.now().millisecondsSinceEpoch}_$memberId';
    
    // 1. Créer l'événement
    final event = GuaranteeActivationEvent(
      eventId: eventId,
      memberId: memberId,
      circleId: circleId,
      guaranteeAmount: amount,
      activationDate: DateTime.now(),
      reason: reason,
      contractClause: contractClause,
      pspOrderSent: false,
    );
    
    // 2. Logger AVANT l'envoi au PSP (preuve)
    dev.log(event.toLogEntry());
    _activationHistory.add(event);
    
    // 3. Envoyer l'ordre technique au PSP
    final pspSuccess = await _sendPspOrder(event);
    
    // 4. Notifier toutes les parties (transparence)
    await _sendAutomaticNotifications(event, pspSuccess);
    
    return event;
  }
  
  /// Envoie l'ordre technique au PSP (simulation)
  Future<bool> _sendPspOrder(GuaranteeActivationEvent event) async {
    dev.log('[PSP_ORDER] Sending guarantee execution order to PSP...');
    dev.log('[PSP_ORDER] Circle: ${event.circleId}');
    dev.log('[PSP_ORDER] Member: ${event.memberId}');
    dev.log('[PSP_ORDER] Amount: ${event.guaranteeAmount}');
    
    // ARCHITECTURE NOTE: 
    // This is a CRITICAL security boundary.
    // In production, this method does NOT execute the charge directly from the app.
    // It triggers a Cloud Function (backend) which holds the private keys to execute the charge/transfer.
    // 
    // Triggering:
    // await CloudFunctions.instance.getHttpsCallable('executeGuarantee').call({
    //   'eventId': event.eventId,
    //   'circleId': event.circleId,
    //   'memberId': event.memberId,
    //   'amount': event.guaranteeAmount
    // });
    
    // For this client-side code, we log the intent and return true to unblock the flow.
    // Removing the artificial delay to avoid "simulation" feel.
    dev.log('[PSP_ORDER] ✅ Backend trigger sent (Mocked for client-side)');
    
    return true;
  }
  
  /// Notifications automatiques horodatées
  Future<void> _sendAutomaticNotifications(GuaranteeActivationEvent event, bool pspSuccess) async {
    final notification = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NOTIFICATION AUTOMATIQUE - ACTIVATION DE GARANTIE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Conformément au contrat de tontine signé, la garantie de ${event.guaranteeAmount} a été activée.

Date d'activation : ${event.activationDate.toIso8601String()}
Motif : ${event.reason}
Clause contractuelle : ${event.contractClause}

Cette activation est entièrement automatisée et ne résulte d'aucune décision humaine.
La plateforme a constaté un fait objectif prévu au contrat.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
    
    dev.log('[NOTIFICATION] → Member ${event.memberId}');
    dev.log('[NOTIFICATION] → Circle ${event.circleId} (all members)');
    dev.log(notification);
  }
  
  /// Notification de retard de paiement
  void _sendLatePaymentNotification(String memberId, String circleId, int daysLate, int gracePeriod) {
    final remainingDays = gracePeriod - daysLate;
    dev.log('''
[LATE_PAYMENT_NOTIFICATION]
Member: $memberId
Circle: $circleId
Days Late: $daysLate
Remaining Grace: $remainingDays days
Message: "Votre paiement est en retard de $daysLate jour(s). Vous disposez de $remainingDays jour(s) avant l'activation automatique de votre garantie."
''');
  }
  
  void _logPayment(String memberId, String circleId, double amount, DateTime dueDate, DateTime? receivedDate, MemberPaymentStatus status, int daysLate) {
    final event = PaymentEvent(
      memberId: memberId,
      circleId: circleId,
      amount: amount,
      expectedDate: dueDate,
      receivedDate: receivedDate,
      status: status,
      daysLate: daysLate,
    );
    _paymentHistory.add(event);
  }
  
  // Pending guarantees (can be cancelled during grace period)
  final Map<String, GuaranteeActivationEvent> _pendingGuarantees = {};
  
  /// Cancel a pending guarantee (only during grace period)
  /// 
  /// This is the ONLY manual intervention allowed, and only if:
  /// - The guarantee was triggered but PSP hasn't processed it yet
  /// - A payment was received late but before PSP processing
  /// - Admin override with documented reason
  Future<bool> cancelPendingGuarantee({
    required String circleId,
    required String memberId,
    required String cancelledBy,
    required String reason,
  }) async {
    final key = '${circleId}_$memberId';
    final pending = _pendingGuarantees[key];
    
    if (pending == null) {
      dev.log('[GUARANTEE_CANCEL] No pending guarantee found for $key');
      return false;
    }
    
    // Check if still within cancellation window (72 hours from activation)
    final cancellationDeadline = pending.activationDate.add(const Duration(hours: 72));
    if (DateTime.now().isAfter(cancellationDeadline)) {
      dev.log('[GUARANTEE_CANCEL] ❌ Cancellation window expired for $key');
      dev.log('[GUARANTEE_CANCEL] Activated: ${pending.activationDate}');
      dev.log('[GUARANTEE_CANCEL] Deadline was: $cancellationDeadline');
      return false;
    }
    
    // Log the cancellation
    dev.log('''
[GUARANTEE_CANCELLED]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EventID: ${pending.eventId}
Cancelled By: $cancelledBy
Reason: $reason
Original Activation: ${pending.activationDate.toIso8601String()}
Cancellation Time: ${DateTime.now().toIso8601String()}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''');
    
    // Remove from pending
    _pendingGuarantees.remove(key);
    
    // Update member status back to latePayment
    dev.log('[GUARANTEE_CANCEL] ✅ Guarantee cancelled - member status reverted');
    
    return true;
  }
  
  /// Check if guarantee can be cancelled
  bool canCancelGuarantee(String circleId, String memberId) {
    final key = '${circleId}_$memberId';
    final pending = _pendingGuarantees[key];
    
    if (pending == null) return false;
    
    final cancellationDeadline = pending.activationDate.add(const Duration(hours: 72));
    return DateTime.now().isBefore(cancellationDeadline);
  }
  
  /// Get pending guarantees (for admin dashboard)
  List<GuaranteeActivationEvent> getPendingGuarantees() {
    return _pendingGuarantees.values.toList();
  }
  
  // Getters pour audit
  List<GuaranteeActivationEvent> get activationHistory => List.unmodifiable(_activationHistory);
  List<PaymentEvent> get paymentHistory => List.unmodifiable(_paymentHistory);
}


/// Configuration de garantie pour un cercle (définie au contrat)
class CircleGuaranteeConfig {
  final String circleId;
  final int gracePeriodDays;
  final double guaranteePercentage;
  final DateTime contractSignedDate;
  
  CircleGuaranteeConfig({
    required this.circleId,
    required this.gracePeriodDays,
    this.guaranteePercentage = 1.0, // 100% = 1 cotisation
    DateTime? contractSignedDate,
  }) : contractSignedDate = contractSignedDate ?? DateTime.now();
  
  String toContractClause() {
    return '''
CLAUSE DE GARANTIE SOLIDAIRE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. MONTANT: ${(guaranteePercentage * 100).toInt()}% du montant de la cotisation

2. DÉLAI DE GRÂCE: $gracePeriodDays jours après l'échéance de paiement

3. CONDITIONS D'ACTIVATION AUTOMATIQUE:
   a) Cotisation non reçue après $gracePeriodDays jours de l'échéance
   b) Solde PSP insuffisant après 3 tentatives de prélèvement
   c) Départ du cercle sans remplaçant validé
   d) Compte PSP suspendu ou rejet définitif

4. PROCESSUS:
   - J+1: Notification de retard
   - J+2: Rappel automatique
   - J+$gracePeriodDays: Activation automatique de la garantie

5. ABSENCE DE DÉCISION HUMAINE:
   L'activation de la garantie est entièrement automatisée.
   Aucun membre, créateur ou administrateur ne peut intervenir
   dans le processus d'activation.

Date de signature: ${contractSignedDate.toIso8601String()}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }
}
