import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/features/tontine/presentation/screens/create_tontine_screen.dart';
import 'package:tontetic/features/shop/presentation/screens/boutique_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/shop_feed_provider.dart';
import 'package:tontetic/core/providers/localization_provider.dart';

class TontineSimulatorScreen extends ConsumerStatefulWidget {
  const TontineSimulatorScreen({super.key});

  @override
  ConsumerState<TontineSimulatorScreen> createState() => _TontineSimulatorScreenState();
}

class _TontineSimulatorScreenState extends ConsumerState<TontineSimulatorScreen> {
  double? _targetAmount;
  double? _monthlyContribution;
  String _categoryTag = 'Smartphone';

  // V15: Extended categories to match merchant categories
  final List<Map<String, dynamic>> _objectiveCategories = [
    {'name': 'Smartphone', 'icon': Icons.smartphone},
    {'name': 'Informatique', 'icon': Icons.computer},
    {'name': 'Électroménager', 'icon': Icons.kitchen},
    {'name': 'Moto/Véhicule', 'icon': Icons.two_wheeler},
    {'name': 'Voyage', 'icon': Icons.flight},
    {'name': 'Mariage', 'icon': Icons.favorite},
    {'name': 'Fêtes', 'icon': Icons.celebration},
    {'name': 'Mode/Vêtements', 'icon': Icons.checkroom},
    {'name': 'Bijoux', 'icon': Icons.diamond},
    {'name': 'Maison/Déco', 'icon': Icons.home},
    {'name': 'Éducation', 'icon': Icons.school},
    {'name': 'Santé', 'icon': Icons.medical_services},
    {'name': 'Artisanat', 'icon': Icons.handyman},
    {'name': 'Alimentation', 'icon': Icons.restaurant},
    {'name': 'Autre', 'icon': Icons.category},
  ];

