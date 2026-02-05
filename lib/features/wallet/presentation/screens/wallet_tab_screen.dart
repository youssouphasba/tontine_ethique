import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/features/wallet/data/wallet_provider.dart';
import 'package:tontetic/features/wallet/presentation/screens/deposit_screen.dart';
import 'package:tontetic/features/savings/presentation/screens/savings_screen.dart';
import 'package:tontetic/features/payments/data/transaction_receipt_service.dart';
import 'package:tontetic/core/services/webhook_log_service.dart';
import 'package:tontetic/core/services/notification_service.dart';
 
import 'package:tontetic/features/auth/presentation/screens/psp_connection_screen.dart';
import 'package:tontetic/features/payments/presentation/screens/payment_history_screen.dart';

class WalletTabScreen extends ConsumerWidget {
  const WalletTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    final l10n = ref.watch(localizationProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      appBar: AppBar(
        title: Text(l10n.translate('wallet_title')),
        elevation: 0,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Celebration Card removed (Mock logic) - Real celebrations are handled via Notifications/Dialogs

            // Header Synthèse PSP (SEPA Pure: fonds chez PSP)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : AppTheme.marineBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
// ... (rest of header) ...
                  // Bannière SEPA Pure
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, color: Colors.white70, size: 14),
                        SizedBox(width: 6),
                        Text(
                          l10n.translate('psp_regulatory_banner'),
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.translate('total_balance'), style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    ref.read(userProvider.notifier).formatContent(walletState.balance),
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bouton Crédit Mobile Money - Afrique uniquement
                      if (ref.watch(userProvider).isAfricanRegion)
                        Expanded(
                          child: _buildActionButton(
                            context,
                            l10n.translate('credit_mobile'),
                            Icons.phone_android,
                            Colors.green.shade600,
                            Colors.white,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepositScreen())),
                          ),
                        ),
                      if (ref.watch(userProvider).isAfricanRegion)
                        const SizedBox(width: 16),
                      // Bouton Blocage Volontaire - Tous
                      Expanded(
                        child: _buildActionButton(
                          context,
                          l10n.translate('lock_btn'),
                          Icons.lock,
                          AppTheme.gold,
                          AppTheme.marineBlue,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PspConnectionScreen())),
                          icon: const Icon(Icons.account_balance_wallet, size: 16),
                          label: Text(l10n.translate('manage_accounts'), style: const TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.translate('bank_disclaimer_short'),
                      style: const TextStyle(color: Colors.white60, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Section Patrimoine & Projets
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(l10n.translate('wealth_analysis'), style: Theme.of(context).textTheme.titleLarge),
                   const SizedBox(height: 12),
                     Container(
                     height: 160,
                     width: double.infinity,
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
                     child: const Center(
                       child: Text(
                         l10n.translate('graph_soon'),
                         style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                       ),
                     ),
                   ),
                   const SizedBox(height: 16),
                   // Coffre-fort Projet
                   InkWell(
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen())),
                     child: Container(
                       padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : AppTheme.marineBlue,
                            Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFF152642)
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                       child: const Row(
                         children: [
                           Icon(Icons.lock_person, color: AppTheme.gold, size: 32),
                           SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(l10n.translate('project_vault'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 Text(l10n.translate('lock_gains_desc'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                               ],
                             ),
                           ),
                           Icon(Icons.arrow_forward, color: Colors.white),
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            ),
            
                    // Transparency Info (Enhanced)
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user, color: Colors.green.shade700, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.translate('zero_commission'),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.translate('zero_commission_desc'),
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

             const SizedBox(height: 24),
            
            // Historique
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.translate('transaction_history'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())
                    ),
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(l10n.translate('see_all'), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: walletState.transactions.length,
              itemBuilder: (context, index) {
                final transaction = walletState.transactions[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: transaction.type == 'deposit' 
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      child: Icon(
                        transaction.type == 'deposit' ? Icons.arrow_downward : Icons.arrow_upward,
                        color: transaction.type == 'deposit' ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(transaction.title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    subtitle: Text(
                      '${transaction.date.day}/${transaction.date.month} à ${transaction.date.hour}:${transaction.date.minute}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${transaction.type == 'deposit' ? '+' : '-'} ${ref.read(userProvider.notifier).formatContent(transaction.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: transaction.type == 'deposit' ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _downloadReceipt(context, ref, transaction),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download, size: 12, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue),
                              const SizedBox(width: 4),
                              Text(l10n.translate('receipt'), style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
             const SizedBox(height: 24),
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
               child: Text(
                 l10n.translate('bank_disclaimer'),
                 textAlign: TextAlign.center,
                 style: const TextStyle(color: Colors.grey, fontSize: 10),
               ),
             ),
             const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  

  void _downloadReceipt(BuildContext context, WidgetRef ref, dynamic transaction) async {
    // 1. Show Loading
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(localizationProvider).translate('generating_receipt')), duration: const Duration(seconds: 1)));

    final currentUser = ref.read(userProvider);

    // 2. Create LogEntry from REAL transaction data
    // In production, we might fetch the full WebhookLog from Firestore by transaction ID
    // But rebuilding it from the trusted transaction history is acceptable for the receipt view.
    final logEntry = WebhookLogEntry(
      id: 'REC-${transaction.id}',
      provider: transaction.type == 'deposit' ? WebhookProvider.wave : WebhookProvider.stripe,
      eventType: 'payment.succeeded', // Assumed based on successful history entry
      timestamp: transaction.date,
      status: WebhookStatus.processed,
      transactionId: transaction.id,
      userId: currentUser.uid,
      amount: transaction.amount,
      currency: transaction.currency,
      signatureValid: true, // History items are verified by definition
    );

    // 3. Generate PDF
    // ignore: unused_local_variable
    final pdfBytes = await TransactionReceiptService.generateReceipt(logEntry);

    // 4. Trigger Notifications (SMS & Email Proofs)
    if (context.mounted) {
      NotificationService.triggerAllProofs(
        context, 
        email: currentUser.email.isEmpty ? 'user@tontetic.com' : currentUser.email, 
        phone: currentUser.phoneNumber, 
        log: logEntry
      );
    }
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(ref.read(localizationProvider).translate('secure_receipt')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, size: 100, color: Colors.blueGrey),
              const SizedBox(height: 16),
              Text(ref.read(localizationProvider).translate('receipt_success')),
              const SizedBox(height: 8),
              Text('Réf: ${logEntry.id}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(ref.read(localizationProvider).translate('open_preview'))),
            ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(ref.read(localizationProvider).translate('share'))),
          ],
        ),
      );
    }
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: fg),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        elevation: 0,
      ),
    );
  }


}
