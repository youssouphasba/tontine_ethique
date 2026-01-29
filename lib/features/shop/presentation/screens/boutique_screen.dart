import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/shop_feed_provider.dart';
import 'package:tontetic/core/services/fuzzy_search_service.dart';
import 'package:tontetic/core/services/content_moderation_service.dart';
import 'package:tontetic/features/shop/presentation/screens/interests_onboarding_screen.dart';
import 'package:tontetic/features/shop/presentation/screens/merchant_profile_page.dart';
import 'package:tontetic/features/shop/presentation/screens/liked_products_screen.dart';
import 'package:tontetic/features/shop/presentation/widgets/report_content_button.dart';
import 'package:tontetic/core/services/voice_service.dart';
import 'dart:async';

// Boutique Screen
// Marketplace for products and services
// 
// Features:
// - Product listing
// - Categories:
// - "Pour vous" personalized feed
// - "Tendances" trending products
// - "Abonnements" followed merchants
// - Infinite scroll
// - Like, follow, share interactions

class BoutiqueScreen extends ConsumerStatefulWidget {
  const BoutiqueScreen({super.key});

  @override
  ConsumerState<BoutiqueScreen> createState() => _BoutiqueScreenState();
}

class _BoutiqueScreenState extends ConsumerState<BoutiqueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Check onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    final state = ref.read(shopFeedProvider);
    if (!state.hasCompletedOnboarding) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const InterestsOnboardingScreen()));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.offWhite,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue,
            title: _isSearching 
              ? _buildSearchField()
              : const Text('Boutique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
              if (!_isSearching)
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LikedProductsScreen())),
                  tooltip: 'Mes likes',
                ),
              if (!_isSearching)
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterestsOnboardingScreen())),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Pour vous'),
                Tab(text: 'Tendances'),
                Tab(text: 'Suivis'),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            // Legal banner
            _buildLegalBanner(),
            // Feed
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildForYouFeed(),
                  _buildTrendingFeed(),
                  _buildFollowingFeed(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold.withValues(alpha: 0.2) : Colors.deepPurple.shade900,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white54, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Paiements via liens externes. Tontetic = outil technique.',
              style: TextStyle(
                fontSize: 10, 
                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Rechercher un produit, marchand...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        border: InputBorder.none,
        suffixIcon: _searchQuery.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.white54),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
          : null,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildForYouFeed() {
    var products = ref.watch(forYouFeedProvider);
    if (_searchQuery.isNotEmpty) {
      products = FuzzySearchService.searchWithScore(
        query: _searchQuery,
        items: products,
        getText: (p) => '${p.name} ${p.description} ${p.shopName}',
      );
    }
    return _buildProductFeed(products, 'Personnalisé pour vous');
  }

  Widget _buildTrendingFeed() {
    final products = ref.watch(trendingFeedProvider);
    return _buildProductFeed(products, 'Les plus populaires');
  }

  Widget _buildFollowingFeed() {
    final products = ref.watch(followingFeedProvider);
    final state = ref.watch(shopFeedProvider);
    
    if (state.followedMerchants.isEmpty) {
      return _buildEmptyFollowing();
    }
    return _buildProductFeed(products, 'Vos marchands favoris');
  }

  Widget _buildEmptyFollowing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Aucun marchand suivi', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18)),
          const SizedBox(height: 8),
          Text('Suivez des marchands pour voir leurs produits ici', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildProductFeed(List<FeedProduct> products, String subtitle) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Aucun produit', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: products.length,
      itemBuilder: (ctx, index) => _buildProductCard(products[index]),
    );
  }

  Widget _buildProductCard(FeedProduct product) {
    final state = ref.watch(shopFeedProvider);
    final isLiked = state.isProductLiked(product.id);
    final isFollowed = state.isMerchantFollowed(product.shopId);

    // Record view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shopFeedProvider.notifier).viewProduct(product.id);
    });

    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.grey.shade900,
      child: Stack(
        children: [
          // Product image placeholder
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepPurple.shade800,
                    Colors.deepPurple.shade900,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 100, color: Colors.white24),
              ),
            ),
          ),

          // Boosted/Sponsored badge for merchant products
          if (product.isBoosted)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Flexible(child: Text('Sponsorisé', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),

          // Report button (top right) - at the very top
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ReportContentIconButton(
                contentId: product.id,
                contentType: ContentType.product,
                reporterId: 'current_user', // TODO: Get from auth
              ),
            ),
          ),

          // Right side actions - positioned lower to avoid report button
          Positioned(
            right: 16,
            bottom: 140, // Lowered further to give space
            child: Column(
              children: [
                // Merchant avatar
                GestureDetector(
                  onTap: () => _showMerchantProfile(product),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.store, color: Colors.deepPurple),
                          ),
                          if (!isFollowed)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.shopName.length > 8 ? '${product.shopName.substring(0, 8)}...' : product.shopName,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Like
                _buildActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${product.likesCount}',
                  color: isLiked ? Colors.red : Colors.white,
                  onTap: () {
                    if (isLiked) {
                      ref.read(shopFeedProvider.notifier).unlikeProduct(product.id);
                    } else {
                      ref.read(shopFeedProvider.notifier).likeProduct(product.id);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Message
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Contacter',
                  onTap: () => _showMessageDialog(product),
                ),
                const SizedBox(height: 16),

                // Share
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Partager',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partage de ${product.name}...'))),
                ),
                const SizedBox(height: 16),

                // Buy
                _buildActionButton(
                  icon: Icons.shopping_cart,
                  label: 'Acheter',
                  color: Colors.green,
                  onTap: () => _showBuyDialog(product),
                ),
              ],
            ),
          ),

          // Bottom info
          Positioned(
            left: 16,
            right: 90, // Increased to prevent overlap with action buttons
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Merchant info - tappable
                GestureDetector(
                  onTap: () => _showMerchantProfile(product),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${product.shopName}', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.green),
                            Text(' ${product.merchantHonorScore.toInt()}%', style: const TextStyle(color: Colors.green, fontSize: 10)),
                          ],
                        ),
                      ),
                      if (isFollowed)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check_circle, size: 16, color: Colors.lightBlue),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Product name
                Text(
                  product.name, 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  product.description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${product.price.toInt()} ${product.currency}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).brightness == Brightness.dark ? AppTheme.marineBlue : Colors.deepPurple, 
                      fontSize: 16,
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
              ],
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
        ],
      ),
    );
  }

  void _showMerchantProfile(FeedProduct product) {
    // Navigate to full Instagram-like merchant page
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
  }

  void _showMessageDialog(FeedProduct product) {
    final textController = TextEditingController();
    bool isRecording = false;
    int recordingSeconds = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Icon(Icons.store, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Généralement répond en 1h', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Product preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, color: Colors.deepPurple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text('${product.price.toInt()} ${product.currency}', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Message options
              const Text(
                'Choisissez votre mode de message :', 
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),

              // Text input
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 12),

              // Voice message option
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRecording ? Colors.red.shade50 : Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isRecording ? Colors.red : Colors.deepPurple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: isRecording ? Colors.red : Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isRecording
                        ? Row(
                            children: [
                              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                              const SizedBox(width: 8),
                              Text(
                                '${(recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(recordingSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  await ref.read(voiceServiceProvider).stopRecording();
                                  setState(() => isRecording = false);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('🎤 Message vocal envoyé (${recordingSeconds}s)'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          )
                        : GestureDetector(
                            onTap: () async {
                              final voiceService = ref.read(voiceServiceProvider);
                              await voiceService.startRecording();
                              
                              setState(() {
                                isRecording = true;
                                recordingSeconds = 0;
                              });

                              // Still need a timer just for the UI display of duration
                              Timer.periodic(const Duration(seconds: 1), (timer) {
                                if (!isRecording || !mounted) {
                                  timer.cancel();
                                  return;
                                }
                                setState(() => recordingSeconds++);
                              });
                            },
                            child: const Text(
                              'Appuyez pour enregistrer un message vocal',
                              style: TextStyle(color: Colors.deepPurple),
                            ),
                          ),
                    ),
                    if (isRecording)
                      GestureDetector(
                        onTap: () => setState(() => isRecording = false),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.close, color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Send text button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: textController.text.trim().isNotEmpty || isRecording
                    ? () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message envoyé !'), backgroundColor: Colors.green),
                        );
                      }
                    : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Envoyer le message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBuyDialog(FeedProduct product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart, size: 48, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${product.price.toInt()} ${product.currency}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le paiement se fait via le lien externe du marchand. Tontetic n\'encaisse aucun fonds.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redirection vers le paiement externe...')));
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Payer via le marchand'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
