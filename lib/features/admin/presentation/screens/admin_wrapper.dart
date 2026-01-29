import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';

import 'package:tontetic/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:tontetic/features/admin/presentation/screens/super_admin_screen.dart';

/// Admin Wrapper - PRODUCTION VERSION
/// Implements RBAC by checking user role in Firestore before granting access
class AdminWrapper extends ConsumerWidget {
  const AdminWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const AdminLoginScreen();
        }
        
        // RBAC: Check admin role in Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: AppTheme.marineBlue,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.gold),
                      SizedBox(height: 16),
                      Text('Vérification des permissions...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildUnauthorizedScreen('Erreur de vérification: ${snapshot.error}');
            }

            final userData = snapshot.data?.data() as Map<String, dynamic>?;
            final role = userData?['role'] as String?;

            // Check if user has admin role
            final allowedRoles = ['superAdmin', 'admin', 'support', 'moderation'];
            if (role == null || !allowedRoles.contains(role)) {
              return _buildUnauthorizedScreen('Accès refusé. Rôle requis: admin');
            }

            // Access granted - show admin dashboard
            return const SuperAdminScreen();
          },
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Erreur: $err'))),
    );
  }

  Widget _buildUnauthorizedScreen(String message) {
    return Scaffold(
      backgroundColor: AppTheme.marineBlue,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Accès Non Autorisé',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Contactez un administrateur pour obtenir les droits d\'accès.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
