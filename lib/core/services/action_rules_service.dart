/// Action Rules Engine - Moteur de Décision
/// 
/// RÈGLE MÈRE (gravée dans le marbre):
/// Pour CHAQUE action, 3 questions dans cet ordre:
/// 1. Qui agit ? (user/créateur/admin/système)
/// 2. Qu'est-ce que ça impacte ? (argent/contrat/droits/sécurité/conformité)
/// 3. Quel est le risque maximal si ça se passe mal ?
///
/// La réponse à la question 3 détermine automatiquement QUOI FAIRE.

/// La réponse à la question 3 détermine automatiquement QUOI FAIRE.
library;

import 'package:flutter/foundation.dart';

// ============================================================
// ENUMS - Classification des actions
// ============================================================

/// Qui agit ?
enum ActionActor {
  user,           // Utilisateur standard
  circleCreator,  // Créateur de cercle
  admin,          // Administrateur
  system,         // Système automatique
}

/// Qu'est-ce que ça impacte ?
enum ActionImpact {
  nothing,        // Rien d'important
  personalData,   // Données personnelles
  money,          // Argent
  contract,       // Contrat / engagement
  otherRights,    // Droits d'un autre utilisateur
  security,       // Sécurité
  compliance,     // Conformité légale
}

/// Quel est le risque maximal ?
enum RiskLevel {
  none,           // Aucun → Niveau 1
  singleUser,     // Utilisateur seul → Niveau 2
  group,          // Groupe → Niveau 3
  platform,       // Plateforme → Niveau 4
  regulator,      // Régulateur → Niveau 4
}

/// Niveau d'action (1 à 4)
enum ActionLevel {
  level1Libre,     // Action libre (risque nul)
  level2Engaging,  // Action engageante (risque individuel)
  level3Sensitive, // Action sensible (risque collectif)
  level4Critical,  // Action critique (risque légal/plateforme)
}

// ============================================================
// MODÈLES
// ============================================================

/// Définition d'une règle d'action
class ActionRule {
  final String actionId;
  final String actionName;
  final String description;
  final ActionLevel level;
  final List<ActionActor> allowedActors;
  final List<ActionImpact> impacts;
  final RiskLevel maxRisk;
  
  // Niveau 1 - Action libre
  final bool immediateExecution;
  final bool simpleLog;
  
  // Niveau 2 - Action engageante
  final bool requiresConfirmation;
  final bool requiresSummary;
  final bool logWithTimestampAndIp;
  
  // Niveau 3 - Action sensible
  final bool requiresConditions;
  final int? gracePeriodHours;
  final bool notifyParties;
  final bool fullTraceability;
  final bool deferredExecution;
  
  // Niveau 4 - Action critique
  final bool blockedByDefault;
  final bool requiresAdminValidation;
  final bool createInternalTicket;
  final bool immutableAudit;

  const ActionRule({
    required this.actionId,
    required this.actionName,
    required this.description,
    required this.level,
    required this.allowedActors,
    required this.impacts,
    required this.maxRisk,
    this.immediateExecution = false,
    this.simpleLog = false,
    this.requiresConfirmation = false,
    this.requiresSummary = false,
    this.logWithTimestampAndIp = false,
    this.requiresConditions = false,
    this.gracePeriodHours,
    this.notifyParties = false,
    this.fullTraceability = false,
    this.deferredExecution = false,
    this.blockedByDefault = false,
    this.requiresAdminValidation = false,
    this.createInternalTicket = false,
    this.immutableAudit = false,
  });

  Map<String, dynamic> toJson() => {
    'actionId': actionId,
    'actionName': actionName,
    'description': description,
    'level': level.index + 1,
    'levelName': getLevelName(level),
    'allowedActors': allowedActors.map((a) => a.name).toList(),
    'impacts': impacts.map((i) => i.name).toList(),
    'maxRisk': maxRisk.name,
    'requirements': getRequirements(),
  };

