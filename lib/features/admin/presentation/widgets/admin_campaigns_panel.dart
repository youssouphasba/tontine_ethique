import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tontetic/core/services/campaign_service.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class AdminCampaignsPanel extends StatefulWidget {
  const AdminCampaignsPanel({super.key});

  @override
  State<AdminCampaignsPanel> createState() => _AdminCampaignsPanelState();
}

class _AdminCampaignsPanelState extends State<AdminCampaignsPanel> {
  final CampaignService _campaignService = CampaignService();
  bool _isCreating = false;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _deepLinkCtrl = TextEditingController();
  
  CampaignType _selectedType = CampaignType.push;
  TargetAudience _selectedAudience = TargetAudience.all;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  
  // Specific targeting
  final _specificIdsCtrl = TextEditingController();

  void _resetForm() {
    _nameCtrl.clear();
    _titleCtrl.clear();
    _contentCtrl.clear();
    _imageCtrl.clear();
    _deepLinkCtrl.clear();
    _specificIdsCtrl.clear();
    setState(() {
      _selectedType = CampaignType.push;
      _selectedAudience = TargetAudience.all;
      _scheduledDate = null;
      _scheduledTime = null;
      _isCreating = false;
    });
  }

  Future<void> _submitCampaign() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime? scheduledAt;
    if (_scheduledDate != null && _scheduledTime != null) {
      scheduledAt = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
    }

    List<String>? specificIds;
    if (_specificIdsCtrl.text.isNotEmpty) {
      specificIds = _specificIdsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    try {
      await _campaignService.createCampaign(
        name: _nameCtrl.text,
        type: _selectedType,
        audience: _selectedAudience,
        specificUserIds: specificIds,
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        imageUrl: _imageCtrl.text.isNotEmpty ? _imageCtrl.text : null,
        deepLink: _deepLinkCtrl.text.isNotEmpty ? _deepLinkCtrl.text : null,
        scheduledAt: scheduledAt,
        createdBy: 'Admin', // In real app, get current admin ID
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campagne créée avec succès !')));
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) {
      return _buildCreationForm();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Campagnes & Communications', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isCreating = true),
                icon: const Icon(Icons.add),
                label: const Text('NOUVELLE CAMPAGNE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.marineBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Campaign>>(
              stream: _campaignService.getCampaignsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final campaigns = snapshot.data ?? [];
                if (campaigns.isEmpty) {
                  return const Center(child: Text('Aucune campagne trouvée. Créez-en une !', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) => _buildCampaignCard(campaigns[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(Campaign campaign) {
    Color statusColor;
    IconData statusIcon;
    switch (campaign.status) {
      case CampaignStatus.draft: statusColor = Colors.grey; statusIcon = Icons.edit; break;
      case CampaignStatus.scheduled: statusColor = Colors.orange; statusIcon = Icons.schedule; break;
      case CampaignStatus.sending: statusColor = Colors.blue; statusIcon = Icons.send; break;
      case CampaignStatus.sent: statusColor = Colors.green; statusIcon = Icons.check_circle; break;
      case CampaignStatus.cancelled: statusColor = Colors.red; statusIcon = Icons.cancel; break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(campaign.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${campaign.name} • ${_campaignService.getCampaignTypeLabel(campaign.type)}', 
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_campaignService.getAudienceLabel(campaign.audience)),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.blue, fontSize: 12),
                ),
                const SizedBox(width: 12),
                if (campaign.status == CampaignStatus.draft)
                  TextButton.icon(
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('ENVOYER'),
                    onPressed: () => _campaignService.sendCampaign(campaign.id),
                  ),
                if (campaign.status == CampaignStatus.scheduled)
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('ANNULER'),
                    onPressed: () => _campaignService.cancelCampaign(campaign.id),
                  ),
              ],
            ),
            if (campaign.status == CampaignStatus.sent) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                   _buildStat('Cible', '${campaign.stats.targetedUsers}'),
                   _buildStat('Envoyés', '${campaign.stats.delivered}'),
                   _buildStat('Ouverts', '${campaign.stats.opened}'),
                   _buildStat('Clics', '${campaign.stats.clicked}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
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
                const Text('Créer une nouvelle campagne', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 32),
            
            // Step 1: Configuration
            const Text('Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CampaignType>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Canal', border: OutlineInputBorder()),
                    items: CampaignType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_campaignService.getCampaignTypeLabel(t)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom interne (ex: Promo Noël)', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Step 2: Ciblage
            const Text('Audience & Ciblage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<TargetAudience>(
              value: _selectedAudience,
              decoration: const InputDecoration(labelText: 'Segment Cible', border: OutlineInputBorder()),
              items: TargetAudience.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(_campaignService.getAudienceLabel(t)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedAudience = v!),
            ),
            const SizedBox(height: 8),
            const Text('Critères avancés: Inactifs > 30j, Score Fidélité, Rôle (Marchand/Entreprise)', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
             TextFormField(
              controller: _specificIdsCtrl,
              decoration: const InputDecoration(
                labelText: 'Ids Spécifiques (Optionnel)', 
                hintText: 'user_123, user_456 (séparés par virgule)',
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 24),

            // Step 3: Contenu
            const Text('Contenu du message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message / Corps', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageCtrl,
              decoration: const InputDecoration(labelText: 'URL Image (Optionnel)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)),
            ),
            const SizedBox(height: 24),

            // Step 4: Planification
            const Text('Planification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(_scheduledDate == null ? 'Envoyer immédiatement' : 'Date: ${DateFormat('dd/MM/yyyy').format(_scheduledDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.grey)),
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (date != null) setState(() => _scheduledDate = date);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    enabled: _scheduledDate != null,
                    title: Text(_scheduledTime == null ? '--:--' : _scheduledTime!.format(context)),
                    trailing: const Icon(Icons.access_time),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.grey)),
                    onTap: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) setState(() => _scheduledTime = time);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _resetForm, child: const Text('ANNULER')),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _submitCampaign,
                  icon: const Icon(Icons.check),
                  label: Text(_scheduledDate != null ? 'PLANIFIER' : 'ENVOYER MAINTENANT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _scheduledDate != null ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
