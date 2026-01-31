import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/config/app_config.dart';
import 'package:tontetic/core/services/audit_log_service.dart';
import 'package:tontetic/features/wallet/data/wallet_provider.dart';
import 'package:tontetic/core/services/voice_service.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/providers/tontine_provider.dart';

enum SimulationScenario { normal, insufficientFunds, accountClosed }

class SandboxOrchestrator {
  final Ref _ref;
  Timer? _timer;
  int _currentSeconds = 0;
  SimulationScenario currentScenario = SimulationScenario.normal;

  SandboxOrchestrator(this._ref);

  void startTimeMachine(String circleId, double monthlyAmount, int members) {
    // SECURITY GUARD: Totally disable in Release
    if (kReleaseMode) {
      debugPrint('🛑 [Security] Tentative de lancement Time Machine en RELEASE bloquée.');
      return; 
    }

    _timer?.cancel();
    _currentSeconds = 0;
    
    debugPrint('🚀 [Time Machine] Démarrage du cycle accéléré pour $circleId');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentSeconds++;

      // Trigger Monthly Event every N seconds
      if (_currentSeconds % AppConfig.monthDurationSeconds == 0) {
        _processVirtualMonth(circleId, monthlyAmount, members);
      }
    });
  }

  void _processVirtualMonth(String circleId, double amount, int members) {
    debugPrint('📅 [Time Machine] Un "mois" est passé. Exécution des prélèvements...');

    final walletNotifier = _ref.read(walletProvider.notifier);
    final voiceService = _ref.read(voiceServiceProvider);

    // --- LOGIQUE FRAIS PASS-THROUGH ---
    // User pays: [Cotisation + Frais Stripe]
    // Simulation: Frais Stripe = 2% du montant
    final stripeFee = amount * 0.02;
    final totalPaidPerMember = amount + stripeFee;
    
    debugPrint('💳 [Simulation] Chaque membre paie $totalPaidPerMember F ($amount + $stripeFee de frais)');

    if (currentScenario == SimulationScenario.insufficientFunds) {
      debugPrint('⚠️ [Simulation] Échec de provision pour un membre.');
      
      voiceService.playAntaSpecificMessage(
        'Ni ngui lay rappelle ni sa cotisations mo gui tard...', 
        AppLanguage.wo
      );

      final gross = amount * (members - 1); // Le pot reçoit uniquement les cotisations nettes
      AuditLogService.logCycle(circleId: circleId, gross: gross, pspFeePercent: 0.0); // Les frais sont déjà payés en extra
      
      // COUVERTURE AMANAH
      final missingAmount = amount;
      debugPrint('🛡️ [Simulation] Utilisation de l\'Amanah pour couvrir les $missingAmount F manquants.');
      AuditLogService.logAmanahWithdrawal(circleId, missingAmount);

      // Le gagnant reçoit quand même le montant total prévu
      walletNotifier.deposit(amount * members, 'Sandbox (Gain Tontine)');

      voiceService.playAntaSpecificMessage(
        'Bakhna, Amanah bi mo couvrir manquement bi. Sa pot bi paréna !', 
        AppLanguage.wo
      );
    } else {
      final gross = amount * members;
      AuditLogService.logCycle(circleId: circleId, gross: gross, pspFeePercent: 0.0);
      
      walletNotifier.deposit(gross, 'Sandbox (Gain Tontine)'); // Corrected: 2 arguments
      
      // V14: Advance the circle cycle in provider
      _ref.read(circleProvider.notifier).advanceCycle(circleId);
      
      voiceService.playAntaSpecificMessage(
        'Baaraka Allahou fik, sa mbindu bi bakhna. Sa pot bi paréna !', 
        AppLanguage.wo
      );
    }
  }

  void simulateInvitationReceived(String circleName, String inviterName, String circleId) {
    if (kReleaseMode) return; // Silent return in Release
    
    final voiceService = _ref.read(voiceServiceProvider);
    debugPrint('📬 [Simulation] Réception d\'une invitation.');
    
    // V14: Add real invitation to CircleProvider
    /* _ref.read(circleProvider.notifier).addInvitation(
      circleName: circleName,
      inviterName: inviterName,
      circleId: circleId,
    ); */
    
    voiceService.playAntaSpecificMessage(
      'Am nga invitation bou bess. Danga beugue dougue ci tontine bi ?', 
      AppLanguage.wo
    );
  }

  void stop() {
    _timer?.cancel();
    debugPrint('🛑 [Time Machine] Arrêté.');
  }
}

final sandboxOrchestratorProvider = Provider<SandboxOrchestrator>((ref) {
  return SandboxOrchestrator(ref);
});
