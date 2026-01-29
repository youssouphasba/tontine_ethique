import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/shop_feed_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/shop/presentation/screens/merchant_profile_page.dart';

/// Liked Products Screen - Shows all products the user has liked
class LikedProductsScreen extends ConsumerWidget {
  const LikedProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(shopFeedProvider);
    final likedProductIds = feedState.likedProductIds;
    final likedProducts = feedState.allProducts
        .where((p) => likedProductIds.contains(p.id))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Mes Likes (${likedProducts.length})'),
          ],
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.deepPurple,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple,
        elevation: 0,
      ),
      body: likedProducts.isEmpty
          ? _buildEmptyState()
          : _buildLikedProductsList(context, ref, likedProducts),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucun produit liké',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Explorez la boutique et likez\nles produits qui vous plaisent !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedProductsList(BuildContext context, WidgetRef ref, List<FeedProduct> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, ref, product);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, WidgetRef ref, FeedProduct product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor, // Added this line
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to merchant profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MerchantProfilePage(
                shopId: product.shopId,
                shopName: product.shopName,
                honorScore: product.merchantHonorScore,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shopping_bag, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.deepPurple, size: 32),
              ),
              const SizedBox(width: 12),
              
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${product.shopName}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${product.price.toInt()} ${product.currency}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.deepPurple,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.red, size: 16),
                            const SizedBox(width: 4),
                            Text('${product.likesCount}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Unlike button
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () {
                  ref.read(shopFeedProvider.notifier).unlikeProduct(product.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} retiré des likes'),
                      duration: const Duration(seconds: 2),
                      action: SnackBarAction(
                        label: 'Annuler',
                        onPressed: () {
                          ref.read(shopFeedProvider.notifier).likeProduct(product.id);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
