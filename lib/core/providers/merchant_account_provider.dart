import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/services/merchant_account_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// =============== ENUMS ===============
// Re-export from service for backward compatibility
export 'package:tontetic/core/services/merchant_account_service.dart'
    show MerchantType, MerchantKycStatus, MerchantAccountStatus, MerchantAccount, BoostOption;

enum ActiveProfile { particulier, marchand }

// Shop-specific status (different from account KYC status)
enum ShopStatus { pendingSetup, active, suspended, closed }

enum ProductCategory {
  other,
  fashion,
  beauty,
  food,
  home,
  electronics,
  services,
  crafts,
  health,
}

enum OrderStatus {
  pending,
  paid,
  processing,
  shipped,
  delivered,
  cancelled,
  returned,
}

// =============== MODELS ===============

class MerchantShop {
  final String id;
  final String ownerId;  // Links to MerchantAccount.userId
  final String merchantAccountId; // Links to merchants collection
  final String shopName;
  final ProductCategory category;
  final DateTime createdAt;
  final String? professionalEmail;
  final String? address;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final ShopStatus status;
  final int followersCount;
  final double rating;
  final int reviewsCount;

  MerchantShop({
    required this.id,
    required this.ownerId,
    required this.merchantAccountId,
    required this.shopName,
    required this.category,
    required this.createdAt,
    this.professionalEmail,
    this.address,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.status,
    this.followersCount = 0,
    this.rating = 0.0,
    this.reviewsCount = 0,
  });

  factory MerchantShop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MerchantShop(
      id: doc.id,
      ownerId: data['ownerId'] ?? data['userId'] ?? '', // Support both field names
      merchantAccountId: data['merchantAccountId'] ?? '',
      shopName: data['shopName'] ?? 'Boutique',
      category: ProductCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ProductCategory.other,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      professionalEmail: data['professionalEmail'],
      address: data['address'],
      description: data['description'],
      logoUrl: data['logoUrl'],
      bannerUrl: data['bannerUrl'],
      status: ShopStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ShopStatus.pendingSetup,
      ),
      followersCount: data['followersCount'] ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: data['reviewsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'merchantAccountId': merchantAccountId,
    'shopName': shopName,
    'category': category.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'professionalEmail': professionalEmail,
    'address': address,
    'description': description,
    'logoUrl': logoUrl,
    'bannerUrl': bannerUrl,
    'status': status.name,
    'followersCount': followersCount,
    'rating': rating,
    'reviewsCount': reviewsCount,
  };
}

class Product {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final double price;
  final int stockQuantity;
  final ProductCategory category;
  final DateTime createdAt;
  final List<String> imageUrls;
  final bool isActive;
  final bool isApproved; // Moderation status
  final String currency;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.price,
    required this.stockQuantity,
    required this.category,
    required this.createdAt,
    this.imageUrls = const [],
    this.isActive = true,
    this.isApproved = false,
    this.currency = 'FCFA',
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: data['stockQuantity'] ?? 0,
      category: ProductCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ProductCategory.other,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      isActive: data['isActive'] ?? true,
      isApproved: data['isApproved'] ?? false,
      currency: data['currency'] ?? 'FCFA',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'shopId': shopId,
    'name': name,
    'description': description,
    'price': price,
    'stockQuantity': stockQuantity,
    'category': category.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'imageUrls': imageUrls,
    'isActive': isActive,
    'isApproved': isApproved,
    'currency': currency,
  };
}

class Order {
  final String id;
  final String shopId;
  final String buyerId;
  final String productId;
  final String productName;
  final int quantity;
  final double totalAmount;
  final DateTime createdAt;
  final OrderStatus status;
  final String? pspTransactionId;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final String? externalPaymentLink;
  final String currency;

  Order({
    required this.id,
    required this.shopId,
    required this.buyerId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalAmount,
    required this.createdAt,
    required this.status,
    this.pspTransactionId,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.externalPaymentLink,
    this.currency = 'FCFA',
  });

  String get anonymizedBuyerId {
    if (buyerId.length <= 8) return 'Client $buyerId';
    return 'Client ${buyerId.substring(0, 4)}...${buyerId.substring(buyerId.length - 4)}';
  }

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      quantity: data['quantity'] ?? 1,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      pspTransactionId: data['pspTransactionId'],
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      externalPaymentLink: data['externalPaymentLink'],
      currency: data['currency'] ?? 'FCFA',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'shopId': shopId,
    'buyerId': buyerId,
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'totalAmount': totalAmount,
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status.name,
    'pspTransactionId': pspTransactionId,
    'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    'shippedAt': shippedAt != null ? Timestamp.fromDate(shippedAt!) : null,
    'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    'externalPaymentLink': externalPaymentLink,
    'currency': currency,
  };
}

