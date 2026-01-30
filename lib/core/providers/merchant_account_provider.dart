import 'package:tontetic/core/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// =============== ENUMS ===============

enum ActiveProfile { particulier, marchand }

enum MerchantAccountStatus { pending, active, suspended, rejected }

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
  final String userId;
  final String shopName;
  final ProductCategory category;
  final DateTime createdAt;
  final String? professionalEmail;
  final String? pspAccountId;
  final String? address;
  final String? description;
  final String? logoUrl;
  final MerchantAccountStatus status;

  MerchantShop({
    required this.id,
    required this.userId,
    required this.shopName,
    required this.category,
    required this.createdAt,
    this.professionalEmail,
    this.pspAccountId,
    this.address,
    this.description,
    this.logoUrl,
    required this.status,
  });
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
    this.currency = 'FCFA',
  });
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
}

// =============== STATE ===============

class MerchantAccountState {
  final MerchantShop? shop;
  final List<Product> products;
  final List<Order> orders;
  final double totalRevenue;
  final int totalOrders;
  final ActiveProfile activeProfile;

  MerchantAccountState({
    this.shop,
    this.products = const [],
    this.orders = const [],
    this.totalRevenue = 0.0,
    this.totalOrders = 0,
    this.activeProfile = ActiveProfile.particulier,
  });

  bool get hasMerchantAccount => shop != null;
  bool get isMerchantMode => activeProfile == ActiveProfile.marchand;
  int get productsCount => products.length;
  int get lowStockCount => products.where((p) => p.stockQuantity < 5).length;

  MerchantAccountState copyWith({
    MerchantShop? shop,
    List<Product>? products,
    List<Order>? orders,
    double? totalRevenue,
    int? totalOrders,
    ActiveProfile? activeProfile,
  }) {
    return MerchantAccountState(
      shop: shop, // shop can be null, but copyWith shouldn't force null if not provided. 
                  // Wait, how to handle "nullable override"? 
                  // For simplicity in this fix, assume if passed as null (and not omitted), it updates to null? 
                  // Dart copyWith pattern usually keeps old if null.
                  // To strictly clear it, we'd need a sentinel.
                  // But here, let's just stick to "keep if null".
                  // However, logical update: usually we pass new value.
      products: products ?? this.products,
      orders: orders ?? this.orders,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalOrders: totalOrders ?? this.totalOrders,
      activeProfile: activeProfile ?? this.activeProfile,
    );
  }
}

// =============== NOTIFIER ===============

class MerchantAccountNotifier extends StateNotifier<MerchantAccountState> {
  final Ref ref;
  final String? userId;
  
  StreamSubscription? _shopSub;
  StreamSubscription? _productsSub;
  StreamSubscription? _ordersSub;

  MerchantAccountNotifier(this.ref, this.userId) : super(MerchantAccountState()) {
    _init();
  }
  
