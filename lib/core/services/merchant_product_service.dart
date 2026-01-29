import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// V17.1: Merchant Product Service
/// Fetches real products from Firestore instead of hardcoded data
class MerchantProduct {
  final String id;
  final String title;
  final String price;
  final String merchantId;
  final String merchantName;
  final String tag;
  final String? imageUrl;
  final DateTime createdAt;

  MerchantProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.merchantId,
    required this.merchantName,
    required this.tag,
    this.imageUrl,
    required this.createdAt,
  });

  factory MerchantProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MerchantProduct(
      id: doc.id,
      title: data['title'] ?? 'Sans titre',
      price: data['price'] ?? '0 FCFA',
      merchantId: data['merchantId'] ?? '',
      merchantName: data['merchantName'] ?? 'Marchand',
      tag: data['tag'] ?? '📦 Autre',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class MerchantProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get all active products for the discovery feed
  Stream<List<MerchantProduct>> getActiveProducts({int limit = 20}) {
    return _db
        .collection('merchant_products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MerchantProduct.fromFirestore(doc))
            .toList());
  }

  /// Get products by category/tag
  Stream<List<MerchantProduct>> getProductsByTag(String tag) {
    return _db
        .collection('merchant_products')
        .where('tag', isEqualTo: tag)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MerchantProduct.fromFirestore(doc))
            .toList());
  }

  /// Get products by merchant
  Stream<List<MerchantProduct>> getMerchantProducts(String merchantId) {
    return _db
        .collection('merchant_products')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MerchantProduct.fromFirestore(doc))
            .toList());
  }

  /// Create a new product listing
  Future<String> createProduct({
    required String title,
    required String price,
    required String merchantId,
    required String merchantName,
    required String tag,
    String? imageUrl,
  }) async {
    try {
      final docRef = await _db.collection('merchant_products').add({
        'title': title,
        'price': price,
        'merchantId': merchantId,
        'merchantName': merchantName,
        'tag': tag,
        'imageUrl': imageUrl,
        'isActive': true,
        'views': 0,
        'clicks': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[MERCHANT] ✅ Product created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[MERCHANT] ❌ Error creating product: $e');
      rethrow;
    }
  }

  /// Increment product views
  Future<void> incrementViews(String productId) async {
    await _db.collection('merchant_products').doc(productId).update({
      'views': FieldValue.increment(1),
    });
  }

  /// Increment product clicks (contact button)
  Future<void> incrementClicks(String productId) async {
    await _db.collection('merchant_products').doc(productId).update({
      'clicks': FieldValue.increment(1),
    });
  }
}
