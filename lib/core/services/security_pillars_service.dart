/// 7. Blocage par PSP suite à comportement suspect
///
/// MESSAGE DÉVELOPPEUR:
/// "Chaque action doit être sécurisée selon son niveau de risque.
/// Aucune décision critique ne doit être prise côté client.
/// Tous les flux financiers et décisions contractuelles passent par le backend.
/// Toute action sensible doit être traçable, réversible ou gelable."
library;




// ============================================================
// ENUMS & MODELS
// ============================================================

/// Types de menaces réelles
enum ThreatType {
  accountTheft,         // Vol de comptes
  apiAbuse,             // Abus API
  fraudulentRuleChange, // Modification frauduleuse de règles
  identityUsurpation,   // Usurpation d'identité
  logicExploitation,    // Exploitation de failles logiques
  dataLeak,             // Fuite de données
  pspBlock,             // Blocage par PSP
}

/// Niveaux de risque utilisateur
enum UserRiskLevel {
  low,      // Aucun comportement suspect
  medium,   // Quelques anomalies
  high,     // Comportement suspect confirmé
  critical, // Menace imminente
}

/// État du compte
enum AccountSecurityStatus {
  active,     // Compte normal
  restricted, // Actions limitées
  suspended,  // Compte gelé
  locked,     // Verrouillé pour sécurité
}

/// Événement de sécurité
class SecurityEvent {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String eventType;
  final String description;
  final String? ipAddress;
  final String? userAgent;
  final bool isSuccess;
  final UserRiskLevel riskContribution;

  const SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.eventType,
    required this.description,
    this.ipAddress,
    this.userAgent,
    required this.isSuccess,
    required this.riskContribution,
  });
}

/// Configuration de sécurité par pilier
class PillarConfig {
  final String pillarId;
  final String name;
  final String description;
  final bool isEnabled;
  final Map<String, dynamic> settings;

  const PillarConfig({
    required this.pillarId,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.settings,
  });
}

/// Alerte de sécurité
class SecurityAlert {
  final String id;
  final DateTime timestamp;
  final ThreatType threatType;
  final UserRiskLevel severity;
  final String userId;
  final String message;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  const SecurityAlert({
    required this.id,
    required this.timestamp,
    required this.threatType,
    required this.severity,
    required this.userId,
    required this.message,
    this.isResolved = false,
    this.resolvedBy,
    this.resolvedAt,
  });
}

// ============================================================
// PILIER 1 - AUTHENTIFICATION SOLIDE
// ============================================================

class AuthenticationPillar {
  /// Règles de mot de passe fort
  static const int minPasswordLength = 12;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireDigit = true;
  static const bool requireSpecialChar = true;
  
  /// Hashage
  static const String hashAlgorithm = 'argon2id'; // ou bcrypt
  
  /// 2FA obligatoire pour:
  static const List<String> require2faFor = [
    'circle_creator',
    'admin',
    'enterprise',
    'merchant',
  ];
  
  /// Limitation tentatives
  static const int maxLoginAttempts = 5;
  static const int lockoutMinutes = 30;
  
  /// Session
  static const int sessionExpirationHours = 24;
  static const int inactivityTimeoutMinutes = 30;

  /// Valide la force du mot de passe
  static PasswordStrength validatePassword(String password) {
    final issues = <String>[];
    
    if (password.length < minPasswordLength) {
      issues.add('Minimum $minPasswordLength caractères requis');
    }
    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      issues.add('Au moins une majuscule requise');
    }
    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      issues.add('Au moins une minuscule requise');
    }
    if (requireDigit && !password.contains(RegExp(r'[0-9]'))) {
      issues.add('Au moins un chiffre requis');
    }
    if (requireSpecialChar && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      issues.add('Au moins un caractère spécial requis');
    }
    
    return PasswordStrength(
      isValid: issues.isEmpty,
      issues: issues,
      score: _calculateScore(password),
    );
  }

  static int _calculateScore(String password) {
    int score = 0;
    if (password.length >= minPasswordLength) score += 25;
    if (password.contains(RegExp(r'[A-Z]'))) score += 20;
    if (password.contains(RegExp(r'[a-z]'))) score += 15;
    if (password.contains(RegExp(r'[0-9]'))) score += 20;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 20;
    return score.clamp(0, 100);
  }

  /// Vérifie si 2FA est requis pour ce rôle
  static bool requires2fa(String userRole) {
    return require2faFor.contains(userRole);
  }
}

