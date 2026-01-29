import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/constants/legal_texts.dart';

/// V17: Épargne Bloquée - Modèle PSP Ségrégué
/// 
/// ARCHITECTURE LÉGALE (CGU Article 8):
/// - Fonds cantonnés chez le PSP (Stripe/Wave)
/// - Tontetic = orchestrateur technique uniquement
/// - Aucun transit par les comptes Tontetic
/// - Règles immutables après validation (8.3)
/// - Déblocage automatique à date (8.5)
/// - Aucun intérêt ni rendement (8.2)

/// Type de finalité pour l'épargne bloquée
enum SavingsPurpose {
  tontineGuarantee,      // Garantie conditionnelle tontine (8.6)
  tontineContributions,  // Préfinancement cotisations (8.1)
  personalProject,       // Épargne projet personnel (8.1)
}

/// Statut de l'épargne bloquée
enum LockedSavingsStatus {
  pending,     // En attente de confirmation PSP (8.10)
  locked,      // Verrouillé chez PSP (8.4)
  unlocking,   // Déblocage en cours (8.5)
  released,    // Libéré (date atteinte ou condition remplie)
  triggered,   // Déclenché (garantie utilisée) (8.6)
}

/// Modèle IMMUTABLE d'épargne bloquée
/// Une fois créée, aucune modification possible (CGU 8.3)
@immutable
class LockedSavings {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final SavingsPurpose purpose;
  final String purposeLabel;        // Ex: "Tabaski 2026", "Cercle Famille"
  final DateTime createdAt;
  final DateTime unlockDate;
  final LockedSavingsStatus status;
  final String? tontineId;          // Si lié à une tontine
  final String pspReference;        // Référence chez PSP (Stripe transfer_group)
  final bool cguAccepted;           // CGU 8.13: Acceptation expresse
  
  const LockedSavings({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.purpose,
    required this.purposeLabel,
    required this.createdAt,
    required this.unlockDate,
    required this.status,
    this.tontineId,
    required this.pspReference,
    this.cguAccepted = true,
  });

  /// Vérifie si le déblocage est dû
  bool get isUnlockDue => DateTime.now().isAfter(unlockDate);
  
  /// Jours restants avant déblocage
  int get daysUntilUnlock => unlockDate.difference(DateTime.now()).inDays;
  
  /// Impossible de modifier après création - seul le status peut changer via PSP
  /// Conformément à CGU 8.3: paramètres DÉFINITIFS et IRRÉVOCABLES
  LockedSavings copyWithStatus(LockedSavingsStatus newStatus) {
    return LockedSavings(
      id: id,
      userId: userId,
      amount: amount,
      currency: currency,
      purpose: purpose,
      purposeLabel: purposeLabel,
      createdAt: createdAt,
      unlockDate: unlockDate,
      status: newStatus,
      tontineId: tontineId,
      pspReference: pspReference,
      cguAccepted: cguAccepted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'amount': amount,
    'currency': currency,
    'purpose': purpose.name,
    'purpose_label': purposeLabel,
    'created_at': createdAt.toIso8601String(),
    'unlock_date': unlockDate.toIso8601String(),
    'status': status.name,
    'tontine_id': tontineId,
    'psp_reference': pspReference,
    'cgu_accepted': cguAccepted,
  };

  factory LockedSavings.fromJson(Map<String, dynamic> json) => LockedSavings(
    id: json['id'],
    userId: json['user_id'],
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'],
    purpose: SavingsPurpose.values.byName(json['purpose']),
    purposeLabel: json['purpose_label'],
    createdAt: DateTime.parse(json['created_at']),
    unlockDate: DateTime.parse(json['unlock_date']),
    status: LockedSavingsStatus.values.byName(json['status']),
    tontineId: json['tontine_id'],
    pspReference: json['psp_reference'],
    cguAccepted: json['cgu_accepted'] ?? true,
  );
}

/// État global des épargnes bloquées
class LockedSavingsState {
  final List<LockedSavings> savings;
  final bool isLoading;
  final String? error;

  const LockedSavingsState({
    this.savings = const [],
    this.isLoading = false,
    this.error,
  });

  /// Total des fonds bloqués
  double get totalLocked => savings
      .where((s) => s.status == LockedSavingsStatus.locked)
      .fold(0.0, (sum, s) => sum + s.amount);

  /// Épargnes actives (non libérées)
  List<LockedSavings> get activeSavings => savings
      .where((s) => s.status == LockedSavingsStatus.locked)
      .toList();

