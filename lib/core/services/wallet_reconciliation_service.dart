
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tontetic/core/services/persistent_audit_service.dart';

/// V16: Wallet Reconciliation Service
/// Ensures wallet balance displayed matches PSP source of truth
/// 
/// Features:
/// - Regular sync with PSP
/// - Discrepancy detection and alerting
/// - Automatic correction from PSP
/// - Audit trail for all reconciliations

enum ReconciliationStatus {
  synced,       // Balances match
  discrepancy,  // Mismatch detected
  corrected,    // Mismatch fixed
  error,        // Could not reconcile
}

class ReconciliationResult {
  final bool synced;
  final bool hadDiscrepancy;
  final double localBalance;
  final double pspBalance;
  final double? correctedAmount;
  final String message;
  final DateTime timestamp;

  ReconciliationResult({
    required this.synced,
    required this.hadDiscrepancy,
    required this.localBalance,
    required this.pspBalance,
    this.correctedAmount,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'synced': synced,
    'had_discrepancy': hadDiscrepancy,
    'local_balance': localBalance,
    'psp_balance': pspBalance,
    'corrected_amount': correctedAmount,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };
}

class WalletReconciliationService {
  final Ref _ref;
  final SupabaseClient _client;
  
  // Threshold for discrepancy alerts (in cents/centimes)
  static const double _discrepancyThreshold = 1.0; // 1 centime/FCFA

  WalletReconciliationService(this._ref) : _client = Supabase.instance.client;

  /// Reconcile a user's wallet with PSP
  Future<ReconciliationResult> reconcile(String userId) async {
    final now = DateTime.now();
    
    try {
      // 1. Get local balance (from app state)
      final localBalance = await _getLocalBalance(userId);
      
      // 2. Get PSP balance (from Stripe/Wave)
      final pspBalance = await _getPSPBalance(userId);
      
      // 3. Calculate difference
      final difference = (localBalance - pspBalance).abs();
      
      // 4. Check for discrepancy
      if (difference > _discrepancyThreshold) {
        // Log the discrepancy
        await _ref.read(persistentAuditServiceProvider).log(
          action: 'BALANCE_DISCREPANCY',
          category: AuditCategory.financial,
          userId: userId,
          data: {
            'local_balance': localBalance,
            'psp_balance': pspBalance,
            'difference': difference,
          },
          severity: AuditSeverity.warning,
        );
        
        // Force sync from PSP (PSP is source of truth)
        await _syncFromPSP(userId, pspBalance);
        
        debugPrint('[RECONCILIATION] Discrepancy detected and corrected for $userId: $difference');
        
        return ReconciliationResult(
          synced: true,
          hadDiscrepancy: true,
          localBalance: localBalance,
          pspBalance: pspBalance,
          correctedAmount: difference,
          message: 'Discrepancy detected and corrected from PSP',
          timestamp: now,
        );
      }
      
      // 5. All good
      return ReconciliationResult(
        synced: true,
        hadDiscrepancy: false,
        localBalance: localBalance,
        pspBalance: pspBalance,
        message: 'Balances are synchronized',
        timestamp: now,
      );
      
    } catch (e) {
      debugPrint('[RECONCILIATION] Error for $userId: $e');
      
      return ReconciliationResult(
        synced: false,
        hadDiscrepancy: false,
        localBalance: 0,
        pspBalance: 0,
        message: 'Reconciliation error: $e',
        timestamp: now,
      );
    }
  }

  /// Get local balance (from app state or cache)
  Future<double> _getLocalBalance(String userId) async {
    // In production: read from walletProvider or local cache
    final response = await _client
        .from('wallet_cache')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    
    return (response?['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get balance from PSP (Stripe/Wave)
  Future<double> _getPSPBalance(String userId) async {
    // In production: call PSP API
    // For Stripe: await stripe.customers.retrieveBalance(customerId)
    // For Wave: await wave.getAccountBalance(userId)
    
    // Mock implementation - in real app, call actual PSP
    final response = await _client
        .from('psp_balances')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    
    return (response?['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Sync wallet from PSP (PSP is source of truth)
  Future<void> _syncFromPSP(String userId, double pspBalance) async {
    // Update local cache with PSP value
    await _client.from('wallet_cache').upsert({
      'user_id': userId,
      'balance': pspBalance,
      'last_synced': DateTime.now().toIso8601String(),
      'sync_source': 'psp_reconciliation',
    });
    
    // Log the correction
    await _ref.read(persistentAuditServiceProvider).log(
      action: 'BALANCE_SYNCED_FROM_PSP',
      category: AuditCategory.financial,
      userId: userId,
      data: {'new_balance': pspBalance},
    );
  }

  /// Scheduled reconciliation for all users (run daily)
  Future<Map<String, ReconciliationResult>> reconcileAll() async {
    final results = <String, ReconciliationResult>{};
    
    // Get all users with wallets
    final users = await _client
        .from('wallet_cache')
        .select('user_id')
        .limit(1000); // Batch processing
    
    for (final user in users as List) {
      final userId = user['user_id'] as String;
      results[userId] = await reconcile(userId);
    }
    
    // Summary stats
    final discrepancies = results.values.where((r) => r.hadDiscrepancy).length;
    debugPrint('[RECONCILIATION] Batch complete: ${results.length} users, $discrepancies discrepancies');
    
    return results;
  }

  /// Get reconciliation history for a user
  Future<List<Map<String, dynamic>>> getHistory(String userId, {int limit = 20}) async {
    final response = await _client
        .from('audit_logs')
        .select()
        .or('action.eq.BALANCE_DISCREPANCY,action.eq.BALANCE_SYNCED_FROM_PSP')
        .eq('user_id_hash', userId.hashCode.toString()) // Note: should use proper hash
        .order('timestamp', ascending: false)
        .limit(limit);
    
    return List<Map<String, dynamic>>.from(response);
  }
}

// ============ PROVIDER ============

final walletReconciliationServiceProvider = Provider<WalletReconciliationService>((ref) {
  return WalletReconciliationService(ref);
});