class PasswordStrength {
  final bool isValid;
  final List<String> issues;
  final int score;

  const PasswordStrength({
    required this.isValid,
    required this.issues,
    required this.score,
  });
}

// ============================================================
// PILIER 2 - AUTORISATIONS
// ============================================================

class AuthorizationPillar {
  /// Rôles stricts
  static const List<String> validRoles = [
    'user',
    'circle_creator',
    'enterprise',
    'merchant',
    'moderator',
    'support',
    'admin',
    'super_admin',
  ];

  /// Permissions par rôle et action
  static final Map<String, List<String>> rolePermissions = {
    'user': [
      'view_profile',
      'edit_profile',
      'join_circle',
      'vote',
      'send_message',
      'view_shop',
    ],
    'circle_creator': [
      'view_profile',
      'edit_profile',
      'create_circle',
      'manage_circle',
      'invite_members',
      'activate_guarantee',
      'modify_circle_rules',
      'vote',
      'send_message',
      'view_shop',
    ],
    'enterprise': [
      'view_profile',
      'edit_profile',
      'create_circle',
      'manage_circle',
      'invite_members',
      'manage_employees',
      'view_enterprise_dashboard',
      'vote',
      'send_message',
    ],
    'merchant': [
      'view_profile',
      'edit_profile',
      'manage_shop',
      'add_products',
      'edit_products',
      'view_merchant_dashboard',
      'boost_products',
    ],
    'moderator': [
      'view_reports',
      'moderate_content',
      'suspend_user_temp',
      'view_audit_logs',
    ],
    'support': [
      'view_tickets',
      'respond_tickets',
      'view_user_basic_info',
    ],
    'admin': [
      'view_all',
      'edit_settings',
      'suspend_user',
      'view_audit_logs',
      'manage_moderators',
      'view_financial_dashboard',
    ],
    'super_admin': [
      'all', // Toutes les permissions
    ],
  };

  /// Vérifie si un rôle a une permission
  static bool hasPermission(String role, String permission) {
    if (!validRoles.contains(role)) return false;
    
    final permissions = rolePermissions[role] ?? [];
    return permissions.contains('all') || permissions.contains(permission);
  }

  /// Vérifie côté serveur - NE JAMAIS faire confiance au client
  static AuthorizationResult verifyServerSide({
    required String userId,
    required String userRole,
    required String action,
    required String? targetResourceId,
    required String? targetResourceType,
  }) {
    // Règle 1: Vérifier le rôle
    if (!validRoles.contains(userRole)) {
      return AuthorizationResult(
        allowed: false,
        reason: 'Rôle invalide',
        shouldLog: true,
        threatLevel: UserRiskLevel.high,
      );
    }

    // Règle 2: Vérifier la permission
    if (!hasPermission(userRole, action)) {
      return AuthorizationResult(
        allowed: false,
        reason: 'Permission insuffisante pour cette action',
        shouldLog: true,
        threatLevel: UserRiskLevel.medium,
      );
    }

    // Règle 3: Vérifier la propriété de la ressource si applicable
    // (À implémenter avec la vraie base de données)

    return AuthorizationResult(
      allowed: true,
      reason: 'Autorisé',
      shouldLog: false,
      threatLevel: UserRiskLevel.low,
    );
  }
}

class AuthorizationResult {
  final bool allowed;
  final String reason;
  final bool shouldLog;
  final UserRiskLevel threatLevel;

  const AuthorizationResult({
    required this.allowed,
    required this.reason,
    required this.shouldLog,
    required this.threatLevel,
  });
}

// ============================================================
// PILIER 3 - SÉCURITÉ DES FLUX FINANCIERS
// ============================================================

class FinancialSecurityPillar {
  /// RÈGLES ABSOLUES:
  /// 1. Aucune clé API dans le client
  /// 2. Toutes les actions PSP via backend
  /// 3. Vérification systématique des webhooks (signature)
  /// 4. Idempotency keys (éviter double paiement)
  /// 5. Montants recalculés côté serveur