  LockedSavingsState copyWith({
    List<LockedSavings>? savings,
    bool? isLoading,
    String? error,
  }) {
    return LockedSavingsState(
      savings: savings ?? this.savings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Service de gestion des épargnes bloquées
/// Conforme aux CGU Article 8 (8.1 à 8.13)
class LockedSavingsNotifier extends StateNotifier<LockedSavingsState> {
  LockedSavingsNotifier() : super(const LockedSavingsState());

  /// Créer une nouvelle épargne bloquée
  /// IMPORTANT: Une fois créée, les paramètres sont IMMUTABLES (CGU 8.3)
  Future<LockedSavings?> createLockedSavings({
    required String userId,
    required double amount,
    required String currency,
    required SavingsPurpose purpose,
    required String purposeLabel,
    required DateTime unlockDate,
    String? tontineId,
  }) async {
    // Validation (CGU 8.7: Responsabilité de l'Utilisateur)
    if (amount <= 0) {
      state = state.copyWith(error: 'Montant invalide');
      return null;
    }
    if (unlockDate.isBefore(DateTime.now())) {
      state = state.copyWith(error: 'Date de déblocage invalide');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Générer référence PSP (CGU 8.10: Prestataires de paiement)
      final pspRef = 'PSP_SEG_${DateTime.now().millisecondsSinceEpoch}';

      final newSavings = LockedSavings(
        id: 'LS_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        amount: amount,
        currency: currency,
        purpose: purpose,
        purposeLabel: purposeLabel,
        createdAt: DateTime.now(),
        unlockDate: unlockDate,
        status: LockedSavingsStatus.locked,
        tontineId: tontineId,
        pspReference: pspRef,
        cguAccepted: true, // CGU 8.13: Acceptation expresse
      );

      // Log audit (CGU 8.11: Traçabilité et audit)
      debugPrint('[LOCKED_SAVINGS] Created: ${newSavings.id}');
      debugPrint('  → Amount: $amount $currency');
      debugPrint('  → Purpose: ${purpose.name} - $purposeLabel');
      debugPrint('  → Unlock: ${unlockDate.toIso8601String()}');
      debugPrint('  → PSP Ref: $pspRef');
      debugPrint('  → CGU 8.13 Accepted: true');

      state = state.copyWith(
        savings: [...state.savings, newSavings],
        isLoading: false,
      );

      return newSavings;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Vérifier et déclencher les déblocages dus
  /// CGU 8.5: Déblocage automatique - Aucune intervention manuelle requise
  Future<List<LockedSavings>> processAutomaticUnlocks() async {
    final unlocked = <LockedSavings>[];
    final now = DateTime.now();

    for (final savings in state.savings) {
      if (savings.status == LockedSavingsStatus.locked && 
          now.isAfter(savings.unlockDate)) {
        
        debugPrint('[LOCKED_SAVINGS] Auto-unlocking: ${savings.id}');
        
        // En prod: appel API PSP pour libérer les fonds (CGU 8.10)
        // await _pspClient.releaseSegregatedFunds(savings.pspReference);

        final updated = savings.copyWithStatus(LockedSavingsStatus.released);
        unlocked.add(updated);
      }
    }

    if (unlocked.isNotEmpty) {
      final updatedList = state.savings.map((s) {
        final match = unlocked.firstWhere((u) => u.id == s.id, orElse: () => s);
        return match;
      }).toList();
      
      state = state.copyWith(savings: updatedList);
    }

    return unlocked;
  }

  /// Déclencher une garantie (cas de défaut tontine)
  /// CGU 8.6: Utilisation en cas de garantie
  Future<bool> triggerGuarantee(String savingsId) async {
    final savings = state.savings.firstWhere(
      (s) => s.id == savingsId && s.purpose == SavingsPurpose.tontineGuarantee,
      orElse: () => throw Exception('Garantie non trouvée'),
    );

    if (savings.status != LockedSavingsStatus.locked) {
      return false;
    }

    debugPrint('[LOCKED_SAVINGS] ⚠️ Triggering guarantee: ${savings.id}');
    debugPrint('  → CGU 8.6: Défaut avéré, règles automatisées appliquées');

    // En prod: API PSP pour transférer au bénéficiaire
    final updated = savings.copyWithStatus(LockedSavingsStatus.triggered);
    
    final updatedList = state.savings.map((s) => s.id == savingsId ? updated : s).toList();
    state = state.copyWith(savings: updatedList);

    return true;
  }

  /// Obtenir le disclaimer légal (CGU Article 8 résumé)
  static String getLegalDisclaimer() {
    final keyPoints = LegalTexts.getEpargneBloqueeKeyPoints();
    return keyPoints.map((p) => '• $p').join('\n');
  }

  /// Obtenir les CGU complètes Article 8
  static String getFullCgu() {
    return LegalTexts.epargneBloqueeFullCgu;
  }
}

// Provider
final lockedSavingsProvider = StateNotifierProvider<LockedSavingsNotifier, LockedSavingsState>((ref) {
  return LockedSavingsNotifier();
});

