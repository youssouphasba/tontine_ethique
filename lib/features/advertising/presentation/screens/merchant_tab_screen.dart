import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/core/providers/merchant_account_provider.dart';
import 'package:tontetic/core/services/merchant_product_service.dart';
import 'package:tontetic/features/advertising/presentation/screens/merchant_registration_screen.dart';
import 'package:tontetic/features/advertising/presentation/screens/merchant_boost_screen.dart';
import 'package:tontetic/features/social/presentation/screens/direct_chat_screen.dart';

/// Riverpod provider for MerchantProductService
final merchantProductServiceProvider = Provider((ref) => MerchantProductService());

/// Riverpod provider for active products stream
final activeProductsProvider = StreamProvider<List<MerchantProduct>>((ref) {
  final productService = ref.watch(merchantProductServiceProvider);
  return productService.getActiveProducts(limit: 20);
});



/// V17.1 Merchant Tab - TikTok-style Discovery Feed with Dynamic Products
class MerchantTabScreen extends ConsumerStatefulWidget {
  const MerchantTabScreen({super.key});

  @override
  ConsumerState<MerchantTabScreen> createState() => _MerchantTabScreenState();
}

class _MerchantTabScreenState extends ConsumerState<MerchantTabScreen> {
  final PageController _pageController = PageController();
  final Set<String> _viewedProducts = {};