  void _init() {
    if (userId == null) return;
    
    // Listen to Shop
    _shopSub = FirebaseFirestore.instance
        .collection('shops')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final shop = MerchantShop(
          id: doc.id,
          userId: data['userId'],
          shopName: data['shopName'],
          category: ProductCategory.values.firstWhere((e) => e.toString() == 'ProductCategory.${data['category']}', orElse: () => ProductCategory.other),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          professionalEmail: data['professionalEmail'],
          pspAccountId: data['pspAccountId'],
          address: data['address'],
          description: data['description'],
          logoUrl: data['logoUrl'],
          status: MerchantAccountStatus.values.firstWhere((e) => e.toString() == 'MerchantAccountStatus.${data['status']}', orElse: () => MerchantAccountStatus.pending),
        );
        
        // If shop found and state was empty (or different), update.
        // Also ensure correct profile if desired, but user switches explicitly.
        state = MerchantAccountState(
          shop: shop,
          products: state.products, // keep existing if any
          orders: state.orders,
          totalRevenue: state.totalRevenue,
          totalOrders: state.totalOrders,
          activeProfile: state.activeProfile,
        );
        _initShopData(shop.id);
      } else {
        // No shop
        state = MerchantAccountState(activeProfile: ActiveProfile.particulier);
        _productsSub?.cancel();
        _ordersSub?.cancel();
      }
    });
  }
  
  void _initShopData(String shopId) {
    // Listen to Products
    _productsSub?.cancel();
    _productsSub = FirebaseFirestore.instance
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .listen((snapshot) {
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          shopId: data['shopId'],
          name: data['name'],
          description: data['description'],
          price: (data['price'] as num).toDouble(),
          stockQuantity: data['stockQuantity'],
          category: ProductCategory.values.firstWhere((e) => e.toString() == 'ProductCategory.${data['category']}', orElse: () => ProductCategory.other),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          isActive: data['isActive'] ?? true,
          currency: data['currency'] ?? 'FCFA',
        );
      }).toList();
      state = state.copyWith(products: products);
    });
    
    // Listen to Orders
    _ordersSub?.cancel();
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .listen((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data();
        return Order(
          id: doc.id,
          shopId: data['shopId'],
          buyerId: data['buyerId'],
          productId: data['productId'],
          productName: data['productName'],
          quantity: data['quantity'],
          totalAmount: (data['totalAmount'] as num).toDouble(),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: OrderStatus.values.firstWhere((e) => e.toString() == 'OrderStatus.${data['status']}', orElse: () => OrderStatus.pending),
          pspTransactionId: data['pspTransactionId'],
          paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
          shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
          deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
          externalPaymentLink: data['externalPaymentLink'],
          currency: data['currency'] ?? 'FCFA',
        );
      }).toList();
      
      // Calculate totals
      final totalRevenue = orders
          .where((o) => o.status == OrderStatus.paid || o.status == OrderStatus.shipped || o.status == OrderStatus.delivered)
          .fold(0.0, (total, o) => total + o.totalAmount);
          
      state = state.copyWith(orders: orders, totalRevenue: totalRevenue, totalOrders: orders.length);
    });
  }

  @override
  void dispose() {
    _shopSub?.cancel();
    _productsSub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }

  // ===== PROFILE SWITCHING =====
  void switchToMerchant() {
    if (state.hasMerchantAccount) {
      state = state.copyWith(activeProfile: ActiveProfile.marchand);
    }
  }

  void switchToParticulier() {
    state = state.copyWith(activeProfile: ActiveProfile.particulier);
  }

  void toggleProfile() {
    if (state.isMerchantMode) {
      switchToParticulier();
    } else if (state.hasMerchantAccount) {
      switchToMerchant();
    }
  }

  // ===== SHOP MANAGEMENT =====
  Future<String> createShop({
    required String userId,
    required String shopName,
    String? professionalEmail,
    required ProductCategory category,
    String? address,
    String? description,
  }) async {
    final doc = FirebaseFirestore.instance.collection('shops').doc();
    final shopData = {
      'id': doc.id,
      'userId': userId,
      'shopName': shopName,
      'professionalEmail': professionalEmail,
      'category': category.toString().split('.').last,
      'address': address,
      'description': description,
      'status': 'pending_payment', // Waiting for Stripe Subscription
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(shopData);
    return doc.id;
  }

  Future<void> activateShop(String shopId) async {
    // If shopId is provided, use it directly (useful for payment callback)
    // Otherwise use current state shop
    final targetId = shopId.isNotEmpty ? shopId : state.shop?.id;
    
    if (targetId == null) {
        debugPrint("Error: activateShop called with no shopId and no state shop");
        return;
    }

    await FirebaseFirestore.instance.collection('shops').doc(targetId).update({
      'status': 'active',
      // 'pspAccountId': ... // No longer required for simple merchant sub
    });
    
    // Refresh local state if needed
    if (state.shop?.id == targetId) {
        // Optimistic update or wait for stream
    }
  }

  Future<void> updateShop({
    String? shopName,
    String? description,
    String? address,
    String? professionalEmail,
  }) async {
    if (state.shop == null) return;
    
    final updates = <String, dynamic>{};
    if (shopName != null) updates['shopName'] = shopName;
    if (description != null) updates['description'] = description;
    if (address != null) updates['address'] = address;
    if (professionalEmail != null) updates['professionalEmail'] = professionalEmail;
    
    if (updates.isEmpty) return;
    
    await FirebaseFirestore.instance.collection('shops').doc(state.shop!.id).update(updates);
  }

  // ===== PRODUCT MANAGEMENT =====
  Future<void> addProduct({
    required String name,
    required String description,
    required double price,
    required int stockQuantity,
    required ProductCategory category,
    List<String>? imageUrls,
  }) async {
    if (state.shop == null) return;
    final doc = FirebaseFirestore.instance.collection('products').doc();
    await doc.set({
      'shopId': state.shop!.id,
      'name': name,
      'description': description,
      'price': price,
      'stockQuantity': stockQuantity,
      'category': category.toString().split('.').last,
      'imageUrls': imageUrls ?? [],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    if (category != null) updates['category'] = category.toString().split('.').last;
    if (imageUrls != null) updates['imageUrls'] = imageUrls;
    if (isActive != null) updates['isActive'] = isActive;
    
    if (updates.isEmpty) return;
    
    await FirebaseFirestore.instance.collection('products').doc(productId).update(updates);
  }

  Future<void> deleteProduct(String productId) async {
    await FirebaseFirestore.instance.collection('products').doc(productId).delete();
  }

  // ===== ORDER MANAGEMENT =====
  Future<void> createOrder({
     required String buyerId,
     required String productId,
     required int quantity,
     required String externalPaymentLink,
  }) async {
    // This is primarily for testing or manual order creation
    if (state.shop == null) return;
    
    // Find product to get price/name
    final product = state.products.firstWhere((p) => p.id == productId, orElse: () => throw Exception("Product found"));
    
    final doc = FirebaseFirestore.instance.collection('orders').doc();
    await doc.set({
      'shopId': state.shop!.id,
      'buyerId': buyerId,
      'productId': productId,
      'productName': product.name,
      'quantity': quantity,
      'totalAmount': product.price * quantity,
      'externalPaymentLink': externalPaymentLink,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markOrderAsShipped(String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'shipped',
      'shippedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markOrderAsPaid(String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markOrderAsDelivered(String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }
}

// =============== PROVIDERS ===============

final merchantAccountProvider = StateNotifierProvider<MerchantAccountNotifier, MerchantAccountState>((ref) {
  final user = ref.watch(userProvider);
  return MerchantAccountNotifier(ref, user.uid);
});

final activeProfileProvider = Provider<ActiveProfile>((ref) {
  return ref.watch(merchantAccountProvider).activeProfile;
});

final hasMerchantAccountProvider = Provider<bool>((ref) {
  return ref.watch(merchantAccountProvider).hasMerchantAccount;
});

final isMerchantModeProvider = Provider<bool>((ref) {
  return ref.watch(merchantAccountProvider).isMerchantMode;
});
