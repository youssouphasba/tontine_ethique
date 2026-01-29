import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/security/security_service.dart';

/// V11.5 - Security Alerts Panel for Super Admin
/// Monitor fraud alerts and frozen wallets
class SecurityAlertsPanel extends ConsumerWidget {
  const SecurityAlertsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final pendingAlerts = security.alerts.where((a) => !a.isResolved).toList();
    final frozenCount = security.frozenWallets.length;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.security, color: AppTheme.gold),
            const SizedBox(width: 12),
            const Text('Centre de Sécurité'),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        actions: [
          // Frozen wallets counter
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: frozenCount > 0 ? Colors.blue : Colors.grey.shade700,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.ac_unit, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '$frozenCount gelés',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          // Pending alerts counter
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: pendingAlerts.isEmpty ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(pendingAlerts.isEmpty ? Icons.check : Icons.warning, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  '${pendingAlerts.length} alertes',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // LEFT: Stats Panel
          Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF16213E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCard('Alertes Actives', '${pendingAlerts.length}', Icons.warning, Colors.orange),
                const SizedBox(height: 12),
                _buildStatCard('Wallets Gelés', '$frozenCount', Icons.ac_unit, Colors.blue),
                const SizedBox(height: 12),
                _buildStatCard('Résolues (Total)', '${security.alerts.where((a) => a.isResolved).length}', Icons.check_circle, Colors.green),
                
                const SizedBox(height: 24),
                const Text(
                  'TYPES D\'ALERTES',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...SecurityAlert.values.map((type) {
                  final count = pendingAlerts.where((a) => a.type == type).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getAlertColor(type),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getAlertLabel(type),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: count > 0 ? Colors.white : Colors.white38,
                            fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          
          // RIGHT: Alerts List
          Expanded(
            child: pendingAlerts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingAlerts.length,
                    itemBuilder: (context, index) => _buildAlertCard(
                      context, 
                      ref,
                      pendingAlerts[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield, size: 80, color: Colors.green.withAlpha(150)),
          const SizedBox(height: 16),
          const Text(
            'Aucune alerte en cours',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Tous les systèmes sont opérationnels ✓',
            style: TextStyle(color: Colors.green.shade300, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, WidgetRef ref, FraudAlert alert) {
    final color = _getAlertColor(alert.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getAlertIcon(alert.type), size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      _getAlertLabel(alert.type),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(alert.timestamp),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Utilisateur #${alert.userId.substring(0, 8)}...',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.description,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  // View user profile
                },
                icon: const Icon(Icons.person_search, size: 16),
                label: const Text('Voir Profil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(securityProvider.notifier).resolveAlert(alert.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Alerte résolue'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Résoudre'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _getAlertColor(SecurityAlert type) {
    switch (type) {
      case SecurityAlert.lowHonorScoreCircleJoin:
        return Colors.orange;
      case SecurityAlert.multipleCircleAttempt:
        return Colors.amber;
      case SecurityAlert.unverifiedCircleAction:
        return Colors.blue;
      case SecurityAlert.suspiciousPaymentPattern:
        return Colors.red;
      case SecurityAlert.walletFrozen:
        return Colors.purple;
    }
  }

  IconData _getAlertIcon(SecurityAlert type) {
    switch (type) {
      case SecurityAlert.lowHonorScoreCircleJoin:
        return Icons.trending_down;
      case SecurityAlert.multipleCircleAttempt:
        return Icons.group_add;
      case SecurityAlert.unverifiedCircleAction:
        return Icons.verified_user;
      case SecurityAlert.suspiciousPaymentPattern:
        return Icons.payment;
      case SecurityAlert.walletFrozen:
        return Icons.lock;
    }
  }

  String _getAlertLabel(SecurityAlert type) {
    switch (type) {
      case SecurityAlert.lowHonorScoreCircleJoin:
        return 'Score bas + Multi-cercles';
      case SecurityAlert.multipleCircleAttempt:
        return 'Tentatives multiples';
      case SecurityAlert.unverifiedCircleAction:
        return 'Action sans KYC';
      case SecurityAlert.suspiciousPaymentPattern:
        return 'Paiement suspect';
      case SecurityAlert.walletFrozen:
        return 'Wallet gelé';
    }
  }
}