  @override
  void initState() {
    super.initState();
    // Merchant account is auto-loaded by merchantShopProvider when userProvider changes
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _trackProductView(MerchantProduct product) {
    // Only track view once per session per product
    if (!_viewedProducts.contains(product.id)) {
      _viewedProducts.add(product.id);
      ref.read(merchantProductServiceProvider).incrementViews(product.id);
    }
  }

  void _trackProductClick(MerchantProduct product) {
    ref.read(merchantProductServiceProvider).incrementClicks(product.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localizationProvider);
    final merchantState = ref.watch(merchantAccountProvider);
    final productsAsync = ref.watch(activeProductsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
             return Stack(
               children: [
                 const Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.storefront, size: 64, color: Colors.grey),
                       SizedBox(height: 16),
                       Text('Aucun produit disponible pour le moment', style: TextStyle(color: Colors.grey)),
                     ],
                   )
                 ),
                 if (!merchantState.hasMerchantAccount)
                  Positioned(
                    bottom: 80,
                    left: 16,
                    right: 16,
                    child: _buildBecomeMerchantBanner(context),
                  ),
                if (merchantState.hasMerchantAccount)
                  Positioned(
                    top: 100,
                    right: 12,
                    child: _buildMerchantDashboardButton(context, merchantState),
                  ),
               ],
             );
          }
          
          return Stack(
            children: [
              // Main content - Product feed
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: products.length,
                onPageChanged: (index) {
                  _trackProductView(products[index]);
                },
                itemBuilder: (context, index) => _buildProductCard(
                  context, 
                  products[index], 
                  index, 
                  products.length,
                  l10n,
                  false, // isDemo
                ),
              ),
              
              // Merchant account banner (if no account)
              if (!merchantState.hasMerchantAccount)
                Positioned(
                  bottom: 80,
                  left: 16,
                  right: 16,
                  child: _buildBecomeMerchantBanner(context),
                ),
              
              // Merchant dashboard button (if has account)
              if (merchantState.hasMerchantAccount)
                Positioned(
                  top: 100,
                  right: 12,
                  child: _buildMerchantDashboardButton(context, merchantState),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
        error: (error, stack) {
          return Center(child: Text('Erreur: $error', style: const TextStyle(color: Colors.white)));
        },
      ),
    );
  }

  Widget _buildBecomeMerchantBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MerchantRegistrationScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.marineBlue, Color(0xFF152642)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.gold, width: 2),
        ),
        child: const Row(
          children: [
            Icon(Icons.storefront, color: AppTheme.gold, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendez sur Tontetic',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Zéro commission • Paiements hors app',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppTheme.gold, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantDashboardButton(BuildContext context, MerchantAccountState state) {
    final account = state.account!;
    final isParticulier = account.type == MerchantType.particulier;
    
    return GestureDetector(
      onTap: () => _showMerchantQuickMenu(context, account),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gold),
        ),
        child: Column(
          children: [
            Icon(
              isParticulier ? Icons.person : Icons.verified,
              color: isParticulier ? Colors.white : AppTheme.gold,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              isParticulier ? 'Particulier' : 'Vérifié',
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
            const SizedBox(height: 2),
            Text(
              '${account.offresActives}/${isParticulier ? MerchantAccount.particulierOffresMax : '∞'}',
              style: const TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showMerchantQuickMenu(BuildContext context, MerchantAccount account) {
    final isParticulier = account.type == MerchantType.particulier;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isParticulier ? Colors.blue : Colors.purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isParticulier ? Icons.person : Icons.verified,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isParticulier ? 'Compte Particulier' : 'Compte Vérifié',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Offres: ${account.offresActives}/${isParticulier ? MerchantAccount.particulierOffresMax : '∞'}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (isParticulier)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CA: ${account.caAnnuel.toStringAsFixed(0)}€/${MerchantAccount.particulierCaMax.toStringAsFixed(0)}€',
                      style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Actions
            _buildMenuAction(
              icon: Icons.add_box,
              label: 'Publier une offre',
              onTap: () {
                Navigator.pop(ctx);
                if (!account.canPublishOffer) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(account.publishBlockReason ?? 'Publication impossible')),
                  );
                } else {
                  // Navigate to publish screen
                  // If screen exists, push it. Otherwise show detailed maintenance message.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Module de publication en cours de déploiement...')),
                  );
                }
              },
              enabled: account.canPublishOffer,
            ),
            
            _buildMenuAction(
              icon: Icons.rocket_launch,
              label: 'Booster un produit',
              onTap: () {
                Navigator.pop(ctx);
                // Use merchant's first product or demo
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MerchantBoostScreen(
                      productId: account.id,
                      productName: 'Mon produit',
                    ),
                  ),
                );
              },
            ),
            
            _buildMenuAction(
              icon: Icons.bar_chart,
              label: 'Statistiques',
              onTap: isParticulier ? null : () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Statistiques à venir')),
                );
              },
              enabled: !isParticulier,
              disabledText: 'Réservé aux Vérifiés',
            ),
            
            if (isParticulier)
              _buildMenuAction(
                icon: Icons.upgrade,
                label: 'Passer en Vérifié',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MerchantRegistrationScreen()),
                  );
                },
                highlight: true,
              ),
            
            const SizedBox(height: 16),
            
            // Legal notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les transactions se font hors plateforme. Tontetic n\'est pas le vendeur.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool enabled = true,
    String? disabledText,
    bool highlight = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? (highlight ? AppTheme.gold : AppTheme.marineBlue) : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: enabled ? Colors.black : Colors.grey,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: !enabled && disabledText != null
          ? Text(disabledText, style: const TextStyle(fontSize: 11, color: Colors.orange))
          : null,
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: enabled ? Colors.grey : Colors.grey.shade300),
      onTap: enabled ? onTap : null,
    );
  }

  Widget _buildProductCard(
    BuildContext context, 
    MerchantProduct product, 
    int index, 
    int total,
    LocalizationState l10n,
    bool isDemo,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, AppTheme.marineBlue.withAlpha(200)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Background - product image or placeholder
            Center(
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.storefront,
                        size: 120,
                        color: Colors.white24,
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: AppTheme.gold,
                          ),
                        );
                      },
                    )
                  : const Icon(Icons.storefront, size: 120, color: Colors.white24),
            ),
            
            // Product Info Overlay
            Positioned(
              bottom: 160,
              left: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.tag,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.marineBlue),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.price,
                    style: const TextStyle(fontSize: 18, color: AppTheme.gold, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.store, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.merchantName,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons (Right side)
            Positioned(
              right: 12,
              bottom: 180,
              child: Column(
                children: [
                  _buildActionButton(
                    Icons.favorite_border,
                    l10n.translate('like'),
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❤️ Liked: ${product.title}')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    Icons.share,
                    l10n.translate('share'),
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📣 Partage de: ${product.title}')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    Icons.chat_bubble_outline,
                    'Contacter',
                    () {
                      _trackProductClick(product);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            friendName: product.merchantName,
                            friendId: product.merchantId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // CTA Button
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _trackProductClick(product);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DirectChatScreen(
                            friendName: product.merchantName,
                            friendId: product.merchantId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.marineBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONTACTER LE MARCHAND', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Transaction hors plateforme • Tontetic n\'est pas le vendeur',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Top Bar
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Column(
                children: [
                   // Technical Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'ESPACE MARCHAND • PAIEMENT HORS PLATEFORME',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text(l10n.translate('merchant_tab_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                        child: Text('${index + 1}/$total', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