  List<String> getRequirements() {
    final reqs = <String>[];
    
    switch (level) {
      case ActionLevel.level1Libre:
        reqs.add('Exécution immédiate');
        reqs.add('Log simple');
        break;
      case ActionLevel.level2Engaging:
        reqs.add('Afficher résumé clair');
        reqs.add('Demander confirmation');
        reqs.add('Horodater + IP');
        reqs.add('Exécuter');
        break;
      case ActionLevel.level3Sensitive:
        reqs.add('Vérifier conditions préalables');
        if (gracePeriodHours != null) {
          reqs.add('Délai de grâce: ${gracePeriodHours}h');
        }
        reqs.add('Notifier parties concernées');
        reqs.add('Log complet');
        reqs.add('Action différée ou conditionnelle');
        break;
      case ActionLevel.level4Critical:
        reqs.add('Bloquer action immédiate');
        reqs.add('Créer ticket interne');
        reqs.add('Notifier admin');
        reqs.add('Décision humaine ou système');
        reqs.add('Journal immuable');
        break;
    }
    
    return reqs;
  }

  static String getLevelName(ActionLevel level) {
    switch (level) {
      case ActionLevel.level1Libre:
        return 'Niveau 1 - Action libre';
      case ActionLevel.level2Engaging:
        return 'Niveau 2 - Action engageante';
      case ActionLevel.level3Sensitive:
        return 'Niveau 3 - Action sensible';
      case ActionLevel.level4Critical:
        return 'Niveau 4 - Action critique';
    }
  }
}

/// Résultat d'exécution d'une action
class ActionExecutionResult {
  final String actionId;
  final bool allowed;
  final ActionLevel level;
  final List<String> requiredSteps;
  final String? blockReason;
  final int? delayHours;
  final bool requiresAdminApproval;
  final DateTime timestamp;
  final String? ticketId;

  const ActionExecutionResult({
    required this.actionId,
    required this.allowed,
    required this.level,
    required this.requiredSteps,
    this.blockReason,
    this.delayHours,
    this.requiresAdminApproval = false,
    required this.timestamp,
    this.ticketId,
  });
}

// ============================================================
// SERVICE PRINCIPAL
// ============================================================

class ActionRulesService {
  static final ActionRulesService _instance = ActionRulesService._internal();
  factory ActionRulesService() => _instance;
  ActionRulesService._internal() {
    _initializeRules();
  }

  final Map<String, ActionRule> _rules = {};

  /// Initialise toutes les règles de la plateforme
  void _initializeRules() {
    // ============================================================
    // NIVEAU 1 - Actions libres (risque nul)
    // ============================================================
    
    _addRule(ActionRule(
      actionId: 'profile_update_photo',
      actionName: 'Modifier photo de profil',
      description: 'Mise à jour de la photo de profil utilisateur',
      level: ActionLevel.level1Libre,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.nothing],
      maxRisk: RiskLevel.none,
      immediateExecution: true,
      simpleLog: true,
    ));

