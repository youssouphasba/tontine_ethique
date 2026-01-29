import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:tontetic/core/providers/subscription_provider.dart';
import 'package:tontetic/core/models/plan_model.dart';

class EnterpriseSubscriptionScreen extends ConsumerWidget {
  const EnterpriseSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSubscription = ref.watch(subscriptionProvider);
    final enterprisePlansAsync = ref.watch(enterprisePlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans Entreprise'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.indigo.shade900 : Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: enterprisePlansAsync.when(
        data: (plans) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            _buildHeader(context),
            
            const SizedBox(height: 24),

            // Current plan indicator
            if (currentSubscription != null)
              _buildCurrentPlanIndicator(currentSubscription),

            // Plan cards
            ...plans.map((plan) => _buildPlanCard(
              context,
              plan,
              isCurrentPlan: currentSubscription?.plan.id == plan.id,
            )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏢 Tontetic Corporate',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez le plan adapté à votre entreprise',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          // Flexibility note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PlanLimits.flexibilityNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanIndicator(CompanySubscription currentSubscription) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Text(
            'Plan actuel: ${currentSubscription.plan.name}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const Spacer(),
          Text(
            '${currentSubscription.currentEmployees}/${currentSubscription.maxEmployees} salariés',
            style: TextStyle(color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    Plan plan, {
    bool isCurrentPlan = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planColors = _getPlanColors(plan, isDark);
    final maxEmployees = plan.getLimit<int>('maxEmployees', 0);
    final maxTontines = plan.getLimit<int>('maxCircles', 0);
    final priceEur = plan.getPrice('EUR');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCurrentPlan ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentPlan 
            ? BorderSide(color: planColors['primary']!, width: 3)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [planColors['light']!, planColors['primary']!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      priceEur == 0 
                          ? 'Sur devis'
                          : '${priceEur.toStringAsFixed(2)}€/mois',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                if (isCurrentPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: planColors['primary'], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'ACTUEL',
                          style: TextStyle(
                            color: planColors['primary'],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.people,
                        maxEmployees >= 999999 ? 'Illimité' : '$maxEmployees',
                        'Salariés max',
                        planColors['primary']!,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem(
                        Icons.groups,
                        maxTontines >= 999999 ? 'Illimité' : '$maxTontines',
                        'Tontines',
                        planColors['primary']!,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Features
                const Text(
                  'Fonctionnalités incluses:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: plan.features.map((f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: planColors['primary']!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 11,
                        color: planColors['primary'],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),

                const SizedBox(height: 16),

                // CTA Button
                if (!isCurrentPlan)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handlePlanSelection(context, plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: planColors['primary'],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        priceEur == 0 
                            ? 'Demander un devis'
                            : 'Choisir ce plan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _getPlanColors(Plan plan, bool isDark) {
    // Dynamic color mapping based on plan code or order
    if (plan.code.contains('STARTER')) {
      return {'primary': isDark ? Colors.blue.shade400 : Colors.blue.shade600, 'light': isDark ? Colors.blue.shade900 : Colors.blue.shade400};
    } else if (plan.code.contains('TEAM')) {
      return {'primary': isDark ? Colors.teal.shade400 : Colors.teal.shade600, 'light': isDark ? Colors.teal.shade900 : Colors.teal.shade400};
    } else if (plan.code.contains('DEPT')) {
      return {'primary': isDark ? Colors.orange.shade400 : Colors.orange.shade600, 'light': isDark ? Colors.orange.shade900 : Colors.orange.shade400};
    } else if (plan.code.contains('ENTERPRISE')) {
      return {'primary': isDark ? Colors.purple.shade400 : Colors.purple.shade600, 'light': isDark ? Colors.purple.shade900 : Colors.purple.shade400};
    } else if (plan.code.contains('UNLIMITED')) {
      return {'primary': isDark ? Colors.indigo.shade400 : Colors.indigo.shade800, 'light': isDark ? Colors.indigo.shade900 : Colors.indigo.shade600};
    }
    return {'primary': Colors.indigo, 'light': Colors.indigo.shade300};
  }

  void _handlePlanSelection(BuildContext context, Plan plan) {
    final priceEur = plan.getPrice('EUR');
    if (priceEur == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Demande de devis'),
          content: Text(
            'Le plan ${plan.name} est personnalisé selon vos besoins.\n\n'
            'Notre équipe commerciale vous contactera pour établir un devis adapté.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📧 Demande envoyée !')),
                );
              },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Passer au plan ${plan.name} ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${plan.getLimit('maxEmployees', 0)} salariés max'),
              Text('${plan.getLimit('maxCircles', 0)} tontines max'),
              Text('${priceEur.toStringAsFixed(2)}€/mois'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Plan ${plan.name} activé !')),
                );
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
    }
  }
}
