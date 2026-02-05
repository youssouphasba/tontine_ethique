import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:intl/intl.dart';

/// Payment History Screen
/// Displays all pot transactions: received, paid, and failed
class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  String _filter = 'all'; // all, received, paid, failed
  
  // Transaction data is fetched from Firestore


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final l10n = ref.watch(localizationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;



    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('payment_history_title')),
        backgroundColor: isDark ? Colors.black : AppTheme.marineBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: user.uid)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             // Fallback for missing index or other errors
             debugPrint("Transaction Stream Error: ${snapshot.error}");
             return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Convert docs to list of maps
          final allTransactions = snapshot.data?.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Ensure date is DateTime
            if (data['date'] is Timestamp) {
               data['date'] = (data['date'] as Timestamp).toDate();
            }
            // Add ID
            data['id'] = doc.id;
            return data;
          }).toList() ?? [];

          // Filter
          final filteredTransactions = allTransactions.where((tx) {
            if (_filter == 'all') return true;
            if (_filter == 'failed') return tx['status'] == 'failed';
            return tx['type'] == _filter;
          }).toList();

          // Calculate totals
          final totalReceived = allTransactions
              .where((t) => t['type'] == 'received' && t['status'] == 'success')
              .fold(0.0, (total, t) => total + ((t['amount'] as num).toDouble()));
          final totalPaid = allTransactions
              .where((t) => t['type'] == 'paid' && t['status'] == 'success')
              .fold(0.0, (total, t) => total + ((t['amount'] as num).toDouble()));

          return Column(
            children: [
              // Summary Cards
              Container(
                padding: const EdgeInsets.all(16),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.arrow_downward,
                        label: l10n.translate('filter_received'),
                        amount: totalReceived,
                        color: Colors.green,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.arrow_upward,
                        label: l10n.translate('filter_paid'),
                        amount: totalPaid,
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('all', l10n.translate('filter_all'), isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('received', l10n.translate('filter_received'), isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('paid', l10n.translate('filter_paid'), isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('failed', l10n.translate('filter_failed'), isDark),
                  ],
                ),
              ),
              
              // Transaction List
              Expanded(
                child: filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              l10n.translate('no_transactions'),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = filteredTransactions[index];
                          return _buildTransactionCard(tx, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${amount.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      selectedColor: AppTheme.gold.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected 
            ? (isDark ? AppTheme.gold : AppTheme.marineBlue)
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx, bool isDark) {
    final type = tx['type'] as String;
    final isReceived = type == 'received';
    final isFailed = tx['status'] == 'failed';
    
    Color iconColor;
    IconData icon;
    
    if (isFailed) {
      iconColor = Colors.red;
      icon = Icons.warning_amber;
    } else if (isReceived) {
      iconColor = Colors.green;
      icon = Icons.arrow_downward;
    } else {
      iconColor = Colors.orange;
      icon = Icons.arrow_upward;
    }

    final date = tx['date'] as DateTime;
    final formattedDate = DateFormat('dd MMM yyyy', 'fr_FR').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFailed 
              ? Colors.red.withValues(alpha: 0.3) 
              : (isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => _showTransactionDetails(tx),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx['circleName'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pot #${tx['potNumber']} • $formattedDate',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  if (isFailed) ...[
                    const SizedBox(height: 4),
                    Text(
                      tx['errorReason'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isReceived ? '+' : '-'}${tx['amount']}${tx['currency']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isFailed ? Colors.red : (isReceived ? Colors.green : Colors.orange),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isFailed 
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFailed ? ref.read(localizationProvider).translate('tx_status_failed') : ref.read(localizationProvider).translate('tx_status_success'),
                    style: TextStyle(
                      fontSize: 10,
                      color: isFailed ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = ref.read(localizationProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.translate('tx_details_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(l10n.translate('tx_circle'), tx['circleName'], isDark),
              _buildDetailRow(l10n.translate('tx_pot_number'), '#${tx['potNumber']}', isDark),
              _buildDetailRow(l10n.translate('tx_type'), tx['type'] == 'received' ? l10n.translate('tx_type_received') : l10n.translate('tx_type_contribution'), isDark),
              _buildDetailRow(l10n.translate('tx_amount'), '${tx['amount']} ${tx['currency']}', isDark),
              _buildDetailRow(l10n.translate('tx_date'), DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(tx['date']), isDark),
              _buildDetailRow(l10n.translate('tx_status'), tx['status'] == 'success' ? '✓ ${l10n.translate('tx_status_success')}' : '✗ ${l10n.translate('tx_status_failed')}', isDark),
              if (tx['errorReason'] != null)
                _buildDetailRow(l10n.translate('tx_reason'), tx['errorReason'], isDark),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.translate('close')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.marineBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