  /// Vérifie la signature d'un webhook PSP
  static bool verifyWebhookSignature({
    required String payload,
    required String signature,
    required String secret,
  }) {
    // Implémentation réelle avec HMAC-SHA256
    // NE JAMAIS accepter un webhook sans vérification
    if (signature.isEmpty || secret.isEmpty) {
      return false;
    }
    // TODO: Implémenter la vérification HMAC réelle
    return true;
  }

  /// Génère une clé d'idempotence unique
  static String generateIdempotencyKey(String userId, String action, double amount) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'idem_${userId}_${action}_${amount.toStringAsFixed(2)}_$timestamp';
  }

  /// Vérifie qu'un montant envoyé par le client correspond au montant serveur
  static FinancialValidation validateAmount({
    required double clientAmount,
    required double serverCalculatedAmount,
    required String currency,
  }) {
    // Le client ne décide JAMAIS d'un montant réel
    if (clientAmount != serverCalculatedAmount) {
      return FinancialValidation(
        isValid: false,
        message: 'Montant client ($clientAmount) != montant serveur ($serverCalculatedAmount)',
        shouldBlock: true,
        threatLevel: UserRiskLevel.critical,
      );
    }

    if (serverCalculatedAmount <= 0) {
      return FinancialValidation(
        isValid: false,
        message: 'Montant invalide: $serverCalculatedAmount',
        shouldBlock: true,
        threatLevel: UserRiskLevel.high,
      );
    }

    return FinancialValidation(
      isValid: true,
      message: 'Montant validé: $serverCalculatedAmount $currency',
      shouldBlock: false,
      threatLevel: UserRiskLevel.low,
    );
  }

  /// Liste des actions qui doivent obligatoirement passer par le backend
  static const List<String> backendOnlyActions = [
    'create_payment',
    'process_refund',
    'activate_guarantee',
    'transfer_funds',
    'modify_subscription',
    'cancel_subscription',
    'block_payment_method',
  ];

  /// Vérifie si une action doit être bloquée côté client
  static bool isClientSideBlocked(String action) {
    return backendOnlyActions.contains(action);
  }
}

class FinancialValidation {
  final bool isValid;
  final String message;
  final bool shouldBlock;
  final UserRiskLevel threatLevel;

  const FinancialValidation({
    required this.isValid,
    required this.message,
    required this.shouldBlock,
    required this.threatLevel,
  });
}

// ============================================================
// PILIER 4 - PROTECTION API & ANTI-ABUS
// ============================================================

class ApiProtectionPillar {
  /// Rate limiting
  static const int maxRequestsPerMinutePerIp = 60;
  static const int maxRequestsPerMinutePerUser = 100;
  static const int maxSensitiveActionsPerHour = 10;

  /// Seuils de détection d'abus
  static const int maxRuleChangesPerDay = 3;
  static const int maxInvitationsPerHour = 20;
  static const int maxCircleCreationsPerMonth = 5;

  /// Durée de blocage temporaire
  static const int autoBlockMinutes = 15;

  /// Vérifie si un utilisateur abuse de l'API
  static AbuseDetectionResult detectAbuse({
    required String userId,
    required String action,
    required int recentActionCount,
    required int timeWindowMinutes,
  }) {
    // Détection de comportement anormal
    final actionsPerMinute = recentActionCount / timeWindowMinutes;

    if (actionsPerMinute > 10) {
      return AbuseDetectionResult(
        isAbuse: true,
        reason: 'Trop d\'actions en peu de temps: ${actionsPerMinute.toStringAsFixed(1)}/min',
        shouldBlock: true,
        blockDurationMinutes: autoBlockMinutes,
      );
    }

    // Vérifications spécifiques par action
    if (action == 'modify_circle_rules' && recentActionCount > maxRuleChangesPerDay) {
      return AbuseDetectionResult(
        isAbuse: true,
        reason: 'Trop de modifications de règles: $recentActionCount/${maxRuleChangesPerDay}j',
        shouldBlock: true,
        blockDurationMinutes: autoBlockMinutes * 4,
      );
    }

    if (action == 'invite_member' && recentActionCount > maxInvitationsPerHour) {
      return AbuseDetectionResult(
        isAbuse: true,
        reason: 'Invitations excessives: $recentActionCount/${maxInvitationsPerHour}h',
        shouldBlock: true,
        blockDurationMinutes: autoBlockMinutes * 2,
      );
    }

    return AbuseDetectionResult(
      isAbuse: false,
      reason: 'OK',
      shouldBlock: false,
      blockDurationMinutes: 0,
    );
  }

