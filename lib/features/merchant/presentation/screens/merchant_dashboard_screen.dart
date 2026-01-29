import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/merchant_account_provider.dart';
import 'package:tontetic/core/services/content_moderation_service.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

/// Merchant Dashboard Screen
/// Complete dashboard for merchant profile
/// 
/// Features:
/// - Overview (revenue, orders, products)
/// - Product management (CRUD)
/// - Order management (status updates)
/// - Transactions & export
/// - Profile switch

class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends ConsumerState<MerchantDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard, 'Accueil'),
    _NavItem(Icons.inventory, 'Produits'),
    _NavItem(Icons.shopping_cart, 'Commandes'),
    _NavItem(Icons.account_balance_wallet, 'Revenus'),
  ];

  // Demo initialization removed as requested.


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantAccountProvider);

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(state.shop?.shopName ?? 'Ma Boutique'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Profile switch
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Retour profil Particulier',
            onPressed: _switchToParticulier,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotifications(context, ref),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Legal banner
          _buildLegalBanner(),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        items: _navItems.map((n) => BottomNavigationBarItem(icon: Icon(n.icon), label: n.label)).toList(),
      ),
      floatingActionButton: _selectedIndex == 1 
        ? FloatingActionButton(
            onPressed: _addProduct,
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.add),
          )
        : null,
    );
  }

  Widget _buildLegalBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? Colors.deepPurple.shade900.withValues(alpha: 0.3) : Colors.deepPurple.shade50,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Les paiements passent par votre PSP. Tontetic agit comme outil technique uniquement.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildOverview();
      case 1: return _buildProducts();
      case 2: return _buildOrders();
      case 3: return _buildRevenue();
      default: return _buildOverview();
    }
  }

  Widget _buildDrawer() {
    final state = ref.watch(merchantAccountProvider);
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, color: Colors.deepPurple, size: 30),
                ),
                const SizedBox(height: 12),
                Text(state.shop?.shopName ?? 'Ma Boutique', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Profil Marchand', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Retour Particulier'),
            onTap: _switchToParticulier,
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Paramètres boutique'),
            onTap: () => _showSettings(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Aide'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // =============== OVERVIEW ===============
  Widget _buildOverview() {
    final state = ref.watch(merchantAccountProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vue d\'ensemble', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 16),

          // KPIs
          Row(
            children: [
              Expanded(child: _buildKpiCard('CA du mois', '${state.totalRevenue.toInt()} FCFA', Icons.trending_up, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Commandes', '${state.totalOrders}', Icons.shopping_cart, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildKpiCard('Produits', '${state.productsCount}', Icons.inventory, Colors.deepPurple)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCard('Stock faible', '${state.lowStockCount}', Icons.warning, Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),

          // Recent orders
          const Text('Commandes récentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (state.orders.isEmpty)
            _buildEmptyState('Aucune commande', 'Vos commandes apparaîtront ici')
          else
            ...state.orders.take(3).map((o) => _buildOrderCard(o)),
          const SizedBox(height: 24),

          // Quick actions
          const Text('Actions rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildQuickAction(Icons.add, 'Produit', Colors.deepPurple, _addProduct)),
              Expanded(child: _buildQuickAction(Icons.download, 'Export', Colors.green, () => _exportData(context))),
              Expanded(child: _buildQuickAction(Icons.message, 'Messages', Colors.blue, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💬 Messagerie pro bientôt disponible !'))))),
              Expanded(child: _buildQuickAction(Icons.settings, 'Paramètres', Colors.grey, () => _showSettings(context, ref))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // =============== PRODUCTS ===============
  Widget _buildProducts() {
    final products = ref.watch(merchantAccountProvider).products;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes Produits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 16),

          if (products.isEmpty)
            _buildEmptyState('Aucun produit', 'Ajoutez votre premier produit')
          else
            ...products.map((p) => _buildProductCard(p)),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.deepPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${p.price.toInt()} ${p.currency}', style: const TextStyle(color: Colors.deepPurple)),
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 14, color: p.stockQuantity < 5 ? Colors.red : Colors.grey),
                      const SizedBox(width: 4),
                      Text('Stock: ${p.stockQuantity}', style: TextStyle(fontSize: 12, color: p.stockQuantity < 5 ? Colors.red : Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
              onSelected: (v) {
                if (v == 'delete') {
                  ref.read(merchantAccountProvider.notifier).deleteProduct(p.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // =============== ORDERS ===============
  Widget _buildOrders() {
    final orders = ref.watch(merchantAccountProvider).orders;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Commandes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 8),
          const Text('Les données clients sont anonymisées pour votre protection mutuelle.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),

          // Filters
          Row(
            children: [
              _buildFilterChip('Toutes', true),
              const SizedBox(width: 8),
              _buildFilterChip('En attente', false),
              const SizedBox(width: 8),
              _buildFilterChip('Livrées', false),
            ],
          ),
          const SizedBox(height: 16),

          if (orders.isEmpty)
            _buildEmptyState('Aucune commande', 'Vos commandes apparaîtront ici')
          else
            ...orders.map((o) => _buildOrderCard(o)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {},
      selectedColor: Colors.deepPurple.withValues(alpha: 0.2),
    );
  }

  Widget _buildOrderCard(Order o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(o.anonymizedBuyerId, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                _buildOrderStatusBadge(o.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${o.totalAmount.toInt()} ${o.currency}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const Spacer(),
                if (o.status == OrderStatus.paid)
                  TextButton(
                    onPressed: () => ref.read(merchantAccountProvider.notifier).markOrderAsShipped(o.id),
                    child: const Text('Marquer expédié'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusBadge(OrderStatus status) {
    Color color;
    String label;
    switch (status) {
      case OrderStatus.pending: color = Colors.orange; label = 'En attente';
      case OrderStatus.paid: color = Colors.blue; label = 'Payé';
      case OrderStatus.processing: color = Colors.purple; label = 'Traitement';
      case OrderStatus.shipped: color = Colors.indigo; label = 'Expédié';
      case OrderStatus.delivered: color = Colors.green; label = 'Livré';
      case OrderStatus.cancelled: color = Colors.red; label = 'Annulé';
      case OrderStatus.returned: color = Colors.red; label = 'Retourné';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  // =============== REVENUE ===============
  Widget _buildRevenue() {
    final state = ref.watch(merchantAccountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenus & Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          const SizedBox(height: 8),
          const Text('Les montants affichés proviennent de votre PSP.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 24),

          // Revenue card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.purple]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chiffre d\'affaires', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('${state.totalRevenue.toInt()} FCFA', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildRevenueStat('Commandes', '${state.totalOrders}'),
                    const SizedBox(width: 24),
                    _buildRevenueStat('Produits', '${state.productsCount}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Export
          const Text('Exporter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildExportOption(Icons.picture_as_pdf, 'PDF', 'Rapport pour comptabilité', Colors.red),
          const SizedBox(height: 8),
          _buildExportOption(Icons.table_chart, 'CSV', 'Données brutes', Colors.green),
          const SizedBox(height: 24),

          // Disclaimer
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
                    'Tous les paiements sont traités par votre PSP. Tontetic n\'a aucun accès aux fonds.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildExportOption(IconData icon, String title, String subtitle, Color color) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.download),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export $title en cours...')));
        },
      ),
    );
  }

  // =============== ACTIONS ===============
  void _switchToParticulier() {
    ref.read(merchantAccountProvider.notifier).switchToParticulier();
    Navigator.pop(context);
  }

  void _showNotifications(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Notifications Marchand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('merchants')
                    .doc(user.uid)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final notes = snapshot.data?.docs ?? [];
                  if (notes.isEmpty) return const Center(child: Text('Aucune notification.', style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final n = notes[i].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.deepPurple),
                        title: Text(n['title'] ?? 'Notification'),
                        subtitle: Text(n['message'] ?? ''),
                        onTap: () => FirebaseFirestore.instance
                            .collection('merchants')
                            .doc(user.uid)
                            .collection('notifications')
                            .doc(notes[i].id)
                            .delete(), // Clear on tap
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    // Navigate to shop settings or show modal
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚙️ Ouverture des paramètres de la boutique...')));
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📊 Génération de l\'exportation (PDF/CSV)...')));
    // Real logic would involve creating a doc in an exports collection for a cloud function to process
  }

  void _addProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          final nameController = TextEditingController();
          final descController = TextEditingController();
          final priceController = TextEditingController();
          final stockController = TextEditingController();
          List<String> mediaUrls = [];
          ProductCategory category = ProductCategory.other;

          return StatefulBuilder(
            builder: (context, setModalState) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

                  const Text('Nouveau Produit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 24),

                  // Media upload section
                  const Text('Photos & Vidéos', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Add photo button
                        _buildMediaAddButton(
                          icon: Icons.add_a_photo,
                          label: 'Photo',
                          onTap: () {
                            setModalState(() {
                              mediaUrls.add('photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Photo simulée ajoutée')),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Add video button
                        _buildMediaAddButton(
                          icon: Icons.videocam,
                          label: 'Vidéo',
                          onTap: () {
                            setModalState(() {
                              mediaUrls.add('video_${DateTime.now().millisecondsSinceEpoch}.mp4');
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vidéo simulée ajoutée')),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        // Show added media
                        ...mediaUrls.map((url) => Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: url.contains('video') ? Colors.red.shade100 : Colors.deepPurple.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  url.contains('video') ? Icons.play_circle : Icons.image,
                                  color: url.contains('video') ? Colors.red : Colors.deepPurple,
                                  size: 32,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() => mediaUrls.remove(url));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez jusqu\'à 10 photos ou vidéos (${mediaUrls.length}/10)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_bag),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'Décrivez votre produit...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price & Stock
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Prix (FCFA)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Legal note
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
                            'Ajoutez votre lien de paiement externe dans la description ou configurez-le après.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Auto-scan content before submission
                        final moderation = ContentModerationService();
                        final scanResult = moderation.scanText(
                          '${nameController.text} ${descController.text}',
                          isNewMerchant: true, // TODO: Check if first product
                        );

                        if (!scanResult.isApproved) {
                          // Block forbidden content
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.block, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Contenu interdit'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Votre produit ne peut pas être publié :'),
                                  const SizedBox(height: 12),
                                  ...scanResult.violations.map((v) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error, color: Colors.red, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Modifier'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Show warning if pending review
                        if (scanResult.requiresManualReview) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Produit en attente de validation par notre équipe'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }

                        ref.read(merchantAccountProvider.notifier).addProduct(
                          name: nameController.text,
                          description: descController.text,
                          price: double.tryParse(priceController.text) ?? 0,
                          stockQuantity: int.tryParse(stockController.text) ?? 0,
                          category: category,
                          imageUrls: mediaUrls,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(scanResult.requiresManualReview 
                              ? 'Produit soumis - en attente de validation' 
                              : 'Produit publié !'),
                            backgroundColor: scanResult.requiresManualReview ? Colors.orange : Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Publier le produit', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaAddButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepPurple, width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.deepPurple, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.deepPurple)),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