// =============== STATE ===============

class MerchantAccountState {
  final MerchantAccount? account; // From 'merchants' collection - KYC, limits, status
  final MerchantShop? shop;       // From 'shops' collection - storefront details
  final List<Product> products;
  final List<Order> orders;
  final double totalRevenue;
  final int totalOrders;
  final ActiveProfile activeProfile;
  final bool isLoading;
  final String? error;

  MerchantAccountState({
    this.account,
    this.shop,
    this.products = const [],
    this.orders = const [],
    this.totalRevenue = 0.0,
    this.totalOrders = 0,
    this.activeProfile = ActiveProfile.particulier,
    this.isLoading = false,
    this.error,
  });

  // Account checks (KYC, limits)
  bool get hasMerchantAccount => account != null;
  bool get isAccountActive => account?.accountStatus == MerchantAccountStatus.active;
  bool get isKycVerified =>
      account?.kycStatus == MerchantKycStatus.lightVerified ||
      account?.kycStatus == MerchantKycStatus.fullVerified;
  bool get canPublish => account?.canPublishOffer ?? false;
  String? get publishBlockReason => account?.publishBlockReason;

  // Shop checks
  bool get hasShop => shop != null;
  bool get isShopActive => shop?.status == ShopStatus.active;

  // Combined checks
  bool get isFullyOperational => hasMerchantAccount && hasShop && isAccountActive && isShopActive;
  bool get isMerchantMode => activeProfile == ActiveProfile.marchand;

  // Stats
  int get productsCount => products.length;
  int get activeProductsCount => products.where((p) => p.isActive && p.isApproved).length;
  int get lowStockCount => products.where((p) => p.stockQuantity < 5 && p.isActive).length;
  int get pendingOrdersCount => orders.where((o) => o.status == OrderStatus.pending).length;

  MerchantAccountState copyWith({
    MerchantAccount? account,
    MerchantShop? shop,
    List<Product>? products,
    List<Order>? orders,
    double? totalRevenue,
    int? totalOrders,
    ActiveProfile? activeProfile,
    bool? isLoading,
    String? error,
    bool clearAccount = false,
    bool clearShop = false,
  }) {
    return MerchantAccountState(
      account: clearAccount ? null : (account ?? this.account),
      shop: clearShop ? null : (shop ?? this.shop),
      products: products ?? this.products,
      orders: orders ?? this.orders,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalOrders: totalOrders ?? this.totalOrders,
      activeProfile: activeProfile ?? this.activeProfile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// =============== NOTIFIER ===============

class MerchantAccountNotifier extends StateNotifier<MerchantAccountState> {
  final Ref ref;
  final String? userId;

  StreamSubscription? _accountSub;
  StreamSubscription? _shopSub;
  StreamSubscription? _productsSub;
  StreamSubscription? _ordersSub;

  static const _profileKey = 'merchant_active_profile';

  MerchantAccountNotifier(this.ref, this.userId) : super(MerchantAccountState()) {
    _init();
  }

  Future<void> _init() async {
    if (userId == null || userId!.isEmpty) return;

    // Load saved profile preference
    final prefs = await SharedPreferences.getInstance();
    final savedProfile = prefs.getString(_profileKey);
    if (savedProfile == 'marchand') {
      state = state.copyWith(activeProfile: ActiveProfile.marchand);
    }

    // Listen to MerchantAccount from 'merchants' collection
    _accountSub = FirebaseFirestore.instance
        .collection('merchants')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;

        try {
          final account = MerchantAccount.fromJson(data);
          state = state.copyWith(account: account, isLoading: false);
          debugPrint('[MERCHANT] Account loaded: ${account.id} (${account.type.name})');

          // Now load the shop linked to this account
          _loadShop(account.id);
        } catch (e) {
          debugPrint('[MERCHANT] Error parsing account: $e');
          state = state.copyWith(error: 'Erreur de chargement du compte', isLoading: false);
        }
      } else {
        // No merchant account yet
        state = state.copyWith(clearAccount: true, clearShop: true, isLoading: false);
        _shopSub?.cancel();
        _productsSub?.cancel();
        _ordersSub?.cancel();
      }
    }, onError: (e) {
      debugPrint('[MERCHANT] Firestore error: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    });
  }

  void _loadShop(String merchantAccountId) {
    _shopSub?.cancel();
    _shopSub = FirebaseFirestore.instance
        .collection('shops')
        .where('merchantAccountId', isEqualTo: merchantAccountId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final shop = MerchantShop.fromFirestore(snapshot.docs.first);
        state = state.copyWith(shop: shop);
        debugPrint('[MERCHANT] Shop loaded: ${shop.shopName}');
        _loadShopData(shop.id);
      } else {
        // Account exists but no shop yet - user needs to create shop
        state = state.copyWith(clearShop: true);
        _productsSub?.cancel();
        _ordersSub?.cancel();
      }
    });
  }

  void _loadShopData(String shopId) {
    // Listen to Products
    _productsSub?.cancel();
    _productsSub = FirebaseFirestore.instance
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final products = snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      state = state.copyWith(products: products);
    });

