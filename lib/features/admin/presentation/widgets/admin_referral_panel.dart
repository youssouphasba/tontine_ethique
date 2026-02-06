import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/services/referral_service.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class AdminReferralPanel extends StatefulWidget {
  const AdminReferralPanel({super.key});

  @override
  State<AdminReferralPanel> createState() => _AdminReferralPanelState();
}

class _AdminReferralPanelState extends State<AdminReferralPanel> {
  final ReferralService _referralService = ReferralService();
  bool _isCreating = false;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rewardCtrl = TextEditingController(); // Amount/Value
  
  ReferralRewardType _selectedRewardType = ReferralRewardType.subscriptionMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  int _maxReferrals = 50;
  int _minCircles = 1;

  void _resetForm() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _rewardCtrl.clear();
    setState(() {
      _selectedRewardType = ReferralRewardType.subscriptionMonth;
      _startDate = DateTime.now();
      _endDate = null;
      _isCreating = false;
    });
  }

  Future<void> _submitCampaign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date de début requise')));
      return;
    }

    final rewardVal = double.tryParse(_rewardCtrl.text) ?? 0.0;

    try {
      // Direct Firestore write as per "No Mocks" rule and to ensure data persistence
      await FirebaseFirestore.instance.collection('referral_campaigns').add({
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'rewardType': _selectedRewardType.name,
        'rewardValue': rewardVal,
        'isActive': true, // Active by default when created from here? Or draft. Let's say Active for now based on button label.
        'status': 'active',
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'maxReferralsPerUser': _maxReferrals,
        'minCirclesToValidate': _minCircles,
        'createdAt': FieldValue.serverTimestamp(),
        'totalReferrals': 0,
        'totalRewardsDistributed': 0,
        'targetAudience': ['all'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campagne de parrainage créée !')));
        _resetForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _toggleCampaignStatus(String id, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('referral_campaigns').doc(id).update({
        'isActive': !currentStatus,
        'status': !currentStatus ? 'active' : 'paused',
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) return _buildCreationForm();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Programme de Parrainage (V2)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isCreating = true),
                icon: const Icon(Icons.add),
                label: const Text('NOUVELLE OFFRE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.marineBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('referral_campaigns').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('Aucune offre de parrainage active.'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final isActive = data['isActive'] == true;
                    // Safely parse enum
                    final rTypeStr = data['rewardType'] as String? ?? 'subscriptionMonth';
                    final rType = ReferralRewardType.values.firstWhere(
                      (e) => e.name == rTypeStr,
                      orElse: () => ReferralRewardType.subscriptionMonth
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          child: Icon(Icons.loyalty, color: isActive ? Colors.green : Colors.grey),
                        ),
                        title: Text(data['name'] ?? 'Campagne'),
                        subtitle: Text('${_referralService.getRewardTypeLabel(rType)} : ${data['rewardValue'] ?? 0}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(isActive ? 'ACTIVE' : 'INACTIVE'),
                              backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              labelStyle: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isActive,
                              onChanged: (v) => _toggleCampaignStatus(id, isActive),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                IconButton(onPressed: _resetForm, icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                const Text('Nouvelle Offre de Parrainage', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),

            // Settings
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom de la campagne (ex: Boost Été)', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<ReferralRewardType>(
                    value: _selectedRewardType,
                    decoration: const InputDecoration(labelText: 'Type de Récompense', border: OutlineInputBorder()),
                    items: ReferralRewardType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_referralService.getRewardTypeLabel(t)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedRewardType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (visible par les utilisateurs)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                 Expanded(
                  child: TextFormField(
                    controller: _rewardCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valeur (Mois / EUR / Cotisations)', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: ListTile(
                    title: Text(_startDate == null ? 'Date début' : DateFormat('dd/MM/yyyy').format(_startDate!)),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365*2)));
                      if (date != null) setState(() => _startDate = date);
                    },
                   ),
                 ), 
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            
            // Actions
            SizedBox(
              width: double.infinity, 
              height: 50, 
              child: ElevatedButton(
                onPressed: _submitCampaign, 
                child: const Text('CRÉER ET ACTIVER')
              )
            ),
          ],
        ),
      ),
    );
  }
}
