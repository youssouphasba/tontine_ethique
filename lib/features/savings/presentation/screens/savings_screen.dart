import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/constants/legal_texts.dart';
import 'package:tontetic/features/savings/data/locked_savings_provider.dart';

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  final _amountController = TextEditingController();
  final _objectiveController = TextEditingController();
  DateTime? _unlockDate;
  SavingsPurpose _selectedPurpose = SavingsPurpose.personalProject;
  bool _disclaimerAccepted = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Date de déblocage (IMMUTABLE)',
      confirmText: 'Confirmer',
      cancelText: 'Annuler',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.marineBlue,
              onPrimary: AppTheme.gold,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _unlockDate) {
      setState(() => _unlockDate = picked);
    }
  }

  Future<void> _createLockedSavings() async {
    if (_amountController.text.isEmpty || _unlockDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir montant et date.')),
      );
      return;
    }

    if (!_disclaimerAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions légales.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final objective = _objectiveController.text.isEmpty ? 'Épargne' : _objectiveController.text;
    final user = ref.read(userProvider);

    // Confirmation finale (règles IMMUTABLES)
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('⚠️ Confirmation Finale'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ATTENTION : Ces paramètres seront IMMUTABLES',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            _buildConfirmRow('Montant', ref.read(userProvider.notifier).formatContent(amount)),
            _buildConfirmRow('Objectif', objective),
            _buildConfirmRow('Déblocage', DateFormat('dd/MM/yyyy').format(_unlockDate!)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange),
              ),
              child: const Text(
                'Aucune modification possible après validation.\n'
                'Déblocage automatique à la date prévue.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
            child: const Text('CONFIRMER (IRRÉVERSIBLE)'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final savings = await ref.read(lockedSavingsProvider.notifier).createLockedSavings(
      userId: user.phoneNumber,
      amount: amount,
      currency: user.zone.currency,
      purpose: _selectedPurpose,
      purposeLabel: objective,
      unlockDate: _unlockDate!,
    );

    if (savings != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Épargne bloquée créée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savingsState = ref.watch(lockedSavingsProvider);
    final user = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocage Volontaire'),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.marineBlue, Color(0xFF152642)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock, color: AppTheme.gold, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Blocage Volontaire de Fonds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(
                              'Total bloqué : ${ref.read(userProvider.notifier).formatContent(savingsState.totalLocked)}',
                              style: const TextStyle(color: AppTheme.gold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fonds chez PSP (Stripe/Wave) • Aucun intérêt • Aucun rendement',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Blocages actifs
            if (savingsState.activeSavings.isNotEmpty) ...[
              const Text('Fonds Bloqués Actifs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...savingsState.activeSavings.map((s) => _buildActiveSavingsCard(s)),
              const SizedBox(height: 24),
            ],

            // Formulaire nouveau blocage
            Text('Nouveau Blocage Volontaire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),

            // Type
            DropdownButtonFormField<SavingsPurpose>(
              initialValue: _selectedPurpose,
              decoration: const InputDecoration(
                labelText: 'Type de blocage',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: SavingsPurpose.personalProject, child: Text('Projet Personnel (Tabaski, rentrée...)')),
                DropdownMenuItem(value: SavingsPurpose.tontineGuarantee, child: Text('Garantie Tontine (1 cotisation)')),
                DropdownMenuItem(value: SavingsPurpose.tontineContributions, child: Text('Préfinancement Cotisations')),
              ],
              onChanged: (v) => setState(() => _selectedPurpose = v!),
            ),

            const SizedBox(height: 16),

            // Objectif
            TextField(
              controller: _objectiveController,
              decoration: const InputDecoration(
                labelText: 'Nom du projet (ex: Tabaski 2026)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),

            const SizedBox(height: 16),

            // Montant
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant à bloquer (${user.zone.currency})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),

            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _unlockDate == null
                            ? 'Déblocage (IMMUTABLE)'
                            : 'Déblocage : ${DateFormat('dd/MM/yyyy').format(_unlockDate!)}',
                        style: TextStyle(
                            fontSize: 14,
                            color: _unlockDate == null 
                            ? Colors.grey 
                            : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Disclaimer légal OBLIGATOIRE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.gavel, color: Colors.red),
                          SizedBox(width: 8),
                          Text('CGU Article 8 - Épargne Bloquée', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _showFullCgu(context),
                        child: const Text('Voir tout', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LockedSavingsNotifier.getLegalDisclaimer(),
                    style: const TextStyle(fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _disclaimerAccepted,
                    onChanged: (v) => setState(() => _disclaimerAccepted = v!),
                    title: const Text(
                      'J\'accepte l\'Article 4 CGU - Blocage Volontaire (IRRÉVOCABLE)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.marineBlue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton création
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _disclaimerAccepted ? _createLockedSavings : null,
                icon: const Icon(Icons.lock),
                label: const Text('BLOQUER CES FONDS (IRRÉVERSIBLE)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _disclaimerAccepted ? AppTheme.marineBlue : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      ), // SafeArea close
    );
  }

  Widget _buildActiveSavingsCard(LockedSavings savings) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
          child: const Icon(Icons.lock, color: AppTheme.gold),
        ),
        title: Text(savings.purposeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.read(userProvider.notifier).formatContent(savings.amount)),
            Text(
              'Bloqué jusqu\'au ${DateFormat('dd/MM/yyyy').format(savings.unlockDate)}',
              style: TextStyle(fontSize: 11, color: savings.isUnlockDue ? Colors.green : Colors.grey),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: savings.isUnlockDue ? Colors.green : Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            savings.isUnlockDue ? 'Libéré' : 'J-${savings.daysUntilUnlock}',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showFullCgu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CONDITIONS GÉNÉRALES D\'UTILISATION',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Article 8 - Épargne Bloquée',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    LegalTexts.epargneBloqueeFullCgu,
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
                  child: const Text('J\'ai compris'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

