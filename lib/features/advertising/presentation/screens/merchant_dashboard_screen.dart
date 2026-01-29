import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/advertising/data/ad_campaign.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// Merchant Dashboard Screen - PRODUCTION VERSION
/// All campaigns are stored in Firestore 'ad_campaigns' collection
class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends ConsumerState<MerchantDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final merchantId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Marchand Pro'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.gold),
            onPressed: _showCreateCampaignDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(merchantId),
            const SizedBox(height: 24),
            const Text('Mes Campagnes Actives', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildCampaignsList(merchantId),
          ],
        ),
      ),
    );
  }

  /// KPI Summary Cards - Data from Firestore
  Widget _buildSummaryCards(String userId) {
    final user = ref.watch(userProvider);
    final currency = user.zone.currency;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('merchants')
          .where('userId', isEqualTo: user.phoneNumber)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Compte marchand non trouvé', style: TextStyle(color: Colors.white70)));
        }
        
        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final followers = data['followersCount'] ?? 0;
        final totalViews = data['totalViews'] ?? 0;
        final totalClicks = data['totalClicks'] ?? 0;
        final totalSpent = data['totalSpent'] ?? 0.0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'Abonnés 🤝', 
                    followers.toString(), 
                    Icons.people, 
                    AppTheme.gold,
                    gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF000000)]),
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    'Vues Totales', 
                    _formatNumber(totalViews), 
                    Icons.visibility, 
                    Colors.blue,
                    gradient: const LinearGradient(colors: [Color(0xFF2980B9), Color(0xFF6DD5FA)]),
                  )
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'Clics Directs', 
                    totalClicks.toString(), 
                    Icons.touch_app, 
                    Colors.greenAccent,
                    gradient: const LinearGradient(colors: [Color(0xFF1D976C), Color(0xFF93F9B9)]),
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    'Budget Utilisé', 
                    '${_formatNumber(totalSpent)} $currency', 
                    Icons.account_balance_wallet, 
                    Colors.orange,
                    gradient: const LinearGradient(colors: [Color(0xFFF09819), Color(0xFFEDDE5D)]),
                  )
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, {Gradient? gradient}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: gradient != null ? LinearGradient(
          colors: gradient.colors.map((c) => c.withAlpha(200)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: gradient != null ? Colors.white : color, size: 20),
              const Icon(Icons.trending_up, color: Colors.white70, size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 20,
              color: gradient != null ? Colors.white : Colors.black87,
            )
          ),
          Text(
            label.toUpperCase(), 
            style: TextStyle(
              fontSize: 9, 
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: gradient != null ? Colors.white70 : Colors.grey,
            )
          ),
        ],
      ),
    );
  }

  /// Campaigns List - REAL from Firestore
  Widget _buildCampaignsList(String merchantId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ad_campaigns')
          .where('merchantId', isEqualTo: merchantId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final campaigns = snapshot.data?.docs ?? [];

        if (campaigns.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('Aucune campagne', style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Cliquez sur + pour créer votre première campagne', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }

        return Column(
          children: campaigns.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final campaign = AdCampaign(
              id: doc.id,
              merchantId: data['merchantId'] ?? '',
              title: data['title'] ?? 'Sans titre',
              imageUrl: data['imageUrl'] ?? '',
              targetObjective: data['targetObjective'] ?? '',
              budget: (data['budget'] ?? 0).toDouble(),
              clicks: data['clicks'] ?? 0,
              status: _parseStatus(data['status']),
            );
            return _buildCampaignCard(campaign);
          }).toList(),
        );
      },
    );
  }

  AdStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved': return AdStatus.approved;
      case 'rejected': return AdStatus.rejected;
      default: return AdStatus.pending;
    }
  }

  Widget _buildCampaignCard(AdCampaign campaign) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
            image: campaign.imageUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(campaign.imageUrl), fit: BoxFit.cover)
                : null,
          ),
          child: campaign.imageUrl.isEmpty ? const Icon(Icons.image) : null,
        ),
        title: Text(campaign.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Ciblage: ${campaign.targetObjective} • Budget: ${campaign.budget.toInt()} F'),
        trailing: _buildStatusChip(campaign.status),
      ),
    );
  }

  Widget _buildStatusChip(AdStatus status) {
    Color color;
    String label;
    switch (status) {
      case AdStatus.pending: color = Colors.orange; label = 'En Attente'; break;
      case AdStatus.approved: color = Colors.green; label = 'Actif'; break;
      case AdStatus.rejected: color = Colors.red; label = 'Rejeté'; break;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showCreateCampaignDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle Campagne'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(labelText: 'Ciblage (ex: Moto)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Budget (FCFA)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final user = ref.read(userProvider);
              final userId = user.phoneNumber; 
              if (userId.isEmpty || titleController.text.isEmpty) return;

              try {
                // Get real merchant ID first
                final merchantQuery = await FirebaseFirestore.instance
                    .collection('merchants')
                    .where('userId', isEqualTo: userId)
                    .limit(1)
                    .get();

                if (merchantQuery.docs.isEmpty) {
                  throw Exception('Veuillez d\'abord finaliser votre inscription marchand.');
                }

                final merchantId = merchantQuery.docs.first.id;
                final budget = double.tryParse(budgetController.text) ?? 0;
                
                await FirebaseFirestore.instance.collection('ad_campaigns').add({
                  'merchantId': merchantId,
                  'title': titleController.text.trim(),
                  'targetObjective': targetController.text.trim(),
                  'budget': budget,
                  'clicks': 0,
                  'status': 'pending',
                  'imageUrl': '',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // Increment total spent placeholder or similar if logic exists
                // await FirebaseFirestore.instance.collection('merchants').doc(userId).update({
                //   'totalSpent': FieldValue.increment(budget),
                // });

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Campagne créée ! En attente de validation.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: Colors.black),
            child: const Text('Lancer la Campagne'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