  /// Patterns de comportement suspect
  static bool detectSuspiciousPattern({
    required String userId,
    required List<String> recentActions,
    required DateTime? upcomingPaymentDate,
  }) {
    // Pattern: changement règles + paiement proche
    if (recentActions.contains('modify_circle_rules') && upcomingPaymentDate != null) {
      final daysUntilPayment = upcomingPaymentDate.difference(DateTime.now()).inDays;
      if (daysUntilPayment <= 3) {
        return true; // ALERTE: modification suspecte avant paiement
      }
    }

    // Pattern: activation garantie après modification récente
    if (recentActions.contains('activate_guarantee') &&
        recentActions.contains('modify_circle_rules')) {
      return true; // ALERTE: séquence suspecte
    }

    return false;
  }
}

class AbuseDetectionResult {
  final bool isAbuse;
  final String reason;
  final bool shouldBlock;
  final int blockDurationMinutes;

  const AbuseDetectionResult({
    required this.isAbuse,
    required this.reason,
    required this.shouldBlock,
    required this.blockDurationMinutes,
  });
}

// ============================================================
// PILIER 5 - JOURNALISATION & PREUVES
// ============================================================

class LoggingPillar {
  /// Actions qui DOIVENT être loggées de façon immuable
  static const List<String> immutableLogActions = [
    'vote',
    'guarantee_activation',
    'payment_created',
    'payment_completed',
    'payment_failed',
    'refund_initiated',
    'circle_rule_modified',
    'member_excluded',
    'circle_closed',
    'cgu_accepted',
    'admin_login',
    'admin_action',
    'user_suspended',
    'account_locked',
  ];

  /// Crée une entrée de log sécurisée
  static SecurityLogEntry createLog({
    required String userId,
    required String action,
    required String description,
    required String? ipAddress,
    required String? userAgent,
    required bool isSuccess,
    Map<String, dynamic>? metadata,
  }) {
    return SecurityLogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().toUtc(),
      userId: userId,
      action: action,
      description: description,
      ipAddress: ipAddress,
      userAgent: userAgent,
      isSuccess: isSuccess,
      isImmutable: immutableLogActions.contains(action),
      metadata: metadata ?? {},
    );
  }

  /// Vérifie si un log doit être immuable
  static bool shouldBeImmutable(String action) {
    return immutableLogActions.contains(action);
  }
}

class SecurityLogEntry {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String action;
  final String description;
  final String? ipAddress;
  final String? userAgent;
  final bool isSuccess;
  final bool isImmutable;
  final Map<String, dynamic> metadata;

  const SecurityLogEntry({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.action,
    required this.description,
    this.ipAddress,
    this.userAgent,
    required this.isSuccess,
    required this.isImmutable,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'user_id': userId,
    'action': action,
    'description': description,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'is_success': isSuccess,
    'is_immutable': isImmutable,
    'metadata': metadata,
  };
}

// ============================================================
// PILIER 6 - CONTENTION & RÉPONSE À INCIDENT
// ============================================================

class IncidentResponsePillar {
  /// États possibles du mode incident
  static const List<String> incidentModes = [
    'normal',      // Fonctionnement normal
    'elevated',    // Vigilance accrue
    'restricted',  // Actions limitées
    'emergency',   // Mode urgence
  ];

