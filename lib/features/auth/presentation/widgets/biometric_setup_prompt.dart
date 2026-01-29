import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/biometric_auth_service.dart';
import 'package:tontetic/features/settings/presentation/screens/security_settings_screen.dart';

/// Biometric Setup Prompt
/// Shows a bottom sheet or dialog after first login to propose biometric/PIN setup
/// 
/// Features:
/// - Shows available biometric options (fingerprint/Face ID)
/// - "Activer maintenant" button
/// - "Plus tard" option
/// - "Ne plus me demander" checkbox

class BiometricSetupPrompt {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyPromptShown = 'biometric_prompt_shown';
  static const String _keyPromptDismissed = 'biometric_prompt_dismissed';

  /// Check if we should show the prompt
  static Future<bool> shouldShowPrompt() async {
    // Check if user already dismissed permanently
    final dismissed = await _storage.read(key: _keyPromptDismissed);
    if (dismissed == 'true') return false;

    // Check if biometric is already enabled
    final authService = BiometricAuthService();
    final status = await authService.getQuickAuthStatus();
    if (status.biometricEnabled || status.pinEnabled) return false;

    return true;
  }

  /// Mark prompt as permanently dismissed
  static Future<void> dismissPermanently() async {
    await _storage.write(key: _keyPromptDismissed, value: 'true');
  }

  /// Reset prompt (for testing or after logout)
  static Future<void> resetPrompt() async {
    await _storage.delete(key: _keyPromptShown);
    await _storage.delete(key: _keyPromptDismissed);
  }

  /// Show the biometric setup prompt
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    if (!await shouldShowPrompt()) return;

    // Wait a moment for the dashboard to fully load
    await Future.delayed(const Duration(milliseconds: 800));

    if (!context.mounted) return;

    final authService = ref.read(biometricAuthServiceProvider);
    final status = await authService.getQuickAuthStatus();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BiometricSetupSheet(
        status: status,
        onActivate: () async {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
          );
        },
        onLater: () => Navigator.pop(ctx),
        onNeverAsk: () async {
          await dismissPermanently();
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _BiometricSetupSheet extends StatefulWidget {
  final QuickAuthStatus status;
  final VoidCallback onActivate;
  final VoidCallback onLater;
  final VoidCallback onNeverAsk;

  const _BiometricSetupSheet({
    required this.status,
    required this.onActivate,
    required this.onLater,
    required this.onNeverAsk,
  });

  @override
  State<_BiometricSetupSheet> createState() => _BiometricSetupSheetState();
}

class _BiometricSetupSheetState extends State<_BiometricSetupSheet> {
  bool _neverAskAgain = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.status.hasFaceId
                    ? Icons.face
                    : widget.status.hasFingerprint
                        ? Icons.fingerprint
                        : Icons.security,
                size: 48,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Connexion rapide',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.marineBlue,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              _getDescription(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Benefits list
            _buildBenefitsList(),
            const SizedBox(height: 24),

            // Activate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.marineBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.lock_open),
                label: const Text(
                  'Activer maintenant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Later button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _neverAskAgain ? widget.onNeverAsk : widget.onLater,
                child: Text(
                  'Plus tard',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),

            // Never ask checkbox
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _neverAskAgain,
                  onChanged: (v) => setState(() => _neverAskAgain = v ?? false),
                  activeColor: AppTheme.marineBlue,
                ),
                GestureDetector(
                  onTap: () => setState(() => _neverAskAgain = !_neverAskAgain),
                  child: Text(
                    'Ne plus me demander',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getDescription() {
    if (widget.status.hasFaceId) {
      return 'Activez Face ID pour vous reconnecter en un instant, sans retaper vos identifiants.';
    }
    if (widget.status.hasFingerprint) {
      return 'Activez l\'empreinte digitale pour vous reconnecter en un instant, sans retaper vos identifiants.';
    }
    return 'Configurez un code PIN à 4 chiffres pour vous reconnecter rapidement.';
  }

  Widget _buildBenefitsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildBenefitRow(Icons.speed, 'Connexion instantanée'),
          const SizedBox(height: 12),
          _buildBenefitRow(Icons.shield, 'Plus sécurisé qu\'un mot de passe'),
          const SizedBox(height: 12),
          _buildBenefitRow(Icons.privacy_tip, 'Données stockées localement'),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.green, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Alternative: Inline banner for dashboard
class BiometricSetupBanner extends ConsumerStatefulWidget {
  const BiometricSetupBanner({super.key});

  @override
  ConsumerState<BiometricSetupBanner> createState() => _BiometricSetupBannerState();
}

class _BiometricSetupBannerState extends ConsumerState<BiometricSetupBanner> {
  bool _visible = false;
  QuickAuthStatus? _status;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    final shouldShow = await BiometricSetupPrompt.shouldShowPrompt();
    if (shouldShow) {
      final authService = ref.read(biometricAuthServiceProvider);
      final status = await authService.getQuickAuthStatus();
      if (mounted) {
        setState(() {
          _visible = true;
          _status = status;
        });
      }
    }
  }

  void _dismiss() {
    setState(() => _visible = false);
  }

  void _dismissPermanently() async {
    await BiometricSetupPrompt.dismissPermanently();
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _status == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.marineBlue, AppTheme.marineBlue.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.marineBlue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _status!.hasFaceId ? Icons.face : Icons.fingerprint,
                  color: AppTheme.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connexion rapide disponible',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activez ${_status!.biometricLabel} pour vous reconnecter instantanément',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.marineBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Activer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _dismissPermanently,
                child: Text(
                  'Plus tard',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
