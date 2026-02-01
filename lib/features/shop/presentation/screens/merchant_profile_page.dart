import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:tontetic/core/theme/app_theme.dart'; - UNUSED
import 'package:tontetic/core/providers/shop_feed_provider.dart';

/// Merchant Profile Page (Instagram-like)
/// Shows merchant info, products grid, and reviews
/// 
/// Features:
/// - Header with avatar, stats, follow button
/// - Tab: Products grid, About, Reviews
/// - Product tap for details

class MerchantProfilePage extends ConsumerWidget {
  final String shopId;
  final String shopName;
  final double honorScore;

  const MerchantProfilePage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.honorScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(shopFeedProvider);
    final isFollowed = feedState.isMerchantFollowed(shopId);
    final products = feedState.allProducts.where((p) => p.shopId == shopId).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
            // App bar
            SliverAppBar(
              expandedHeight: 320, // Increased for more header space
              pinned: true,
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.deepPurple,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(context, ref, isFollowed, products.length),
              ),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.grid_on), text: 'Produits'),
                  Tab(icon: Icon(Icons.info_outline), text: 'À propos'),
                  Tab(icon: Icon(Icons.star_outline), text: 'Avis'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildProductsGrid(context, products),
              _buildAboutTab(context),
              _buildReviewsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isFollowed, int productCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 20), // Reduced vertical padding to avoid overflow
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple.shade800, Colors.deepPurple],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar - smaller
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              shopName.isNotEmpty ? shopName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
          ),
          const SizedBox(height: 8),

          // Name
          Text(
            shopName, 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // Honor score - inline
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.greenAccent, size: 12),
              const SizedBox(width: 4),
              Text('Score: ${honorScore.toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),

          // Stats - compact row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('$productCount', 'Produits'),
              const SizedBox(width: 24),
              _buildStat('${(productCount * 23).clamp(0, 9999)}', 'Abonnés'),
              const SizedBox(width: 24),
              _buildStat('${honorScore.toInt()}%', 'Score'),
            ],
          ),
          const SizedBox(height: 10),

          // Follow button - always visible
          Consumer(
            builder: (ctx, ref, _) {
              return SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isFollowed) {
                      ref.read(shopFeedProvider.notifier).unfollowMerchant(shopId);
                    } else {
                      ref.read(shopFeedProvider.notifier).followMerchant(shopId, shopName, null);
                    }
                  },
                  icon: Icon(isFollowed ? Icons.check : Icons.add, size: 14),
                  label: Text(isFollowed ? 'Suivi' : 'Suivre', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowed ? Colors.white24 : Colors.white,
                    foregroundColor: isFollowed ? Colors.white : Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ===== PRODUCTS GRID (Instagram-like) =====
  Widget _buildProductsGrid(BuildContext context, List<FeedProduct> products) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucun produit', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () => _showProductDetail(context, product),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Product image placeholder
              Container(
                color: Colors.deepPurple.shade100,
                child: product.imageUrls.isNotEmpty
                  ? Image.network(product.imageUrls.first, fit: BoxFit.cover)
                  : Center(
                      child: Icon(Icons.image, size: 32, color: Colors.deepPurple.shade300),
                    ),
              ),
              // Video indicator
              if (product.imageUrls.any((url) => url.contains('video')))
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
                ),
              // Price overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black54,
                  child: Text(
                    '${product.price.toInt()} ${product.currency}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProductDetail(BuildContext context, FeedProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Image carousel
              SizedBox(
                height: 250,
                child: product.imageUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: product.imageUrls.length,
                      itemBuilder: (_, i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Icon(Icons.image, size: 64, color: Colors.grey)),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Icon(Icons.image, size: 64, color: Colors.deepPurple)),
                    ),
              ),
              const SizedBox(height: 20),

              // Name & Price
              Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '${product.price.toInt()} ${product.currency}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 16),

              // Description
              Text(product.description, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('💬 Message envoyé à $shopName'))),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Contacter'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Redirection vers paiement externe...')),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Commander'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== ABOUT TAB =====
  Widget _buildAboutTab(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('À propos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      const SizedBox(height: 16),
      _buildInfoTile(context, Icons.store, 'Boutique', shopName),
      _buildInfoTile(context, Icons.verified, 'Score d\'honneur', '${honorScore.toInt()}% - Vendeur de confiance'),
      _buildInfoTile(context, Icons.location_on, 'Localisation', 'Dakar, Sénégal'),
      _buildInfoTile(context, Icons.access_time, 'Membre depuis', 'Janvier 2024'),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: Colors.blue.shade700) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Les paiements se font directement avec le marchand via son lien de paiement externe.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildInfoTile(BuildContext context, IconData icon, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.purple.shade300 : Colors.deepPurple),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      subtitle: Text(value, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
    );
  }

  Widget _buildReviewsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Aucun avis pour le moment', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(review['name'].toString()[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < (review['rating'] as int) ? Icons.star : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        )),
                      ),
                    ],
                  ),
                ),
                Text(review['date'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(review['comment'].toString()),
          ],
        ),
      ),
    );
  }
}
