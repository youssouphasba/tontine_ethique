import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/auth/presentation/widgets/otp_dialog.dart';
import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  UserType? _selectedType; // Step 1 Selection
  
  // Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  
  // Specifics
  final _birthDateController = TextEditingController(); // Individual
  final _siretController = TextEditingController(); // Company
  final _representativeController = TextEditingController(); // Company

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // 1. Mise à jour des données (Encryptées par le provider/service)
      ref.read(userProvider.notifier).updateProfile(
        name: _nameController.text,
        address: _addressController.text,
        type: _selectedType!,
        birthDate: _selectedType == UserType.individual ? _birthDateController.text : null,
        siret: _selectedType == UserType.company ? _siretController.text : null,
        representative: _selectedType == UserType.company ? _representativeController.text : null,
      );
      
      // 2. Navigation vers OTP (via Dialog)
      _showOtpDialog();
    }
  }

  void _showOtpDialog() async {
    final user = ref.read(userProvider);
    final result = await OtpDialog.show(context, phone: user.phoneNumber);

    if (result == 'SUCCESS' && mounted) {
       Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Création de Compte'), backgroundColor: AppTheme.marineBlue),
      body: _selectedType == null ? _buildTypeSelection() : _buildForm(),
    );
  }

  Widget _buildTypeSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Bienvenue !', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
          const Text('Pour commencer, dites-nous qui vous êtes.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          
          _buildTypeCard(
            title: 'Je suis un Particulier',
            subtitle: 'Pour moi, ma famille ou mes amis.',
            icon: Icons.person,
            color: Colors.blue,
            type: UserType.individual,
          ),
          const SizedBox(height: 16),
          _buildTypeCard(
            title: 'Je suis une Entreprise',
            subtitle: 'Pour mes employés, mes associés ou ma trésorerie.',
            icon: Icons.business,
            color: Colors.orange,
            type: UserType.company,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({required String title, required String subtitle, required IconData icon, required Color color, required UserType type}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(radius: 30, backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 30)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final isCompany = _selectedType == UserType.company;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedType = null)),
                Text(isCompany ? 'Compte Entreprise' : 'Compte Particulier', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Common Fields
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: isCompany ? 'Dénomination Sociale' : 'Nom Complet',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(isCompany ? Icons.business : Icons.person),
              ),
              validator: (v) => v!.isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            
            // Specific Fields
            if (isCompany) ...[
              TextFormField(
                controller: _siretController,
                decoration: const InputDecoration(labelText: 'Numéro SIRET / NINEA', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _representativeController,
                decoration: const InputDecoration(labelText: 'Représentant Légal (Nom)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _birthDateController,
                decoration: const InputDecoration(labelText: 'Date de Naissance (JJ/MM/AAAA)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.cake)),
                keyboardType: TextInputType.datetime,
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Address (Mock)
             TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse Complète',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirmer & Vérifier (OTP)'),
            ),
          ],
        ),
      ),
    );
  }
}