    _addRule(ActionRule(
      actionId: 'send_message',
      actionName: 'Envoyer un message',
      description: 'Envoi de message dans un cercle',
      level: ActionLevel.level1Libre,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.nothing],
      maxRisk: RiskLevel.none,
      immediateExecution: true,
      simpleLog: true,
    ));

    _addRule(ActionRule(
      actionId: 'view_circle',
      actionName: 'Consulter une tontine',
      description: 'Visualisation des détails d\'un cercle',
      level: ActionLevel.level1Libre,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.nothing],
      maxRisk: RiskLevel.none,
      immediateExecution: true,
      simpleLog: true,
    ));

    _addRule(ActionRule(
      actionId: 'view_shop',
      actionName: 'Consulter la boutique',
      description: 'Navigation dans le marketplace',
      level: ActionLevel.level1Libre,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.nothing],
      maxRisk: RiskLevel.none,
      immediateExecution: true,
      simpleLog: true,
    ));

    // ============================================================
    // NIVEAU 2 - Actions engageantes (risque individuel)
    // ============================================================

    _addRule(ActionRule(
      actionId: 'join_circle',
      actionName: 'Rejoindre une tontine',
      description: 'Demande d\'adhésion à un cercle existant',
      level: ActionLevel.level2Engaging,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.contract, ActionImpact.money],
      maxRisk: RiskLevel.singleUser,
      requiresConfirmation: true,
      requiresSummary: true,
      logWithTimestampAndIp: true,
    ));

    _addRule(ActionRule(
      actionId: 'vote_pot_order',
      actionName: 'Voter pour l\'ordre des pots',
      description: 'Vote dans le processus de décision collective',
      level: ActionLevel.level2Engaging,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.otherRights],
      maxRisk: RiskLevel.singleUser,
      requiresConfirmation: true,
      logWithTimestampAndIp: true,
    ));

    _addRule(ActionRule(
      actionId: 'accept_contract',
      actionName: 'Accepter les conditions',
      description: 'Acceptation des CGU ou contrat de cercle',
      level: ActionLevel.level2Engaging,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.contract, ActionImpact.compliance],
      maxRisk: RiskLevel.singleUser,
      requiresConfirmation: true,
      requiresSummary: true,
      logWithTimestampAndIp: true,
    ));

    _addRule(ActionRule(
      actionId: 'invite_member',
      actionName: 'Inviter un membre',
      description: 'Invitation d\'un nouveau membre dans un cercle',
      level: ActionLevel.level2Engaging,
      allowedActors: [ActionActor.user, ActionActor.circleCreator],
      impacts: [ActionImpact.otherRights],
      maxRisk: RiskLevel.singleUser,
      requiresConfirmation: true,
      logWithTimestampAndIp: true,
    ));

    _addRule(ActionRule(
      actionId: 'add_payment_method',
      actionName: 'Ajouter moyen de paiement',
      description: 'Enregistrement d\'un nouveau moyen de paiement',
      level: ActionLevel.level2Engaging,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.money, ActionImpact.security],
      maxRisk: RiskLevel.singleUser,
      requiresConfirmation: true,
      requiresSummary: true,
      logWithTimestampAndIp: true,
    ));

    // ============================================================
    // NIVEAU 3 - Actions sensibles (risque collectif/financier)
    // ============================================================

    _addRule(ActionRule(
      actionId: 'leave_circle',
      actionName: 'Quitter une tontine active',
      description: 'Départ d\'un cercle en cours de cycle',
      level: ActionLevel.level3Sensitive,
      allowedActors: [ActionActor.user],
      impacts: [ActionImpact.contract, ActionImpact.money, ActionImpact.otherRights],
      maxRisk: RiskLevel.group,
      requiresConditions: true,
      gracePeriodHours: 48,
      notifyParties: true,
      fullTraceability: true,
      deferredExecution: true,
    ));

    _addRule(ActionRule(
      actionId: 'activate_guarantee',
      actionName: 'Activer une garantie',
      description: 'Déclenchement de la garantie suite à un défaut',
      level: ActionLevel.level3Sensitive,
      allowedActors: [ActionActor.circleCreator, ActionActor.system],
      impacts: [ActionImpact.money, ActionImpact.contract, ActionImpact.otherRights],
      maxRisk: RiskLevel.group,
      requiresConditions: true,
      gracePeriodHours: 72,
      notifyParties: true,
      fullTraceability: true,
      deferredExecution: true,
    ));

    _addRule(ActionRule(
      actionId: 'modify_circle_rules',
      actionName: 'Modifier règles du cercle',
      description: 'Changement des paramètres d\'un cercle actif',
      level: ActionLevel.level3Sensitive,
      allowedActors: [ActionActor.circleCreator],
      impacts: [ActionImpact.contract, ActionImpact.otherRights],
      maxRisk: RiskLevel.group,
      requiresConditions: true,
      gracePeriodHours: 72,
      notifyParties: true,
      fullTraceability: true,
      deferredExecution: true,
    ));

    _addRule(ActionRule(
      actionId: 'change_amounts',
      actionName: 'Modifier montants ou dates',
      description: 'Modification des montants ou échéances',
      level: ActionLevel.level3Sensitive,
      allowedActors: [ActionActor.circleCreator],
      impacts: [ActionImpact.money, ActionImpact.contract],
      maxRisk: RiskLevel.group,
      requiresConditions: true,
      gracePeriodHours: 48,
      notifyParties: true,
      fullTraceability: true,
      deferredExecution: true,
    ));

    _addRule(ActionRule(
      actionId: 'exclude_member',
      actionName: 'Exclure un membre',
      description: 'Exclusion d\'un membre du cercle',
      level: ActionLevel.level3Sensitive,
      allowedActors: [ActionActor.circleCreator, ActionActor.admin],
      impacts: [ActionImpact.contract, ActionImpact.otherRights],
      maxRisk: RiskLevel.group,
      requiresConditions: true,
      gracePeriodHours: 24,
      notifyParties: true,
      fullTraceability: true,
    ));

    // ============================================================
    // NIVEAU 4 - Actions critiques (risque légal/plateforme)
    // ============================================================

    _addRule(ActionRule(
      actionId: 'close_active_circle',
      actionName: 'Clôturer une tontine active',
      description: 'Fermeture anticipée d\'un cercle en cours',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.admin, ActionActor.system],
      impacts: [ActionImpact.money, ActionImpact.contract, ActionImpact.compliance],
      maxRisk: RiskLevel.platform,
      blockedByDefault: true,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    _addRule(ActionRule(
      actionId: 'report_fraud',
      actionName: 'Signalement fraude',
      description: 'Signalement d\'une activité frauduleuse',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.user, ActionActor.admin, ActionActor.system],
      impacts: [ActionImpact.security, ActionImpact.compliance],
      maxRisk: RiskLevel.platform,
      blockedByDefault: false,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    _addRule(ActionRule(
      actionId: 'suspend_account',
      actionName: 'Suspension de compte',
      description: 'Suspension temporaire ou définitive d\'un compte',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.admin, ActionActor.system],
      impacts: [ActionImpact.security, ActionImpact.compliance, ActionImpact.otherRights],
      maxRisk: RiskLevel.regulator,
      blockedByDefault: true,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    _addRule(ActionRule(
      actionId: 'modify_cgu',
      actionName: 'Modification CGU',
      description: 'Mise à jour des conditions générales d\'utilisation',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.admin],
      impacts: [ActionImpact.contract, ActionImpact.compliance],
      maxRisk: RiskLevel.regulator,
      blockedByDefault: true,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    _addRule(ActionRule(
      actionId: 'psp_action',
      actionName: 'Action PSP',
      description: 'Opération liée au prestataire de paiement',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.admin, ActionActor.system],
      impacts: [ActionImpact.money, ActionImpact.compliance, ActionImpact.security],
      maxRisk: RiskLevel.regulator,
      blockedByDefault: true,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    _addRule(ActionRule(
      actionId: 'delete_user_data',
      actionName: 'Suppression données RGPD',
      description: 'Suppression des données personnelles (droit à l\'oubli)',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.admin, ActionActor.system],
      impacts: [ActionImpact.personalData, ActionImpact.compliance],
      maxRisk: RiskLevel.regulator,
      blockedByDefault: true,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    _addRule(ActionRule(
      actionId: 'refund_via_psp',
      actionName: 'Remboursement via PSP',
      description: 'Déclenchement d\'un remboursement',
      level: ActionLevel.level4Critical,
      allowedActors: [ActionActor.admin],
      impacts: [ActionImpact.money, ActionImpact.compliance],
      maxRisk: RiskLevel.platform,
      blockedByDefault: true,
      requiresAdminValidation: true,
      createInternalTicket: true,
      immutableAudit: true,
    ));

    debugPrint('[ActionRules] ${_rules.length} règles initialisées');
  }

  void _addRule(ActionRule rule) {
    _rules[rule.actionId] = rule;
  }

  // ============================================================
  // MÉTHODES PUBLIQUES
  // ============================================================

  /// Récupère une règle par son ID
  ActionRule? getRule(String actionId) => _rules[actionId];

  /// Récupère toutes les règles
  List<ActionRule> getAllRules() => _rules.values.toList();

  /// Récupère les règles par niveau
  List<ActionRule> getRulesByLevel(ActionLevel level) {
    return _rules.values.where((r) => r.level == level).toList();
  }

  /// Détermine le niveau d'une action basé sur les 3 questions
  ActionLevel determineLevel({
    required ActionActor actor,
    required List<ActionImpact> impacts,
    required RiskLevel maxRisk,
  }) {
    // La question 3 (risque max) détermine le niveau
    switch (maxRisk) {
      case RiskLevel.none:
        return ActionLevel.level1Libre;
      case RiskLevel.singleUser:
        return ActionLevel.level2Engaging;
      case RiskLevel.group:
        return ActionLevel.level3Sensitive;
      case RiskLevel.platform:
      case RiskLevel.regulator:
        return ActionLevel.level4Critical;
    }
  }

  /// Évalue si une action peut être exécutée
  ActionExecutionResult evaluateAction({
    required String actionId,
    required ActionActor currentActor,
    required String userId,
    required String? ip,
  }) {
    final rule = _rules[actionId];
    
    if (rule == null) {
      return ActionExecutionResult(
        actionId: actionId,
        allowed: false,
        level: ActionLevel.level4Critical,
        requiredSteps: ['Action non reconnue'],
        blockReason: 'Action non définie dans les règles',
        timestamp: DateTime.now().toUtc(),
      );
    }

    // Vérifier si l'acteur est autorisé
    if (!rule.allowedActors.contains(currentActor)) {
      return ActionExecutionResult(
        actionId: actionId,
        allowed: false,
        level: rule.level,
        requiredSteps: [],
        blockReason: 'Acteur non autorisé pour cette action',
        timestamp: DateTime.now().toUtc(),
      );
    }

    // Appliquer les règles selon le niveau
    switch (rule.level) {
      case ActionLevel.level1Libre:
        return ActionExecutionResult(
          actionId: actionId,
          allowed: true,
          level: rule.level,
          requiredSteps: ['Exécuter', 'Logger'],
          timestamp: DateTime.now().toUtc(),
        );

      case ActionLevel.level2Engaging:
        return ActionExecutionResult(
          actionId: actionId,
          allowed: true,
          level: rule.level,
          requiredSteps: [
            'Afficher résumé clair',
            'Demander confirmation utilisateur',
            'Horodater + IP: $ip',
            'Exécuter',
          ],
          timestamp: DateTime.now().toUtc(),
        );

      case ActionLevel.level3Sensitive:
        return ActionExecutionResult(
          actionId: actionId,
          allowed: true,
          level: rule.level,
          requiredSteps: [
            'Vérifier conditions préalables',
            if (rule.gracePeriodHours != null)
              'Appliquer délai de grâce: ${rule.gracePeriodHours}h',
            'Notifier parties concernées',
            'Log complet avec traçabilité',
            'Exécution différée ou conditionnelle',
          ],
          delayHours: rule.gracePeriodHours,
          timestamp: DateTime.now().toUtc(),
        );

      case ActionLevel.level4Critical:
        final ticketId = 'TKT-${DateTime.now().millisecondsSinceEpoch}';
        return ActionExecutionResult(
          actionId: actionId,
          allowed: !rule.blockedByDefault,
          level: rule.level,
          requiredSteps: [
            'Action bloquée par défaut',
            'Ticket créé: $ticketId',
            'Notification admin envoyée',
            'En attente de décision humaine',
            'Audit immuable requis',
          ],
          blockReason: rule.blockedByDefault ? 'Validation admin requise' : null,
          requiresAdminApproval: rule.requiresAdminValidation,
          ticketId: ticketId,
          timestamp: DateTime.now().toUtc(),
        );
    }
  }

  /// Question pour chaque bouton: "Si cette action échoue ou est frauduleuse, qui perd quoi ?"
  String getPotentialLossDescription(ActionLevel level) {
    switch (level) {
      case ActionLevel.level1Libre:
        return 'Rien';
      case ActionLevel.level2Engaging:
        return 'Un utilisateur';
      case ActionLevel.level3Sensitive:
        return 'Un groupe';
      case ActionLevel.level4Critical:
        return 'La plateforme';
    }
  }

  /// Export pour audit
  List<Map<String, dynamic>> exportRulesForAudit() {
    return _rules.values.map((r) => r.toJson()).toList();
  }

  /// Statistiques des règles
  Map<String, dynamic> getRulesStats() {
    return {
      'total': _rules.length,
      'level1_libre': getRulesByLevel(ActionLevel.level1Libre).length,
      'level2_engaging': getRulesByLevel(ActionLevel.level2Engaging).length,
      'level3_sensitive': getRulesByLevel(ActionLevel.level3Sensitive).length,
      'level4_critical': getRulesByLevel(ActionLevel.level4Critical).length,
    };
  }
}
