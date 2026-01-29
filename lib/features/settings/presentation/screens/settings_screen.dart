import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/notifications/celebration_notification.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/services/auth_service.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:tontetic/features/settings/presentation/screens/help_screen.dart';
// import 'package:tontetic/features/admin/presentation/screens/super_admin_screen.dart'; - UNUSED
// import 'package:tontetic/features/admin/presentation/screens/arbitration_dashboard_screen.dart'; - UNUSED
// import 'package:tontetic/features/admin/presentation/screens/security_alerts_panel.dart'; - UNUSED
// import 'package:tontetic/features/admin/presentation/screens/report_archive_screen.dart'; - UNUSED
import 'package:tontetic/features/chat/presentation/screens/support_chat_screen.dart';
import 'package:tontetic/features/settings/presentation/screens/legal_documents_screen.dart';
// import 'package:tontetic/features/security/presentation/screens/liveness_check_screen.dart'; // V4.0 - Removed by user request
import 'package:tontetic/features/subscription/presentation/screens/subscription_selection_screen.dart'; // V4.1
import 'package:tontetic/features/corporate/presentation/screens/corporate_dashboard_screen.dart'; // V9.7 RH
// import 'package:tontetic/core/services/notification_service.dart'; // V10.1 Notifications - UNUSED
import 'package:tontetic/core/providers/localization_provider.dart';
import 'package:tontetic/features/legal/presentation/screens/legal_wolof_screen.dart';
import 'package:tontetic/core/services/gdpr_service.dart';
import 'package:tontetic/core/providers/consent_provider.dart';
import 'package:tontetic/core/providers/context_provider.dart';
import 'package:tontetic/core/providers/merchant_account_provider.dart';
import 'package:tontetic/features/advertising/presentation/screens/merchant_registration_screen.dart';
import 'package:tontetic/features/merchant/presentation/screens/merchant_dashboard_screen.dart';
// import 'package:tontetic/features/admin/presentation/screens/admin_dashboard.dart'; - UNUSED
import 'package:tontetic/core/providers/theme_provider.dart';
import 'package:tontetic/features/settings/presentation/screens/security_settings_screen.dart';
import 'dart:developer' as dev;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final notifier = ref.read(userProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres & Profil'),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: ListView(
        children: [
          // Header Profil & Score
          _buildProfileHeader(context, ref, user),

          // V4.1 - Mon Abonnement
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: AppTheme.gold.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.star, color: AppTheme.gold),
                title: Text(
                  'Mon Abonnement', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
                  ),
                ),
                subtitle: Text(
                  'Plan actuel: ${user.subscriptionTier.toUpperCase()}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionSelectionScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('GÉRER'),
                ),
              ),
            ),
          ),

          // V9.7 - Espace RH / Entreprise (Only for Business Accounts)
          if (user.userType == UserType.company)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                color: Colors.indigo.withValues(alpha: 0.1),
                child: ListTile(
                  leading: const Icon(Icons.business, color: Colors.indigo),
                  title: const Text('Espace RH / Entreprise', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: const Text('Gérer les tontines de vos salariés'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CorporateDashboardScreen())),
                ),
              ),
            ),

          // ===== CONTEXT SWITCH (Personal ↔ Enterprise) =====
          _buildContextSwitchSection(context, ref, user),

          _buildMerchantSection(context, ref),

          _buildSectionHeader('Langue & Région'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Language Selection
                ListTile(
                  leading: const Icon(Icons.language, color: AppTheme.marineBlue),
                  title: const Text('Langue de l\'application'),
                  trailing: DropdownButton<AppLanguage>(
                    value: ref.watch(localizationProvider).language,
                    onChanged: (lang) {
                      if (lang != null) ref.read(localizationProvider.notifier).setLanguage(lang);
                    },
                    items: const [
                      DropdownMenuItem(value: AppLanguage.fr, child: Text('Français')),
                      DropdownMenuItem(value: AppLanguage.wo, child: Text('Wolof (Sénégal)')),
                    ],
                  ),
                ),
                const Divider(),
                // ignore: deprecated_member_use
                RadioListTile<UserZone>(
                  title: const Text('Zone Euro (€) - SEPA/CB'),
                  value: UserZone.zoneEuro,
                  // ignore: deprecated_member_use
                  groupValue: user.zone,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) notifier.switchZone(val);
                  },
                ),
                // ignore: deprecated_member_use
                RadioListTile<UserZone>(
                  title: const Text('Zone FCFA - Mobile Money (Wave/OM)'),
                  value: UserZone.zoneFCFA,
                  // ignore: deprecated_member_use
                  groupValue: user.zone,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) notifier.switchZone(val);
                  },
                ),
              ],
            ),
          ),

          // ===== APPARENCE / THEME =====
          _buildSectionHeader('Apparence'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        ref.watch(themeModeProvider) == ThemeMode.dark 
                            ? Icons.dark_mode 
                            : ref.watch(themeModeProvider) == ThemeMode.light 
                                ? Icons.light_mode 
                                : Icons.brightness_auto,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppTheme.gold 
                            : AppTheme.marineBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Thème',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildThemeOption(
                          context, ref,
                          icon: Icons.light_mode,
                          label: 'Clair',
                          mode: ThemeMode.light,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeOption(
                          context, ref,
                          icon: Icons.dark_mode,
                          label: 'Sombre',
                          mode: ThemeMode.dark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeOption(
                          context, ref,
                          icon: Icons.brightness_auto,
                          label: 'Auto',
                          mode: ThemeMode.system,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ===== SÉCURITÉ & CONNEXION =====
          _buildSectionHeader('Sécurité & Connexion'),
          _buildTile(
            context,
            icon: Icons.security,
            title: 'Sécurité du compte',
            subtitle: 'Mot de passe, empreinte, Face ID, code PIN',
            color: Colors.red,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
          ),
          _buildTile(
            context,
            icon: Icons.delete_forever,
            title: 'Supprimer mon compte',
            subtitle: 'Action irréversible (RGPD)',
            onTap: () => _confirmDeletion(context, ref),
            color: Colors.red,
          ),

// ... (in build)
          _buildSectionHeader('Aide & Support'),
          _buildTile(
            context,
            icon: Icons.gavel,
            title: 'Conditions Générales & Légales',
            subtitle: 'CGU, RGPD, Mentions',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalDocumentsScreen())),
          ),
          _buildTile(
            context,
            icon: Icons.translate,
            title: 'Sartu Tontetic (Wolof)',
            subtitle: 'Règles simplifiées en Wolof',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalWolofScreen())),
          ),
          _buildTile(
            context,
            icon: Icons.support_agent,
            title: 'Contacter le Support',
            subtitle: 'Discussion directe avec un agent',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen())),
          ),
          _buildTile(
            context,
            icon: Icons.help_outline,
            title: 'Tutoriels',
            subtitle: 'Comprendre le modèle éthique',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),

          _buildSectionHeader('Piliers de Confiance'),
          _buildTechPillar(
             context,
             icon: Icons.security,
             title: 'Sécurité des Données (RGPD)',
             desc: 'Vos données sont cryptées et protégées selon les normes européennes.',
             videoDuration: '0:30',
          ),
          _buildTechPillar(
             context,
             icon: Icons.shield,
             title: 'Garantie Solidaire',
             desc: 'Mécanisme de protection communautaire en cas de défaillance.',
             videoDuration: '0:45',
          ),
          _buildTechPillar(
             context,
             icon: Icons.draw,
             title: 'Signature Numérique',
             desc: 'Valeur légale probante de votre engagement sur mobile.',
             videoDuration: '0:25',
          ),
          
          // RGPD Section
          _buildSectionHeader('Vos Données (RGPD)'),
          _buildTile(
            context,
            icon: Icons.download,
            title: 'Exporter mes données',
            subtitle: 'Télécharger toutes vos données (Art.20)',
            onTap: () => _showExportDataDialog(context, ref),
          ),
          _buildTile(
            context,
            icon: Icons.history,
            title: 'Historique des consentements',
            subtitle: 'CGU, Newsletter, Cookies...',
            onTap: () => _showConsentHistory(context, ref),
          ),

          _buildSectionHeader('Sécurité & Documents'),
          _buildTile(
            context,
            icon: Icons.folder_shared,
            title: 'Coffre à Documents',
            subtitle: 'Mandats, Contrats, Règlements',
            onTap: () => _showLegalVault(context),
          ),
          _buildTile(
            context,
            icon: Icons.history_edu,
            title: 'Journal de Connexion',
            subtitle: 'Dernières activités (IP, Appareil)',
            onTap: () => _showConnectionLogs(context),
          ),

          // V15: Administration removed - admins use Firebase web back-office (admin.tontetic.com)

          _buildSectionHeader('Notifications'),
           SwitchListTile(
            value: true, 
            onChanged: (v) {
                if(v) CelebrationNotification.show(context, "Membre");
            },
            title: const Text('Célébrations de Pot 🎉'),
            subtitle: const Text('Test des notifications'),
          ),

          const SizedBox(height: 16),
          
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
            onTap: () {
               Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()), (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, UserState user) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppTheme.marineBlue,
      child: Column(
        children: [
          Row(
            children: [
              // Photo V2
               Stack(
                 children: [
                   CircleAvatar(
                     radius: 36, 
                     backgroundColor: AppTheme.gold, 
                     backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                     child: user.photoUrl == null ? const Icon(Icons.person, size: 36, color: AppTheme.marineBlue) : null
                   ),
                   Positioned(
                     bottom: 0, right: 0,
                     child: InkWell(
                       onTap: () {
                          // REAL: Navigate to profile screen for photo upload
                          context.push('/profile');
                       },
                       child: const CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 14)),
                     ),
                   )
                 ],
               ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(user.displayName.isEmpty ? 'Membre Tontetic' : user.displayName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (user.isProfileCertified) const Icon(Icons.verified, color: Colors.blue, size: 20),
                      ],
                    ),
                    // Bio V3.5
                    if (user.bio.isNotEmpty)
                      Text(user.bio, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic))
                    else
                      InkWell(
                        onTap: () => _showEditBioDialog(context, ref),
                        child: const Text('Ajouter une bio +', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showScoreHistory(context, user),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text('Score d\'Honneur', style: TextStyle(color: AppTheme.gold, fontSize: 10)),
                      Text('${user.honorScore}/100', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('Historique >', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  void _showEditBioDialog(BuildContext context, WidgetRef ref) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ma Biographie'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Ex: Entrepreneur passionné...')),
        actions: [
          TextButton(onPressed: () { 
            ref.read(userProvider.notifier).updateExtendedProfile(bio: c.text); 
            Navigator.pop(ctx); 
          }, child: const Text('Enregistrer'))
        ],
      )
    );
  }

  void _showScoreHistory(BuildContext context, UserState user) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Historique de Confiance ⭐️', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...user.trustScoreHistory.map((e) => ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(e),
              trailing: const Text('31 Dec', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ))
          ],
        ),
      )
    );
  }

  Widget _buildSectionHeader(String title, {Color color = AppTheme.gold}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Widget _buildTechPillar(BuildContext context, {required IconData icon, required String title, required String desc, required String videoDuration}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.marineBlue),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
             const SizedBox(height: 12),
             InkWell(
               onTap: () {
                 showDialog(
                   context: context, 
                   builder: (c) => AlertDialog(
                     content: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Icon(Icons.play_circle_fill, size: 64, color: AppTheme.marineBlue),
                         const SizedBox(height: 16),
                         Text('Lecture de la vidéo : $title'),
                         const SizedBox(height: 8),
                         const Text('(Simulation Vidéo Player)'),
                       ],
                     ),
                     actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))],
                   )
                 );
               },
               child: Container(
                 padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                 decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     const Icon(Icons.play_circle, size: 20, color: Colors.red),
                     const SizedBox(width: 8),
                     Text('Voir la vidéo explicative ($videoDuration)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                   ],
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, {required IconData icon, required String title, String? subtitle, VoidCallback? onTap, Color color = AppTheme.gold}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])) : null,
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black45),
      onTap: onTap,
    );
  }

  void _showConnectionLogs(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Journal de Connexion 🕵️‍♂️', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
              const SizedBox(height: 8),
              const Text(
                'Vérifiez régulièrement cette liste pour détecter tout accès suspect. Si vous ne reconnaissez pas une activité, changez immédiatement votre code.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: user == null 
                  ? const Center(child: Text('Non connecté'))
                  : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('login_history')
                        .orderBy('timestamp', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final logs = snapshot.data?.docs ?? [];
                      
                      if (logs.isEmpty) {
                        return const Center(
                          child: Text('Aucun historique de connexion disponible.', 
                            style: TextStyle(color: Colors.grey)),
                        );
                      }
                      
                      return ListView.separated(
                        controller: controller,
                        itemCount: logs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (_, index) {
                          final log = logs[index].data() as Map<String, dynamic>;
                          final isFail = (log['status'] ?? '').toString().contains('ÉCHEC') || 
                                         (log['status'] ?? '').toString().contains('failed');
                          final timestamp = log['timestamp'] as Timestamp?;
                          final dateStr = timestamp != null 
                              ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                              : 'Date inconnue';
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isFail ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                              child: Icon(isFail ? Icons.warning : Icons.check_circle, color: isFail ? Colors.red : Colors.green),
                            ),
                            title: Text('$dateStr • ${log['device'] ?? 'Appareil inconnu'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('IP: ${log['ip'] ?? 'N/A'}'),
                            trailing: Text(
                              log['status'] ?? 'OK', 
                              style: TextStyle(color: isFail ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déconnexion de toutes les autres sessions...'))); },
                  icon: const Icon(Icons.logout, color: Colors.orange),
                  label: const Text('Déconnecter les autres appareils', style: TextStyle(color: Colors.orange)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletion(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Suppression définitive'),
        content: const Text(
          "Êtes-vous sûr de vouloir supprimer votre compte ?\n\n"
          "Cette action est irréversible. Toutes vos données seront effacées, sauf les traces légales de transaction."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Call Global Deletion Method
              final authService = ref.read(authServiceProvider);
              final success = await ref.read(userProvider.notifier).deleteAccount(authService);
              
              if (success) {
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()), (route) => false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte supprimé avec succès. Au revoir !')));
                }
              } else {
                if (context.mounted) {
                  _showDeletionError(context);
                }
              }
            },
            child: const Text('SUPPRIMER', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  void _showDeletionError(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: const Text('Suppression Impossible'),
        content: const Text(
          "Sécurité Tontine : Vous ne pouvez pas supprimer votre compte car vous êtes engagé dans un cercle actif.\n\n"
          "Pour protéger les autres membres, vous devez terminer le cycle ou trouver un remplaçant avant de partir."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Compris'))
        ],
      ),
    );
  }
  void _showLegalVault(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📁 Coffre Légal Sécurisé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Aucun document archivé.', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('FERMER')),
        ],
      ),
    );
  }



  // =========== RGPD DIALOGS ===========

  void _showExportDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📥 Exporter mes données'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conformément à l\'Article 20 du RGPD, vous pouvez télécharger toutes vos données personnelles.'),
            const SizedBox(height: 16),
            const Text('Le fichier contiendra :', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Informations de profil'),
            const Text('• Historique des cercles'),
            const Text('• Transactions'),
            const Text('• Consentements'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANNULER')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final gdpr = ref.read(gdprServiceProvider);
              final json = await gdpr.exportToJson();
              dev.log('Export RGPD: $json');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Données exportées ! Vérifiez vos téléchargements.'), backgroundColor: Colors.green),
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('TÉLÉCHARGER (JSON)'),
          ),
        ],
      ),
    );
  }

  void _showConsentHistory(BuildContext context, WidgetRef ref) {
    final consents = ref.read(consentProvider).consents;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📋 Historique des Consentements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('(RGPD Article 7)', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            if (consents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun consentement enregistré.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...consents.map((c) => ListTile(
                title: Text(c.type.name.toUpperCase()),
                subtitle: Text('${c.timestamp.toString().split('.')[0]} • IP: ${c.ipAddress}'),
              )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('FERMER'),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ===== CONTEXT SWITCH SECTION =====
  Widget _buildContextSwitchSection(BuildContext context, WidgetRef ref, UserState user) {
    final contextState = ref.watch(contextProvider);
    
    // Only show if user is linked to a company (employee)
    if (!contextState.isEmployee) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.blue.withValues(alpha: 0.1),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                contextState.currentContext == UserContext.enterprise ? Icons.business : Icons.person,
                color: contextState.currentContext == UserContext.enterprise ? Colors.indigo : Colors.blue,
              ),
              title: Text(
                'Profil actif : ${contextState.currentContext == UserContext.enterprise ? "Entreprise" : "Personnel"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(contextState.currentContext == UserContext.enterprise 
                ? 'Vous voyez les tontines entreprise'
                : 'Vous voyez vos tontines personnelles'),
              trailing: Switch(
                value: contextState.currentContext == UserContext.enterprise,
                activeThumbColor: Colors.indigo,
                onChanged: (value) {
                  if (value && contextState.employeeLinks.isNotEmpty) {
                    ref.read(contextProvider.notifier).switchToEnterprise(contextState.employeeLinks.first.companyId);
                  } else {
                    ref.read(contextProvider.notifier).switchToPersonal();
                  }
                },
              ),
            ),
            if (contextState.employeeLinks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lié à : ${contextState.employeeLinks.map((c) => c.companyName).join(", ")}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== MERCHANT SECTION =====
  Widget _buildMerchantSection(BuildContext context, WidgetRef ref) {
    final merchantState = ref.watch(merchantAccountProvider);
    final hasMerchantAccount = merchantState.hasMerchantAccount;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.store, color: Colors.deepPurple),
              title: Text(
                hasMerchantAccount ? 'Ma Boutique Marchand' : 'Devenir Marchand',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              subtitle: Text(hasMerchantAccount 
                ? merchantState.shop?.shopName ?? 'Accéder au dashboard'
                : 'Vendez vos produits sur la plateforme'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasMerchantAccount ? Colors.green : Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasMerchantAccount ? 'ACTIF' : 'NOUVEAU',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              onTap: () {
                if (hasMerchantAccount) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantDashboardScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantRegistrationScreen()));
                }
              },
            ),
            if (hasMerchantAccount && merchantState.isMerchantMode)
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Mode Marchand actif', style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build theme option button for the theme toggle
  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required ThemeMode mode,
  }) {
    final currentMode = ref.watch(themeModeProvider);
    final isSelected = currentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.gold.withValues(alpha: 0.2) : AppTheme.marineBlue.withValues(alpha: 0.1))
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.gold : AppTheme.marineBlue)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isDark ? AppTheme.gold : AppTheme.marineBlue)
                  : (isDark ? Colors.white54 : Colors.black54),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? AppTheme.gold : AppTheme.marineBlue)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

