import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:tontetic/core/providers/merchant_account_provider.dart'; - UNUSED

/// Shop Feed Provider
/// TikTok-like product discovery with interests and recommendations
/// 
/// Features:
/// - Interest-based recommendations
/// - Favorites and follows
/// - Product history
/// - Gamification (badges)
/// - Boost/promoted products

// =============== CATEGORIES ===============
enum ProductInterest {
  // Fashion
  fashionWomen,
  fashionMen,
  fashionKids,
  accessories,
  shoes,
  jewelry,
  
  // Beauty
  skincare,
  makeup,
  haircare,
  perfume,
  
  // Food & Drink
  localFood,
  restaurants,
  bakery,
  beverages,
  organic,
  
  // Home
  furniture,
  decoration,
  kitchen,
  garden,
  
  // Electronics
  phones,
  computers,
  gaming,
  audio,
  
  // Services
  beautyServices,
  repairs,
  coaching,
  transport,
  events,
  
  // Crafts
  artisanal,
  handmade,
  traditional,
  art,
  
  // Health
  wellness,
  sports,
  nutrition,
  
  // Other
  pets,
  kids,
  books,
  music,
}

String getInterestLabel(ProductInterest interest) {
  switch (interest) {
    // Fashion
    case ProductInterest.fashionWomen: return '👗 Mode Femme';
    case ProductInterest.fashionMen: return '👔 Mode Homme';
    case ProductInterest.fashionKids: return '👶 Mode Enfant';
    case ProductInterest.accessories: return '👜 Accessoires';
    case ProductInterest.shoes: return '👟 Chaussures';
    case ProductInterest.jewelry: return '💎 Bijoux';
    
    // Beauty
    case ProductInterest.skincare: return '🧴 Soins Peau';
    case ProductInterest.makeup: return '💄 Maquillage';
    case ProductInterest.haircare: return '💇 Cheveux';
    case ProductInterest.perfume: return '🌸 Parfums';
    
    // Food
    case ProductInterest.localFood: return '🍲 Cuisine Locale';
    case ProductInterest.restaurants: return '🍽️ Restaurants';
    case ProductInterest.bakery: return '🥐 Pâtisserie';
    case ProductInterest.beverages: return '🧃 Boissons';
    case ProductInterest.organic: return '🥬 Bio';
    
    // Home
    case ProductInterest.furniture: return '🛋️ Meubles';
    case ProductInterest.decoration: return '🖼️ Décoration';
    case ProductInterest.kitchen: return '🍳 Cuisine';
    case ProductInterest.garden: return '🌱 Jardin';
    
    // Electronics
    case ProductInterest.phones: return '📱 Téléphones';
    case ProductInterest.computers: return '💻 Informatique';
    case ProductInterest.gaming: return '🎮 Gaming';
    case ProductInterest.audio: return '🎧 Audio';
    
    // Services
    case ProductInterest.beautyServices: return '💅 Services Beauté';
    case ProductInterest.repairs: return '🔧 Réparations';
    case ProductInterest.coaching: return '🎯 Coaching';
    case ProductInterest.transport: return '🚗 Transport';
    case ProductInterest.events: return '🎉 Événements';
    
    // Crafts
    case ProductInterest.artisanal: return '🎨 Artisanat';
    case ProductInterest.handmade: return '✂️ Fait Main';
    case ProductInterest.traditional: return '🏺 Traditionnel';
    case ProductInterest.art: return '🖌️ Art';
    
    // Health
    case ProductInterest.wellness: return '🧘 Bien-être';
    case ProductInterest.sports: return '⚽ Sports';
    case ProductInterest.nutrition: return '🥗 Nutrition';
    
    // Other
    case ProductInterest.pets: return '🐕 Animaux';
    case ProductInterest.kids: return '🧸 Enfants';
    case ProductInterest.books: return '📚 Livres';
    case ProductInterest.music: return '🎵 Musique';
  }
}

// =============== DATA CLASSES ===============

class FeedProduct {
  final String id;
  final String shopId;
  final String shopName;
  final String name;
  final String description;
  final double price;
  final String currency;
  final List<String> imageUrls;
  final List<ProductInterest> interests;
  final int likesCount;
  final bool isBoosted;
  final int boostPriority;
  final String? externalPaymentLink;
  final double merchantHonorScore;
  final DateTime createdAt;

  FeedProduct({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.name,
    required this.description,
    required this.price,
    this.currency = 'FCFA',
    this.imageUrls = const [],
    this.interests = const [],
    this.likesCount = 0,
    this.isBoosted = false,
    this.boostPriority = 0,
    this.externalPaymentLink,
    this.merchantHonorScore = 85,
    required this.createdAt,
  });