    // Listen to Orders (limited for performance)
    _ordersSub?.cancel();
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .limit(100) // Pagination limit
        .snapshots()
        .listen((snapshot) {
      final orders = snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();

      // Calculate totals
      final paidStatuses = [OrderStatus.paid, OrderStatus.shipped, OrderStatus.delivered];
      final totalRevenue = orders
          .where((o) => paidStatuses.contains(o.status))
          .fold(0.0, (total, o) => total + o.totalAmount);

      state = state.copyWith(
        orders: orders,
        totalRevenue: totalRevenue,
        totalOrders: orders.length,
      );
    });
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _shopSub?.cancel();
    _productsSub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }

  // ===== PROFILE SWITCHING =====
  Future<void> switchToMerchant() async {
    if (state.hasMerchantAccount) {
      state = state.copyWith(activeProfile: ActiveProfile.marchand);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileKey, 'marchand');
    }
  }

  Future<void> switchToParticulier() async {
    state = state.copyWith(activeProfile: ActiveProfile.particulier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, 'particulier');
  }

  Future<void> toggleProfile() async {
    if (state.isMerchantMode) {
      await switchToParticulier();
    } else if (state.hasMerchantAccount) {
      await switchToMerchant();
    }
  }

  // ===== ACCOUNT CREATION (writes to 'merchants' collection) =====
  Future<MerchantAccount?> createParticulierAccount({
    required String userId,
    required String email,
    required String pspAccountId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final accountId = 'MERCH_${DateTime.now().millisecondsSinceEpoch}';
      final account = MerchantAccount(
        id: accountId,
        userId: userId,
        type: MerchantType.particulier,
        kycStatus: MerchantKycStatus.lightVerified,
        accountStatus: MerchantAccountStatus.active,
        email: email,
        pspAccountId: pspAccountId,
        createdAt: DateTime.now(),
        kycVerifiedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(accountId)
          .set(account.toJson());

      debugPrint('[MERCHANT] Created Particulier account: $accountId');
      state = state.copyWith(account: account, isLoading: false);
      return account;
    } catch (e) {
      debugPrint('[MERCHANT] Error creating account: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  Future<MerchantAccount?> createVerifieAccount({
    required String userId,
    required String email,
    required String siretNinea,
    required String idDocumentUrl,
    required String selfieUrl,
    String? pspAccountId,
    String? iban,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final accountId = 'MERCH_${DateTime.now().millisecondsSinceEpoch}';
      final account = MerchantAccount(
        id: accountId,
        userId: userId,
        type: MerchantType.verifie,
        kycStatus: MerchantKycStatus.pending, // Requires manual verification
        accountStatus: MerchantAccountStatus.active,
        email: email,
        pspAccountId: pspAccountId,
        siretNinea: siretNinea,
        idDocumentUrl: idDocumentUrl,
        selfieUrl: selfieUrl,
        iban: iban,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(accountId)
          .set(account.toJson());

      debugPrint('[MERCHANT] Created Vérifié account (pending KYC): $accountId');
      state = state.copyWith(account: account, isLoading: false);
      return account;
    } catch (e) {
      debugPrint('[MERCHANT] Error creating account: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  // ===== SHOP MANAGEMENT =====
  Future<String?> createShop({
    required String shopName,
    String? professionalEmail,
    required ProductCategory category,
    String? address,
    String? description,
  }) async {
    if (state.account == null) {
      debugPrint('[MERCHANT] Cannot create shop without merchant account');
      return null;
    }

    final doc = FirebaseFirestore.instance.collection('shops').doc();
    final shop = MerchantShop(
      id: doc.id,
      ownerId: userId!,
      merchantAccountId: state.account!.id,
      shopName: shopName,
      professionalEmail: professionalEmail,
      category: category,
      address: address,
      description: description,
      status: ShopStatus.active, // Active immediately since account is verified
      createdAt: DateTime.now(),
    );

    await doc.set(shop.toFirestore());
    debugPrint('[MERCHANT] Shop created: ${doc.id}');
    return doc.id;
  }

  Future<void> activateShop(String shopId) async {
    final targetId = shopId.isNotEmpty ? shopId : state.shop?.id;
    if (targetId == null) {
      debugPrint('[MERCHANT] activateShop: no shopId provided');
      return;
    }

    await FirebaseFirestore.instance.collection('shops').doc(targetId).update({
      'status': ShopStatus.active.name,
    });
  }

  Future<void> updateShop({
    String? shopName,
    String? description,
    String? address,
    String? professionalEmail,
    String? logoUrl,
    String? bannerUrl,
  }) async {
    if (state.shop == null) return;

    final updates = <String, dynamic>{};
    if (shopName != null) updates['shopName'] = shopName;
    if (description != null) updates['description'] = description;
    if (address != null) updates['address'] = address;
    if (professionalEmail != null) updates['professionalEmail'] = professionalEmail;
    if (logoUrl != null) updates['logoUrl'] = logoUrl;
    if (bannerUrl != null) updates['bannerUrl'] = bannerUrl;

    if (updates.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(state.shop!.id)
        .update(updates);
  }

  // ===== PRODUCT MANAGEMENT =====
  Future<String?> addProduct({
    required String name,
    required String description,
    required double price,
    required int stockQuantity,
    required ProductCategory category,
    List<String>? imageUrls,
    String currency = 'FCFA',
  }) async {
    // Check prerequisites
    if (state.shop == null) {
      debugPrint('[MERCHANT] Cannot add product: no shop');
      return null;
    }

    // Check account limits for particulier
    if (!state.canPublish) {
      debugPrint('[MERCHANT] Cannot add product: ${state.publishBlockReason}');
      return state.publishBlockReason;
    }

    final doc = FirebaseFirestore.instance.collection('products').doc();
    final product = Product(
      id: doc.id,
      shopId: state.shop!.id,
      name: name,
      description: description,
      price: price,
      stockQuantity: stockQuantity,
      category: category,
      imageUrls: imageUrls ?? [],
      isActive: true,
      isApproved: false, // Requires moderation
      currency: currency,
      createdAt: DateTime.now(),
    );

    await doc.set(product.toFirestore());

    // Update account's offresActives count
    if (state.account != null) {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(state.account!.id)
          .update({'offres_actives': FieldValue.increment(1)});
    }

    debugPrint('[MERCHANT] Product added: ${doc.id}');
    return null; // null = success
  }

  Future<void> updateProduct({
    required String productId,
    String? name,
    String? description,
    double? price,
    int? stockQuantity,
    ProductCategory? category,
    List<String>? imageUrls,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (stockQuantity != null) updates['stockQuantity'] = stockQuantity;
    if (category != null) updates['category'] = category.name;
    if (imageUrls != null) updates['imageUrls'] = imageUrls;
    if (isActive != null) updates['isActive'] = isActive;

    if (updates.isEmpty) return;

    // If content changed, reset approval
    if (name != null || description != null || imageUrls != null) {
      updates['isApproved'] = false;
    }

    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update(updates);
  }

  Future<void> deleteProduct(String productId) async {
    await FirebaseFirestore.instance.collection('products').doc(productId).delete();

    // Decrement account's offresActives count
    if (state.account != null) {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(state.account!.id)
          .update({'offres_actives': FieldValue.increment(-1)});
    }
  }

  // ===== ORDER MANAGEMENT =====
  Future<String?> createOrder({
    required String buyerId,
    required String productId,
    required int quantity,
    String? externalPaymentLink,
  }) async {
    if (state.shop == null) return 'Boutique non configurée';

    // Find product
    final productIndex = state.products.indexWhere((p) => p.id == productId);
    if (productIndex == -1) return 'Produit non trouvé';

    final product = state.products[productIndex];
    if (!product.isActive || !product.isApproved) {
      return 'Produit non disponible';
    }
    if (product.stockQuantity < quantity) {
      return 'Stock insuffisant';
    }

    final doc = FirebaseFirestore.instance.collection('orders').doc();
    final order = Order(
      id: doc.id,
      shopId: state.shop!.id,
      buyerId: buyerId,
      productId: productId,
      productName: product.name,
      quantity: quantity,
      totalAmount: product.price * quantity,
      externalPaymentLink: externalPaymentLink,
      status: OrderStatus.pending,
      currency: product.currency,
      createdAt: DateTime.now(),
    );

    await doc.set(order.toFirestore());

    // Decrement stock
    await FirebaseFirestore.instance.collection('products').doc(productId).update({
      'stockQuantity': FieldValue.increment(-quantity),
    });

    return null; // Success
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final updates = <String, dynamic>{'status': newStatus.name};

    switch (newStatus) {
      case OrderStatus.paid:
        updates['paidAt'] = FieldValue.serverTimestamp();
        // Record sale for CA tracking
        final order = state.orders.firstWhere((o) => o.id == orderId);
        await _recordSale(order.totalAmount);
        break;
      case OrderStatus.shipped:
        updates['shippedAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.delivered:
        updates['deliveredAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.cancelled:
      case OrderStatus.returned:
        // Restore stock
        final cancelledOrder = state.orders.firstWhere((o) => o.id == orderId);
        await FirebaseFirestore.instance
            .collection('products')
            .doc(cancelledOrder.productId)
            .update({'stockQuantity': FieldValue.increment(cancelledOrder.quantity)});
        break;
      default:
        break;
    }

    await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updates);
  }

  Future<void> markOrderAsShipped(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.shipped);

  Future<void> markOrderAsPaid(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.paid);

  Future<void> markOrderAsDelivered(String orderId) =>
      updateOrderStatus(orderId, OrderStatus.delivered);

  // ===== CA TRACKING =====
  Future<void> _recordSale(double amount) async {
    if (state.account == null) return;

    await FirebaseFirestore.instance
        .collection('merchants')
        .doc(state.account!.id)
        .update({'ca_annuel': FieldValue.increment(amount)});

    // Check threshold (will be caught by listener)
    if (state.account!.type == MerchantType.particulier) {
      final newCa = state.account!.caAnnuel + amount;
      if (newCa >= MerchantAccount.particulierCaMax) {
        debugPrint('[MERCHANT] ⚠️ CA threshold exceeded: $newCa€');
        // Suspension handled by Cloud Function or manual review
      }
    }
  }

  // ===== UPGRADE =====
  Future<bool> upgradeToVerifie({
    required String siretNinea,
    required String idDocumentUrl,
    required String selfieUrl,
    String? iban,
  }) async {
    if (state.account == null || state.account!.type == MerchantType.verifie) {
      return false;
    }

    state = state.copyWith(isLoading: true);

    try {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(state.account!.id)
          .update({
        'type': MerchantType.verifie.name,
        'kyc_status': MerchantKycStatus.pending.name,
        'siret_ninea': siretNinea,
        'id_document_url': idDocumentUrl,
        'selfie_url': selfieUrl,
        if (iban != null) 'iban': iban,
      });

      debugPrint('[MERCHANT] Upgrade to Vérifié submitted');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }
}

// =============== PROVIDERS ===============

/// Main provider for merchant shop management (unified with account)
final merchantShopProvider = StateNotifierProvider<MerchantAccountNotifier, MerchantAccountState>((ref) {
  final user = ref.watch(userProvider);
  return MerchantAccountNotifier(ref, user.uid);
});

// Backward compatibility alias
final merchantAccountProvider = merchantShopProvider;

// Convenience providers
final activeProfileProvider = Provider<ActiveProfile>((ref) {
  return ref.watch(merchantShopProvider).activeProfile;
});

final hasMerchantAccountProvider = Provider<bool>((ref) {
  return ref.watch(merchantShopProvider).hasMerchantAccount;
});

final hasShopProvider = Provider<bool>((ref) {
  return ref.watch(merchantShopProvider).hasShop;
});

final isMerchantModeProvider = Provider<bool>((ref) {
  return ref.watch(merchantShopProvider).isMerchantMode;
});

final canPublishProvider = Provider<bool>((ref) {
  return ref.watch(merchantShopProvider).canPublish;
});

final merchantProductsProvider = Provider<List<Product>>((ref) {
  return ref.watch(merchantShopProvider).products;
});

final merchantOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(merchantShopProvider).orders;
});

final merchantRevenueProvider = Provider<double>((ref) {
  return ref.watch(merchantShopProvider).totalRevenue;
});
