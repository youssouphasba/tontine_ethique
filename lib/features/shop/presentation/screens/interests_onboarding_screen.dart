import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/shop_feed_provider.dart';

/// Interests Onboarding Screen
/// TikTok-style selection of product categories
/// 
/// Features:
/// - Wide range of categories (35+)
/// - Visual chips selection
/// - Minimum 3 required

class InterestsOnboardingScreen extends ConsumerStatefulWidget {
  const InterestsOnboardingScreen({super.key});

  @override
  ConsumerState<InterestsOnboardingScreen> createState() => _InterestsOnboardingScreenState();
}

class _InterestsOnboardingScreenState extends ConsumerState<InterestsOnboardingScreen> {
  final Set<ProductInterest> _selectedInterests = {};

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedInterests.length >= 3;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Vos Centres d\'Intérêt'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue,
        actions: [
          TextButton(
            onPressed: canContinue ? _saveAndContinue : null,
            child: Text('Suivant', style: TextStyle(color: canContinue ? Colors.white : Colors.white38)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.deepPurple.shade50,
            child: Column(
              children: [
                Icon(
                  Icons.interests, 
                  size: 48, 
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                ),
                const SizedBox(height: 12),
                Text(
                  'Qu\'est-ce qui vous intéresse ?',
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sélectionnez au moins 3 catégories pour personnaliser votre boutique',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedInterests.length >= 3 ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedInterests.length} sélectionné${_selectedInterests.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Categories
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySection('👗 Mode & Accessoires', [
                    ProductInterest.fashionWomen,
                    ProductInterest.fashionMen,
                    ProductInterest.fashionKids,
                    ProductInterest.accessories,
                    ProductInterest.shoes,
                    ProductInterest.jewelry,
                  ]),
                  _buildCategorySection('💄 Beauté & Bien-être', [
                    ProductInterest.skincare,
                    ProductInterest.makeup,
                    ProductInterest.haircare,
                    ProductInterest.perfume,
                    ProductInterest.wellness,
                  ]),
                  _buildCategorySection('🍽️ Alimentation', [
                    ProductInterest.localFood,
                    ProductInterest.restaurants,
                    ProductInterest.bakery,
                    ProductInterest.beverages,
                    ProductInterest.organic,
                  ]),
                  _buildCategorySection('🏠 Maison', [
                    ProductInterest.furniture,
                    ProductInterest.decoration,
                    ProductInterest.kitchen,
                    ProductInterest.garden,
                  ]),
                  _buildCategorySection('📱 Électronique', [
                    ProductInterest.phones,
                    ProductInterest.computers,
                    ProductInterest.gaming,
                    ProductInterest.audio,
                  ]),
                  _buildCategorySection('🔧 Services', [
                    ProductInterest.beautyServices,
                    ProductInterest.repairs,
                    ProductInterest.coaching,
                    ProductInterest.transport,
                    ProductInterest.events,
                  ]),
                  _buildCategorySection('🎨 Artisanat & Art', [
                    ProductInterest.artisanal,
                    ProductInterest.handmade,
                    ProductInterest.traditional,
                    ProductInterest.art,
                  ]),
                  _buildCategorySection('📦 Autres', [
                    ProductInterest.sports,
                    ProductInterest.nutrition,
                    ProductInterest.pets,
                    ProductInterest.kids,
                    ProductInterest.books,
                    ProductInterest.music,
                  ]),
                ],
              ),
            ),
          ),

          // Bottom button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue ? _saveAndContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.marineBlue : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(canContinue ? 'Découvrir la Boutique' : 'Sélectionnez ${3 - _selectedInterests.length} de plus'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, List<ProductInterest> interests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: interests.map((interest) => _buildInterestChip(interest)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInterestChip(ProductInterest interest) {
    final isSelected = _selectedInterests.contains(interest);
    final label = getInterestLabel(interest);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedInterests.add(interest);
          } else {
            _selectedInterests.remove(interest);
          }
        });
      },
      selectedColor: (Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue).withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.marineBlue : AppTheme.marineBlue,
      labelStyle: TextStyle(
        color: isSelected 
            ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.marineBlue) 
            : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _saveAndContinue() {
    ref.read(shopFeedProvider.notifier).setInterests(_selectedInterests.toList());
    Navigator.pop(context);
  }
}