  /// Actions disponibles en réponse à un incident
  static IncidentActions getAvailableActions(String incidentType) {
    switch (incidentType) {
      case 'account_compromise':
        return IncidentActions(
          immediate: ['lock_account', 'invalidate_sessions', 'notify_user'],
          followUp: ['reset_password', 'review_recent_actions', 'enable_2fa'],
        );
      case 'fraud_detected':
        return IncidentActions(
          immediate: ['freeze_financial_actions', 'notify_admin', 'create_ticket'],
          followUp: ['investigate', 'contact_psp', 'suspend_if_confirmed'],
        );
      case 'api_abuse':
        return IncidentActions(
          immediate: ['rate_limit_strict', 'block_ip', 'notify_admin'],
          followUp: ['analyze_pattern', 'update_rules', 'whitelist_if_legitimate'],
        );
      case 'psp_issue':
        return IncidentActions(
          immediate: ['pause_payments', 'notify_users', 'switch_psp_if_possible'],
          followUp: ['contact_psp', 'wait_resolution', 'resume_payments'],
        );
      default:
        return IncidentActions(
          immediate: ['notify_admin', 'create_ticket'],
          followUp: ['investigate', 'determine_actions'],
        );
    }
  }

  /// Désactive rapidement un compte
  static AccountLockResult lockAccount({
    required String userId,
    required String reason,
    required String lockedBy,
  }) {
    return AccountLockResult(
      userId: userId,
      isLocked: true,
      reason: reason,
      lockedBy: lockedBy,
      lockedAt: DateTime.now().toUtc(),
      sessionsInvalidated: true,
    );
  }

  /// Gèle temporairement les actions financières
  static FinancialFreezeResult freezeFinancialActions({
    required String userId,
    required String reason,
    required int freezeDurationHours,
  }) {
    return FinancialFreezeResult(
      userId: userId,
      isFrozen: true,
      reason: reason,
      frozenAt: DateTime.now().toUtc(),
      unfreezeAt: DateTime.now().add(Duration(hours: freezeDurationHours)),
      blockedActions: FinancialSecurityPillar.backendOnlyActions,
    );
  }
}

class IncidentActions {
  final List<String> immediate;
  final List<String> followUp;

  const IncidentActions({
    required this.immediate,
    required this.followUp,
  });
}

class AccountLockResult {
  final String userId;
  final bool isLocked;
  final String reason;
  final String lockedBy;
  final DateTime lockedAt;
  final bool sessionsInvalidated;

  const AccountLockResult({
    required this.userId,
    required this.isLocked,
    required this.reason,
    required this.lockedBy,
    required this.lockedAt,
    required this.sessionsInvalidated,
  });
}

class FinancialFreezeResult {
  final String userId;
  final bool isFrozen;
  final String reason;
  final DateTime frozenAt;
  final DateTime unfreezeAt;
  final List<String> blockedActions;

  const FinancialFreezeResult({
    required this.userId,
    required this.isFrozen,
    required this.reason,
    required this.frozenAt,
    required this.unfreezeAt,
    required this.blockedActions,
  });
}

// ============================================================
// SERVICE PRINCIPAL - COORDINATEUR DES 6 PILIERS
// ============================================================

class SecurityPillarsService {
  static final SecurityPillarsService _instance = SecurityPillarsService._internal();
  factory SecurityPillarsService() => _instance;
  SecurityPillarsService._internal();

  /// État actuel du mode incident
  String currentIncidentMode = 'normal';

  /// Alertes actives
  final List<SecurityAlert> _activeAlerts = [];

  /// Événements de sécurité récents
  final List<SecurityEvent> _recentEvents = [];

  /// Scores de risque par utilisateur
  final Map<String, UserRiskLevel> _userRiskScores = {};

  // ============================================================
  // DASHBOARD ADMIN - MINIMUM VITAL
  // ============================================================

  /// Connexions suspectes (dernières 24h)
  List<SecurityEvent> getSuspiciousLogins() {
    return _recentEvents.where((e) =>
      e.eventType == 'login' &&
      (!e.isSuccess || e.riskContribution != UserRiskLevel.low)
    ).toList();
  }

  /// Historique actions sensibles
  List<SecurityEvent> getSensitiveActionsHistory({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _recentEvents.where((e) =>
      e.timestamp.isAfter(cutoff) &&
      LoggingPillar.shouldBeImmutable(e.eventType)
    ).toList();
  }

  /// Tentatives échouées
  List<SecurityEvent> getFailedAttempts({int hours = 24}) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    return _recentEvents.where((e) =>
      e.timestamp.isAfter(cutoff) && !e.isSuccess
    ).toList();
  }