  FeedProduct copyWith({
    int? likesCount,
    bool? isBoosted,
    int? boostPriority,
  }) {
    return FeedProduct(
      id: id,
      shopId: shopId,
      shopName: shopName,
      name: name,
      description: description,
      price: price,
      currency: currency,
      imageUrls: imageUrls,
      interests: interests,
      likesCount: likesCount ?? this.likesCount,
      isBoosted: isBoosted ?? this.isBoosted,
      boostPriority: boostPriority ?? this.boostPriority,
      externalPaymentLink: externalPaymentLink,
      merchantHonorScore: merchantHonorScore,
      createdAt: createdAt,
    );
  }
  factory FeedProduct.fromMap(Map<String, dynamic> map, String id) {
    return FeedProduct(
      id: id,
      shopId: map['shopId'] ?? '',
      shopName: map['shopName'] ?? 'Boutique Inconnue',
      name: map['name'] ?? 'Produit sans nom',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'FCFA',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      interests: (map['interests'] as List<dynamic>?)
          ?.map((e) => ProductInterest.values.firstWhere(
              (i) => i.toString() == 'ProductInterest.$e',
              orElse: () => ProductInterest.fashionWomen))
          .toList() ?? [],
      likesCount: map['likesCount'] ?? 0,
      isBoosted: map['isBoosted'] ?? false,
      boostPriority: map['boostPriority'] ?? 0,
      externalPaymentLink: map['externalPaymentLink'],
      merchantHonorScore: (map['merchantHonorScore'] as num?)?.toDouble() ?? 85.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FollowedMerchant {
  final String shopId;
  final String shopName;
  final String? logoUrl;
  final DateTime followedAt;

  FollowedMerchant({
    required this.shopId,
    required this.shopName,
    this.logoUrl,
    required this.followedAt,
  });
}

class UserBadge {
  final String id;
  final String name;
  final String icon;
  final String description;
  final DateTime earnedAt;

  UserBadge({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.earnedAt,
  });
}

// =============== STATE ===============

class ShopFeedState {
  final List<ProductInterest> interests;
  final bool hasCompletedOnboarding;
  final List<String> likedProductIds;
  final List<String> viewedProductIds;
  final List<FollowedMerchant> followedMerchants;
  final List<FeedProduct> allProducts;
  final List<UserBadge> badges;
  final int totalLikes;
  final int totalViews;

  ShopFeedState({
    this.interests = const [],
    this.hasCompletedOnboarding = false,
    this.likedProductIds = const [],
    this.viewedProductIds = const [],
    this.followedMerchants = const [],
    this.allProducts = const [],
    this.badges = const [],
    this.totalLikes = 0,
    this.totalViews = 0,
  });

  bool isProductLiked(String productId) => likedProductIds.contains(productId);
  bool isProductViewed(String productId) => viewedProductIds.contains(productId);
  bool isMerchantFollowed(String shopId) => followedMerchants.any((m) => m.shopId == shopId);

  // Get products for "Pour vous" feed (personalized)
  List<FeedProduct> getForYouFeed() {
    if (interests.isEmpty) return allProducts;
    
    return allProducts.where((p) {
      // Boosted always show
      if (p.isBoosted) return true;
      // Match interests
      return p.interests.any((i) => interests.contains(i));
    }).toList()
      ..sort((a, b) {
        // Boosted first
        if (a.isBoosted && !b.isBoosted) return -1;
        if (!a.isBoosted && b.isBoosted) return 1;
        // Then by boost priority
        if (a.boostPriority != b.boostPriority) return b.boostPriority.compareTo(a.boostPriority);
        // Then by likes
        return b.likesCount.compareTo(a.likesCount);
      });
  }

  // Get trending products
  List<FeedProduct> getTrendingFeed() {
    return allProducts.toList()
      ..sort((a, b) => b.likesCount.compareTo(a.likesCount));
  }

  // Get products from followed merchants
  List<FeedProduct> getFollowingFeed() {
    final followedIds = followedMerchants.map((m) => m.shopId).toSet();
    return allProducts.where((p) => followedIds.contains(p.shopId)).toList();
  }

  ShopFeedState copyWith({
    List<ProductInterest>? interests,
    bool? hasCompletedOnboarding,
    List<String>? likedProductIds,
    List<String>? viewedProductIds,
    List<FollowedMerchant>? followedMerchants,
    List<FeedProduct>? allProducts,
    List<UserBadge>? badges,
    int? totalLikes,
    int? totalViews,
  }) {
    return ShopFeedState(
      interests: interests ?? this.interests,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      likedProductIds: likedProductIds ?? this.likedProductIds,
      viewedProductIds: viewedProductIds ?? this.viewedProductIds,
      followedMerchants: followedMerchants ?? this.followedMerchants,
      allProducts: allProducts ?? this.allProducts,
      badges: badges ?? this.badges,
      totalLikes: totalLikes ?? this.totalLikes,
      totalViews: totalViews ?? this.totalViews,
    );
  }
}

// =============== NOTIFIER ===============

class ShopFeedNotifier extends StateNotifier<ShopFeedState> {
  ShopFeedNotifier() : super(ShopFeedState()) {
    _initRealtimeFeed();
  }

  void _initRealtimeFeed() {
    FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      final products = snapshot.docs.map((doc) {
        return FeedProduct.fromMap(doc.data(), doc.id);
      }).toList();
      
      state = state.copyWith(allProducts: products);
    }, onError: (e) {
      debugPrint("Error fetching products: $e");
    });
  }

  // ===== ONBOARDING =====
  void setInterests(List<ProductInterest> interests) {
    state = state.copyWith(
      interests: interests,
      hasCompletedOnboarding: true,
    );
    _checkBadges();
    debugPrint('[ShopFeed] Interests set: ${interests.length} selected');
  }

  void addInterest(ProductInterest interest) {
    if (!state.interests.contains(interest)) {
      state = state.copyWith(interests: [...state.interests, interest]);
    }
  }

  void removeInterest(ProductInterest interest) {
    state = state.copyWith(
      interests: state.interests.where((i) => i != interest).toList(),
    );
  }

  // ===== INTERACTIONS =====
  void likeProduct(String productId) {
    if (state.isProductLiked(productId)) return;
    
    // Update liked list
    state = state.copyWith(
      likedProductIds: [...state.likedProductIds, productId],
      totalLikes: state.totalLikes + 1,
    );
    
    // Update product likes count
    final products = state.allProducts.map((p) {
      if (p.id == productId) return p.copyWith(likesCount: p.likesCount + 1);
      return p;
    }).toList();
    state = state.copyWith(allProducts: products);
    
    _checkBadges();
    debugPrint('[ShopFeed] Liked product: $productId');
  }

  void unlikeProduct(String productId) {
    if (!state.isProductLiked(productId)) return;
    
    state = state.copyWith(
      likedProductIds: state.likedProductIds.where((id) => id != productId).toList(),
      totalLikes: state.totalLikes - 1,
    );
    
    final products = state.allProducts.map((p) {
      if (p.id == productId) return p.copyWith(likesCount: p.likesCount - 1);
      return p;
    }).toList();
    state = state.copyWith(allProducts: products);
  }

  void viewProduct(String productId) {
    if (state.isProductViewed(productId)) return;
    
    state = state.copyWith(
      viewedProductIds: [...state.viewedProductIds, productId],
      totalViews: state.totalViews + 1,
    );
    _checkBadges();
  }

  void followMerchant(String shopId, String shopName, String? logoUrl) {
    if (state.isMerchantFollowed(shopId)) return;
    
    state = state.copyWith(
      followedMerchants: [
        ...state.followedMerchants,
        FollowedMerchant(shopId: shopId, shopName: shopName, logoUrl: logoUrl, followedAt: DateTime.now()),
      ],
    );
    _checkBadges();
    debugPrint('[ShopFeed] Followed merchant: $shopName');
  }

  void unfollowMerchant(String shopId) {
    state = state.copyWith(
      followedMerchants: state.followedMerchants.where((m) => m.shopId != shopId).toList(),
    );
  }

  // ===== GAMIFICATION =====
  void _checkBadges() {
    final newBadges = <UserBadge>[];
    
    // First like
    if (state.totalLikes >= 1 && !state.badges.any((b) => b.id == 'first_like')) {
      newBadges.add(UserBadge(id: 'first_like', name: 'Premier Like', icon: '❤️', description: 'Vous avez liké votre premier produit', earnedAt: DateTime.now()));
    }
    
    // 10 products viewed
    if (state.totalViews >= 10 && !state.badges.any((b) => b.id == 'explorer')) {
      newBadges.add(UserBadge(id: 'explorer', name: 'Explorateur', icon: '🔍', description: 'Vous avez consulté 10 produits', earnedAt: DateTime.now()));
    }
    
    // First follow
    if (state.followedMerchants.isNotEmpty && !state.badges.any((b) => b.id == 'follower')) {
      newBadges.add(UserBadge(id: 'follower', name: 'Fan', icon: '⭐', description: 'Vous suivez un marchand', earnedAt: DateTime.now()));
    }
    
    if (newBadges.isNotEmpty) {
      state = state.copyWith(badges: [...state.badges, ...newBadges]);
    }
  }

  // ===== BOOST (for merchant) =====
  void boostProduct(String productId, int priority) {
    final products = state.allProducts.map((p) {
      if (p.id == productId) {
        return p.copyWith(isBoosted: true, boostPriority: priority);
      }
      return p;
    }).toList();
    state = state.copyWith(allProducts: products);
    debugPrint('[ShopFeed] Product boosted: $productId with priority $priority');
  }
}

// =============== PROVIDERS ===============

final shopFeedProvider = StateNotifierProvider<ShopFeedNotifier, ShopFeedState>((ref) {
  return ShopFeedNotifier();
});

final forYouFeedProvider = Provider<List<FeedProduct>>((ref) {
  return ref.watch(shopFeedProvider).getForYouFeed();
});

final trendingFeedProvider = Provider<List<FeedProduct>>((ref) {
  return ref.watch(shopFeedProvider).getTrendingFeed();
});

final followingFeedProvider = Provider<List<FeedProduct>>((ref) {
  return ref.watch(shopFeedProvider).getFollowingFeed();
});