  double _calculateNet(double amount) {
    // Simulation: 3.5% PSP Fees (Stripe/Wave/Orange)
    return amount * 0.965;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    final l10n = ref.watch(localizationProvider);
    
    // Initialize values based on zone if not already set
    final isEuro = user.zone == UserZone.zoneEuro;
    _targetAmount ??= isEuro ? 1000.0 : 500000.0;
    _monthlyContribution ??= isEuro ? 100.0 : 50000.0;
    
    // Ensure values are within bounds
    final maxContribution = isEuro ? 500.0 : 325000.0;
    final minContribution = isEuro ? 10.0 : 5000.0;
    if (_monthlyContribution! > maxContribution) _monthlyContribution = maxContribution;
    if (_monthlyContribution! < minContribution) _monthlyContribution = minContribution;
    
    final monthsSolo = (_targetAmount! / _monthlyContribution!).ceil();
    final monthsTontineAvg = (monthsSolo / 2).ceil();
    final netAmount = _calculateNet(_targetAmount!);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Simulation de Tontine'), // V15: Renamed
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLogicExplainer(context, ref),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Theme - V15: Changed to purple gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.language == AppLanguage.wo ? 'Natt ba mu nekk dëgg' : 'Simulez Votre Objectif',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.language == AppLanguage.wo 
                      ? 'Naka ngay pareelle sa jëndu $_categoryTag ?'
                      : 'Trouvez le marchand idéal pour votre projet $_categoryTag',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inputs
                  _buildGoalInput(),
                  const SizedBox(height: 24),
                  
                  // The Comparison Section
                  Text(l10n.language == AppLanguage.wo ? 'L\'Effet Tontine : Sama Bopp vs Mbooloo' : 'L\'Effet Tontine : Solo vs Groupe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple)),
                  const SizedBox(height: 16),
                  _buildCoachMessage(ref),
                  const SizedBox(height: 16),
                  _buildComparisonView(monthsSolo, monthsTontineAvg, netAmount, ref),

                  const SizedBox(height: 32),

                  // V15: Merchant Section - now filtered by category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Équipements & Projets',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16, 
                            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BoutiqueScreen())), 
                        child: Text(
                          'Voir tout',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMerchantProducts(),

                  const SizedBox(height: 32),

                  // Honor Score Tip
                  _buildHonorScoreTip(),
                  
                  const SizedBox(height: 120), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // V15: Navigate to tontine creation
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTontineScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.marineBlue : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  l10n.language == AppLanguage.wo ? 'SAMP NATT' : 'CRÉER UNE TONTINE', 
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                l10n.translate('sim_legal_note'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, 
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : const Color(0xFF666666), 
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalInput() {
    final user = ref.read(userProvider);
    final l10n = ref.watch(localizationProvider);
    final currency = user.currencySymbol;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _categoryTag,
              decoration: InputDecoration(
                labelText: l10n.language == AppLanguage.wo ? 'Sama Objectif' : 'Mon Objectif', 
                prefixIcon: Icon(_objectiveCategories.firstWhere((c) => c['name'] == _categoryTag)['icon'] as IconData),
              ),
              items: _objectiveCategories
                  .map((c) => DropdownMenuItem(value: c['name'] as String, child: Row(
                    children: [
                      Icon(
                        c['icon'] as IconData, 
                        size: 20, 
                        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple,
                      ),
                      const SizedBox(width: 12),
                      Text(c['name'] as String),
                    ],
                  ))).toList(),
              onChanged: (v) => setState(() => _categoryTag = v!),
            ),
            const SizedBox(height: 16),
            _buildCustomSlider(
               title: l10n.translate('sim_target_amount'),
               value: _targetAmount!,
               min: user.zone == UserZone.zoneEuro ? 100 : 10000,
               max: user.zone == UserZone.zoneEuro ? 5000 : 2000000,
               suffix: ' $currency',
               onChanged: (v) => setState(() => _targetAmount = v),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                l10n.language == AppLanguage.wo 
                  ? 'Frais PSP (3.5% ñu bokan ak Wave/Orange Money) dañu koy wàññi.'
                  : 'Note: Les frais PSP (3.5% reversés à Stripe/Wave) seront déduits lors de la perception du pot.',
                style: const TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                l10n.language == AppLanguage.wo 
                  ? 'Plafond mbooloo mbindu : ${user.zone == UserZone.zoneEuro ? 500 : 325000} $currency.'
                  : 'Plafond universel : ${user.zone == UserZone.zoneEuro ? 500 : 325000} $currency / mois.',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            _buildCustomSlider(
               title: l10n.translate('sim_monthly_contribution'),
               value: _monthlyContribution!,
               min: user.zone == UserZone.zoneEuro ? 10 : 5000,
               max: user.zone == UserZone.zoneEuro ? 500 : 325000,
               suffix: ' $currency',
               onChanged: (v) => setState(() => _monthlyContribution = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonView(int soloResult, int tontineResult, double netPerceived, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    return Column(
      children: [
        _buildTimelineBar(
          label: l10n.translate('sim_solo_label'),
          months: soloResult,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey.shade400,
          icon: Icons.hourglass_bottom, // Turtle-equivalent metaphor
          isBest: false,
        ),
        const SizedBox(height: 12),
        _buildTimelineBar(
          label: l10n.translate('sim_tontine_label'),
          months: tontineResult,
          color: AppTheme.marineBlue,
          icon: l10n.language == AppLanguage.wo ? Icons.bolt : Icons.flight_takeoff, // Bolt or Plane for Tontine
          isBest: true,
          subtitle: l10n.language == AppLanguage.wo 
            ? 'Li nga wara jot : ${netPerceived.toInt()} FCFA (bo wàññee frais PSP) ✨'
            : 'Net à percevoir : ${netPerceived.toInt()} FCFA (après frais PSP) ✨',
        ),
      ],
    );
  }

  Widget _buildTimelineBar({
    required String label,
    required int months,
    required Color color,
    required IconData icon,
    required bool isBest,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBest 
            ? (Theme.of(context).brightness == Brightness.dark 
                ? AppTheme.marineBlue.withValues(alpha: 0.3) 
                : AppTheme.marineBlue.withValues(alpha: 0.05))
            : (Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF2C2C2C) 
                : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBest 
              ? (Theme.of(context).brightness == Brightness.dark 
                  ? AppTheme.gold.withValues(alpha: 0.3) 
                  : AppTheme.marineBlue.withValues(alpha: 0.2))
              : (Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey.shade700 
                  : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: isBest ? AppTheme.marineBlue : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey)),
              const SizedBox(width: 8),
              Text(
                label, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 13, 
                  color: isBest 
                      ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue) 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey),
                ),
              ),
              const Spacer(),
              Text(
                '$months ${months > 1 ? 'weer' : 'weer'}', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: isBest 
                      ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue) 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8, 
                width: double.infinity, 
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200], 
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 8,
                width: (MediaQuery.of(context).size.width - 80) * (1 - (months / 48).clamp(0, 1)), // Mock scale
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
          ]
        ],
      ),
    );
  }

  ProductInterest? _mapCategoryToInterest(String category) {
    switch (category) {
      case 'Smartphone': return ProductInterest.phones;
      case 'Informatique': return ProductInterest.computers;
      case 'Électroménager': return ProductInterest.kitchen; // Close match
      case 'Moto/Véhicule': return ProductInterest.transport;
      case 'Voyage': return ProductInterest.events; // Or new category
      case 'Mariage': return ProductInterest.fashionWomen; // Often dress/attire
      case 'Fêtes': return ProductInterest.events;
      case 'Mode/Vêtements': return ProductInterest.fashionWomen; // Generalize
      case 'Bijoux': return ProductInterest.jewelry;
      case 'Maison/Déco': return ProductInterest.furniture;
      case 'Éducation': return ProductInterest.books;
      case 'Santé': return ProductInterest.wellness;
      case 'Artisanat': return ProductInterest.artisanal;
      case 'Alimentation': return ProductInterest.localFood;
      default: return null;
    }
  }

  Widget _buildMerchantProducts() {
    final interest = _mapCategoryToInterest(_categoryTag);
    
    // Query directly from Firestore for now
    // In a real app, this should be in a Repository/Provider
    Query query = FirebaseFirestore.instance.collection('products')
        .where('interests', arrayContains: interest?.name ?? 'phones') // Default fallback if null, though handled
        .limit(10);
        
    // If no specific interest mapped (e.g. "Autre"), just show latest
    if (interest == null) {
       query = FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).limit(10);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interest != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Produits disponibles pour "$_categoryTag" :',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
        SizedBox(
          height: 130,
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return _buildEmptyState(interest);
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  // Safe casting
                  final name = data['name'] ?? 'Produit';
                  final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                  final currency = data['currency'] ?? 'FCFA';
                  final shopName = data['shopName'] ?? 'Marchand';
                  
                  // In a real scenario, use actual icons from interests or images
                  // Here we use a generic icon map or list first icon
                  
                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.deepPurple.shade50),
                      boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.08), blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.deepPurple.shade50, 
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag, // Generic icon for real products without image
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                '${price.toInt()} $currency', 
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                shopName, 
                                style: TextStyle(
                                  fontSize: 10, 
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey,
                                ), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ProductInterest? interest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2), style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            interest != null 
              ? 'Aucun produit trouvé pour cette catégorie.' 
              : 'Aucun produit disponible pour le moment.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Soyez le premier marchand à proposer cela !',
            style: TextStyle(color: Colors.deepPurple[300], fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHonorScoreTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.stars, color: AppTheme.gold),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Avec un Score d\'Honneur > 80, vous accédez à des cercles marchands avec livraison immédiate ! 📦',
              style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.marineBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachMessage(WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.marineBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              Text(l10n.translate('coach_signature'), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('sim_coach_expl'),
            style: TextStyle(fontSize: 13, height: 1.5, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSlider({required String title, required double value, required double min, required double max, required String suffix, required ValueChanged<double> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${value.toInt()}$suffix', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showLogicExplainer(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(localizationProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.language == AppLanguage.wo ? 'Naka la natt di doxé' : 'Outil d\'Aide à la Décision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.language == AppLanguage.wo 
              ? 'Lii ab illustration la rekk ngir nga xam naka ngay gawante ak natt bi.' 
              : 'Ce simulateur est un outil d\'illustration technique et non un conseil financier personnalisé.'),
            const SizedBox(height: 12),
            Text(l10n.language == AppLanguage.wo ? '⚠️ SEYTU NI NGAY FEYEE :' : '⚠️ ALÉA SOCIAL :', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            Text(l10n.language == AppLanguage.wo 
              ? 'Natt bi ci koolute ak takku ci membre yi la depand. Bu kenn gataxé (retard), dina la yéxeel sa kàttan.'
              : 'Le bénéfice de la tontine repose sur l\'assiduité de tous les membres. En cas de défaut de paiement d\'un membre, le calendrier de versement peut être impacté.'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}
