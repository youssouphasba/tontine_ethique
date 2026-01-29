
// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/features/advertising/presentation/screens/merchant_dashboard_screen.dart';

/// Privacy levels for profile fields
/// - public: Visible to everyone
/// - friends: Visible only to mutual followers
/// - private: Not visible to anyone except the user
enum FieldPrivacy { public, friends, private }

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _bioCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  bool _isEditing = false;
  bool _isUploadingPhoto = false;
  
  // Privacy controls for each field
  BioPrivacyLevel _bioPrivacy = BioPrivacyLevel.public;
  BioPrivacyLevel _jobPrivacy = BioPrivacyLevel.public;
  BioPrivacyLevel _companyPrivacy = BioPrivacyLevel.public;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _bioCtrl.text = user.bio;
    _jobCtrl.text = user.jobTitle;
    _companyCtrl.text = user.company;
    _bioPrivacy = user.bioPrivacy;
    // For now, use the same privacy level for all fields
    _jobPrivacy = user.bioPrivacy;
    _companyPrivacy = user.bioPrivacy;
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _jobCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    ref.read(userProvider.notifier).updateExtendedProfile(
      bio: _bioCtrl.text,
      job: _jobCtrl.text,
      company: _companyCtrl.text,
      privacy: _bioPrivacy, // For now, use bio privacy as the main one
    );
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil mis à jour ! ✅'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter')),
      );
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    
    if (image != null) {
      setState(() => _isUploadingPhoto = true);
      
      try {
        // Read image bytes
        final Uint8List imageBytes = await image.readAsBytes();
        
        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('$uid.jpg');
        
        final uploadTask = await storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        // Get download URL
        final photoUrl = await uploadTask.ref.getDownloadURL();
        
        // Add cache-bust parameter to force browser to reload
        final photoUrlWithCacheBust = '$photoUrl&t=${DateTime.now().millisecondsSinceEpoch}';
        
        // Update Firestore user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'photoUrl': photoUrl, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        
        // Update local state with cache-busted URL
        ref.read(userProvider.notifier).updatePhoto(photoUrlWithCacheBust);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo de profil mise à jour ! 📸'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'upload : $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploadingPhoto = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localizationProvider);
    final user = ref.watch(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile_title')),
        actions: [
          if (_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = false),
              icon: const Icon(Icons.close, color: Colors.white),
              label: const Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo de profil (toujours visible)
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        backgroundImage: user.photoUrl != null 
                          ? NetworkImage(user.photoUrl!) 
                          : null,
                        child: user.photoUrl == null 
                          ? Icon(Icons.person, size: 60, color: isDark ? Colors.white54 : Colors.grey.shade400)
                          : null,
                      ),
                      // Loading overlay during upload
                      if (_isUploadingPhoto)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                      if (_isEditing && !_isUploadingPhoto)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.marineBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('Toujours visible', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Nom et informations de base
            Center(
              child: Column(
                children: [
                  Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                  const SizedBox(height: 4),
                  Text('${user.phoneNumber} • ${user.zone.label}', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Section Bio
            _buildEditableField(
              title: 'Bio',
              icon: Icons.info_outline,
              controller: _bioCtrl,
              value: user.bio,
              placeholder: 'Parlez de vous...',
              privacy: _bioPrivacy,
              onPrivacyChanged: (p) => setState(() => _bioPrivacy = p),
              maxLines: 4,
            ),
            
            const SizedBox(height: 24),
            
            // Section Métier
            _buildEditableField(
              title: 'Métier',
              icon: Icons.work_outline,
              controller: _jobCtrl,
              value: user.jobTitle,
              placeholder: 'Ex: Développeur, Enseignant...',
              privacy: _jobPrivacy,
              onPrivacyChanged: (p) => setState(() => _jobPrivacy = p),
            ),
            
            const SizedBox(height: 24),
            
            // Section Entreprise
            _buildEditableField(
              title: 'Entreprise',
              icon: Icons.business_outlined,
              controller: _companyCtrl,
              value: user.company,
              placeholder: 'Ex: Google, Microsoft...',
              privacy: _companyPrivacy,
              onPrivacyChanged: (p) => setState(() => _companyPrivacy = p),
            ),
            
            const SizedBox(height: 24),
            
            // Language Toggle
            _buildSectionTitle(l10n.translate('language_label'), Icons.language),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(l10n.translate('french')),
                    leading: Radio<AppLanguage>(
                      value: AppLanguage.fr,
                      groupValue: l10n.language,
                      fillColor: WidgetStateProperty.all(isDark ? AppTheme.gold : AppTheme.marineBlue),
                      onChanged: (val) => ref.read(localizationProvider.notifier).setLanguage(val!),
                    ),
                    onTap: () => ref.read(localizationProvider.notifier).setLanguage(AppLanguage.fr),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: Text(l10n.translate('wolof')),
                    leading: Radio<AppLanguage>(
                      value: AppLanguage.wo,
                      groupValue: l10n.language,
                      fillColor: WidgetStateProperty.all(isDark ? AppTheme.gold : AppTheme.marineBlue),
                      onChanged: (val) => ref.read(localizationProvider.notifier).setLanguage(val!),
                    ),
                    onTap: () => ref.read(localizationProvider.notifier).setLanguage(AppLanguage.wo),
                  ),
                ],
              ),
            ),

            // Merchant Mode (for business accounts)
            if (user.userType == UserType.company) ...[
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple.shade50, 
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.purple),
                ),
                title: Text(l10n.translate('tab_merchant'), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Gérez vos campagnes de publicité'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                   Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MerchantDashboardScreen()));
                },
              ),
            ],
               
            const SizedBox(height: 32),
            
            // Privacy Legend
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50, 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔒 Légende de visibilité', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildPrivacyLegendItem(Icons.public, 'Public', 'Visible par tout le monde', Colors.green),
                  const SizedBox(height: 8),
                  _buildPrivacyLegendItem(Icons.group, 'Followers', 'Visible uniquement par vos followers mutuels', Colors.blue),
                  const SizedBox(height: 8),
                  _buildPrivacyLegendItem(Icons.lock, 'Privé', 'Invisible pour les autres', Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String title,
    required IconData icon,
    required TextEditingController controller,
    required String value,
    required String placeholder,
    required BioPrivacyLevel privacy,
    required Function(BioPrivacyLevel) onPrivacyChanged,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(title, icon),
            if (_isEditing)
              _buildPrivacyDropdown(privacy, onPrivacyChanged)
            else
              _buildPrivacyBadge(privacy),
          ],
        ),
        const SizedBox(height: 12),
        if (_isEditing)
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50, 
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value.isEmpty ? 'Non renseigné' : value, 
              style: TextStyle(
                fontSize: 14, 
                height: 1.5,
                color: value.isEmpty ? Colors.grey : null,
                fontStyle: value.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrivacyDropdown(BioPrivacyLevel current, Function(BioPrivacyLevel) onChanged) {
    return DropdownButton<BioPrivacyLevel>(
      value: current,
      underline: const SizedBox(),
      items: BioPrivacyLevel.values.map((v) => DropdownMenuItem(
        value: v,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getPrivacyIcon(v), size: 16, color: _getPrivacyColor(v)),
            const SizedBox(width: 4),
            Text(_getPrivacyLabel(v), style: const TextStyle(fontSize: 12)),
          ],
        ),
      )).toList(),
      onChanged: (v) => onChanged(v!),
    );
  }

  Widget _buildPrivacyBadge(BioPrivacyLevel privacy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPrivacyColor(privacy).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPrivacyIcon(privacy), size: 14, color: _getPrivacyColor(privacy)),
          const SizedBox(width: 4),
          Text(
            _getPrivacyLabel(privacy), 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getPrivacyColor(privacy)),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyLegendItem(IconData icon, String title, String description, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
              Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: isDark ? AppTheme.gold : AppTheme.marineBlue, size: 20), 
        const SizedBox(width: 8), 
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
  
  IconData _getPrivacyIcon(BioPrivacyLevel level) {
    switch (level) {
      case BioPrivacyLevel.public: return Icons.public;
      case BioPrivacyLevel.friends: return Icons.group;
      case BioPrivacyLevel.private: return Icons.lock;
    }
  }

  Color _getPrivacyColor(BioPrivacyLevel level) {
    switch (level) {
      case BioPrivacyLevel.public: return Colors.green;
      case BioPrivacyLevel.friends: return Colors.blue;
      case BioPrivacyLevel.private: return Colors.red;
    }
  }

  String _getPrivacyLabel(BioPrivacyLevel level) {
    switch (level) {
      case BioPrivacyLevel.public: return 'Public';
      case BioPrivacyLevel.friends: return 'Followers';
      case BioPrivacyLevel.private: return 'Privé';
    }
  }
}