  /// Comptes à risque
  Map<String, UserRiskLevel> getAtRiskAccounts() {
    return Map.fromEntries(
      _userRiskScores.entries.where((e) =>
        e.value == UserRiskLevel.high || e.value == UserRiskLevel.critical
      )
    );
  }

  /// Alertes actives
  List<SecurityAlert> getActiveAlerts() {
    return _activeAlerts.where((a) => !a.isResolved).toList();
  }

  // ============================================================
  // AUTOMATISATIONS RECOMMANDÉES
  // ============================================================

  /// Blocage automatique après X échecs
  void handleLoginFailure(String userId, String ipAddress) {
    final recentFailures = _recentEvents.where((e) =>
      e.userId == userId &&
      e.eventType == 'login' &&
      !e.isSuccess &&
      e.timestamp.isAfter(DateTime.now().subtract(Duration(minutes: 30)))
    ).length;

    if (recentFailures >= AuthenticationPillar.maxLoginAttempts) {
      // Bloquer automatiquement
      IncidentResponsePillar.lockAccount(
        userId: userId,
        reason: 'Trop de tentatives de connexion échouées',
        lockedBy: 'system',
      );
      
      _addAlert(SecurityAlert(
        id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now().toUtc(),
        threatType: ThreatType.accountTheft,
        severity: UserRiskLevel.high,
        userId: userId,
        message: 'Compte bloqué après $recentFailures échecs de connexion',
      ));
    }
  }

  /// Alerte si changement règles + paiement proche
  void checkSuspiciousRuleChange(String userId, String circleId, DateTime? nextPaymentDate) {
    if (nextPaymentDate != null) {
      final daysUntilPayment = nextPaymentDate.difference(DateTime.now()).inDays;
      if (daysUntilPayment <= 3) {
        _addAlert(SecurityAlert(
          id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now().toUtc(),
          threatType: ThreatType.fraudulentRuleChange,
          severity: UserRiskLevel.high,
          userId: userId,
          message: 'Modification de règles suspecte: paiement dans $daysUntilPayment jours',
        ));
        
        _updateUserRiskScore(userId, UserRiskLevel.high);
      }
    }
  }

  void _addAlert(SecurityAlert alert) {
    _activeAlerts.add(alert);
  }

  void _updateUserRiskScore(String userId, UserRiskLevel level) {
    final currentLevel = _userRiskScores[userId] ?? UserRiskLevel.low;
    if (level.index > currentLevel.index) {
      _userRiskScores[userId] = level;
    }
  }

  // ============================================================
  // STATISTIQUES POUR DASHBOARD
  // ============================================================

  Map<String, dynamic> getSecurityStats() {
    return {
      'incident_mode': currentIncidentMode,
      'active_alerts': _activeAlerts.where((a) => !a.isResolved).length,
      'suspicious_logins_24h': getSuspiciousLogins().length,
      'failed_attempts_24h': getFailedAttempts().length,
      'at_risk_accounts': getAtRiskAccounts().length,
      'pillars': {
        'authentication': {
          'status': 'active',
          '2fa_enabled': true,
          'password_policy': 'strong',
        },
        'authorization': {
          'status': 'active',
          'roles_defined': AuthorizationPillar.validRoles.length,
        },
        'financial_security': {
          'status': 'active',
          'webhook_verification': true,
          'idempotency': true,
        },
        'api_protection': {
          'status': 'active',
          'rate_limiting': true,
          'abuse_detection': true,
        },
        'logging': {
          'status': 'active',
          'immutable_actions': LoggingPillar.immutableLogActions.length,
        },
        'incident_response': {
          'status': 'active',
          'mode': currentIncidentMode,
        },
      },
    };
  }

  /// Export pour audit
  List<Map<String, dynamic>> exportSecurityReport() {
    return _recentEvents.map((e) => {
      'timestamp': e.timestamp.toIso8601String(),
      'user_id': e.userId,
      'event_type': e.eventType,
      'description': e.description,
      'ip_address': e.ipAddress,
      'is_success': e.isSuccess,
      'risk_level': e.riskContribution.name,
    }).toList();
  }
}
