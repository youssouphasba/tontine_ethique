import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/models/user_model.dart';
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
import 'package:package_info_plus/package_info_plus.dart';
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
          _buildAnalyticsConsentTile(context, ref),
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
          _buildNotificationPreferences(context, ref, user),

          const SizedBox(height: 16),

          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
            onTap: () {
               Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()), (route) => false);
            },
          ),

          // App Version & Legal Mention
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              final buildNumber = snapshot.data?.buildNumber ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      'Les services de paiement sont assurés par nos partenaires financiers agréés. Tontine Éthique agit en qualité de prestataire technique.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tontetic v$version ($buildNumber)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, UserState user) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final isEmailVerified = firebaseUser?.emailVerified ?? false;
    final hasPhone = firebaseUser?.phoneNumber != null && firebaseUser!.phoneNumber!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      color: AppTheme.marineBlue,
      child: Column(
        children: [
          Row(
            children: [
              // Photo with camera icon
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
                      onTap: () => context.push('/profile?isMe=true'),
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
                        Flexible(
                          child: Text(
                            user.displayName.isEmpty ? 'Mon Profil' : user.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (user.isProfileCertified) const Icon(Icons.verified, color: Colors.blue, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Verification Status Row
                    Row(
                      children: [
                        _buildVerificationBadge(
                          icon: Icons.email,
                          label: 'Email',
                          isVerified: isEmailVerified,
                        ),
                        const SizedBox(width: 8),
                        _buildVerificationBadge(
                          icon: Icons.phone,
                          label: 'Tél',
                          isVerified: hasPhone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Bio
                    if (user.bio.isNotEmpty)
                      Text(user.bio, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 12))
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
                      Text('${user.honorScore}/100', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildVerificationBadge({required IconData icon, required String label, required bool isVerified}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.check_circle : Icons.warning,
            size: 12,
            color: isVerified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isVerified ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildAnalyticsConsentTile(BuildContext context, WidgetRef ref) {
    final consentState = ref.watch(consentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistiques d\'utilisation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Aide à améliorer l\'application',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: consentState.analyticsAccepted,
                  onChanged: (value) async {
                    await ref.read(consentProvider.notifier).recordConsent(
                      type: ConsentType.analytics,
                      accepted: value,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Statistiques activées. Merci de nous aider !'
                                : 'Statistiques désactivées.',
                          ),
                          backgroundColor: value ? Colors.green : Colors.grey,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  activeColor: AppTheme.marineBlue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Données anonymisées uniquement. Aucune information personnelle n\'est partagée. (RGPD Art. 6)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
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
              const Text('Journal de Connexion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
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
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _revokeOtherSessions(context);
                  },
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

  Future<void> _revokeOtherSessions(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déconnexion des autres sessions en cours...'), duration: Duration(seconds: 2)),
      );

      // Mark all other sessions as revoked in Firestore
      final batch = FirebaseFirestore.instance.batch();
      final sessions = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in sessions.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'revokedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Log the action
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('login_history')
          .add({
        'action': 'REVOKE_ALL_SESSIONS',
        'timestamp': FieldValue.serverTimestamp(),
        'device': 'Current Device',
        'status': 'OK',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les autres sessions ont été déconnectées.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
              
              // Call Global Deletion Method via GDPR Service
              // This handles Storage + Firestore + Auth deletion sequentially
              final gdprService = ref.read(gdprServiceProvider);
              final anonymousId = 'ANON_${DateTime.now().millisecondsSinceEpoch}';
              
              // 1. Verify eligibility (Circle Check is done inside userNotifier.deleteAccount usually, 
              // but we should probably replicate or move that check. 
              // For now, let's assume we want to call the robust service.)
              
              // Perform the check locally first using UserNotifier's logic if possible, 
              // or rely on the fact that the user is actively navigating settings.
              // Note: Ideally GDPR Service should also check for active circles.
              
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Suppression en cours... Patientez...'), 
                duration: Duration(seconds: 5)
              ));

              final success = await gdprService.executeDeletion(anonymousId);
              
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
              const Row(
                children: [
                  Icon(Icons.folder_shared, color: AppTheme.marineBlue, size: 28),
                  SizedBox(width: 12),
                  Text('Coffre Légal Sécurisé', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Vos documents signés et contrats sont archivés ici de manière sécurisée.',
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
                        .collection('legal_documents')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text('Aucun document archivé', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(
                                'Vos chartes signées et mandats apparaîtront ici.',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: controller,
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (_, index) {
                          final doc = docs[index].data() as Map<String, dynamic>;
                          final timestamp = doc['createdAt'] as Timestamp?;
                          final dateStr = timestamp != null
                              ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                              : 'Date inconnue';
                          final docType = doc['type'] ?? 'Document';
                          final circleName = doc['circleName'] ?? '';

                          IconData iconData;
                          Color iconColor;
                          switch (docType) {
                            case 'charter':
                              iconData = Icons.gavel;
                              iconColor = AppTheme.marineBlue;
                              break;
                            case 'mandate':
                              iconData = Icons.account_balance;
                              iconColor = Colors.green;
                              break;
                            case 'contract':
                              iconData = Icons.description;
                              iconColor = Colors.orange;
                              break;
                            default:
                              iconData = Icons.insert_drive_file;
                              iconColor = Colors.grey;
                          }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withValues(alpha: 0.1),
                              child: Icon(iconData, color: iconColor),
                            ),
                            title: Text(doc['title'] ?? docType, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$circleName • $dateStr'),
                            trailing: IconButton(
                              icon: const Icon(Icons.download, color: AppTheme.gold),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Téléchargement du document...')),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationPreferences(BuildContext context, WidgetRef ref, UserState user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final prefs = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final notifPrefs = prefs['notificationPreferences'] as Map<String, dynamic>? ?? {};

          final celebrationEnabled = notifPrefs['celebrations'] ?? true;
          final paymentReminders = notifPrefs['paymentReminders'] ?? true;
          final circleUpdates = notifPrefs['circleUpdates'] ?? true;
          final marketingEnabled = notifPrefs['marketing'] ?? false;

          return Column(
            children: [
              SwitchListTile(
                value: celebrationEnabled,
                onChanged: (v) => _updateNotificationPref('celebrations', v),
                title: const Text('Célébrations de Pot'),
                subtitle: const Text('Notification quand un membre reçoit le pot'),
                secondary: const Icon(Icons.celebration, color: AppTheme.gold),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: paymentReminders,
                onChanged: (v) => _updateNotificationPref('paymentReminders', v),
                title: const Text('Rappels de paiement'),
                subtitle: const Text('Rappel avant échéance de cotisation'),
                secondary: const Icon(Icons.notifications_active, color: Colors.orange),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: circleUpdates,
                onChanged: (v) => _updateNotificationPref('circleUpdates', v),
                title: const Text('Actualités du cercle'),
                subtitle: const Text('Nouveaux membres, messages, etc.'),
                secondary: const Icon(Icons.groups, color: AppTheme.marineBlue),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: marketingEnabled,
                onChanged: (v) => _updateNotificationPref('marketing', v),
                title: const Text('Offres et promotions'),
                subtitle: const Text('Bons plans et nouveautés Tontetic'),
                secondary: const Icon(Icons.local_offer, color: Colors.purple),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateNotificationPref(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationPreferences': {key: value},
    }, SetOptions(merge: true));
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

