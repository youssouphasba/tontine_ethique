import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/biometric_auth_service.dart';

import 'package:tontetic/core/providers/auth_provider.dart';

/// Security Settings Screen
/// Allows users to configure biometric and PIN authentication
/// 
/// Features:
/// - Enable/disable biometric auth
/// - Set up/change/remove PIN
/// - View security status

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  bool _biometricAvailable = false;
  String _biometricLabel = 'Biométrie';
  IconData _biometricIcon = Icons.fingerprint;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final authService = ref.read(biometricAuthServiceProvider);
    final status = await authService.getQuickAuthStatus();

    if (mounted) {
      setState(() {
        _biometricEnabled = status.biometricEnabled;
        _pinEnabled = status.pinEnabled;
        _biometricAvailable = status.availableBiometrics.isNotEmpty;
        _biometricLabel = status.biometricLabel;
        _biometricIcon = status.biometricIcon;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final authService = ref.read(biometricAuthServiceProvider);

    if (value) {
      // First verify biometric works
      final result = await authService.authenticateWithBiometric(
        reason: 'Vérifiez votre identité pour activer la biométrie',
      );
      if (result.success) {
        await authService.enableBiometric();
        setState(() => _biometricEnabled = true);
        _showSnackBar('$_biometricLabel activé ✅');
      } else {
        _showSnackBar(result.error ?? 'Échec de l\'activation', isError: true);
      }
    } else {
      await authService.disableBiometric();
      setState(() => _biometricEnabled = false);
      _showSnackBar('$_biometricLabel désactivé');
    }
  }

  Future<void> _setupPin() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PinSetupDialog(),
    );

    if (result != null && result.isNotEmpty) {
      final authService = ref.read(biometricAuthServiceProvider);
      final success = await authService.setupPin(result);
      if (success) {
        setState(() => _pinEnabled = true);
        _showSnackBar('Code PIN configuré ✅');
      } else {
        _showSnackBar('Erreur de configuration', isError: true);
      }
    }
  }

  Future<void> _changePin() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PinChangeDialog(),
    );

    if (result != null) {
      final authService = ref.read(biometricAuthServiceProvider);
      final success = await authService.changePin(result['old']!, result['new']!);
      if (success) {
        _showSnackBar('Code PIN modifié ✅');
      } else {
        _showSnackBar('Ancien code incorrect', isError: true);
      }
    }
  }

  Future<void> _removePin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le code PIN ?'),
        content: const Text('Vous ne pourrez plus vous reconnecter rapidement avec un code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService = ref.read(biometricAuthServiceProvider);
      await authService.disablePin();
      setState(() => _pinEnabled = false);
      _showSnackBar('Code PIN supprimé');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité & Connexion'),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildPasswordSection(),
                const SizedBox(height: 16),
                _buildBiometricSection(),
                const SizedBox(height: 16),
                _buildPinSection(),
                const SizedBox(height: 24),
                _buildSecurityTips(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final isSecure = _biometricEnabled || _pinEnabled;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSecure
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.orange.shade700, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isSecure ? Icons.shield : Icons.warning_amber,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSecure ? 'Compte sécurisé' : 'Connexion rapide désactivée',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSecure
                      ? 'Reconnexion rapide activée'
                      : 'Activez la biométrie ou le PIN',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: Colors.red),
            ),
            title: const Text('Mot de passe'),
            subtitle: const Text('Modifier votre mot de passe de connexion'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null) ...[
                  Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final current = currentPasswordController.text;
                final newPass = newPasswordController.text;
                final confirm = confirmPasswordController.text;

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  setDialogState(() => errorMessage = 'Remplissez tous les champs');
                  return;
                }
                if (newPass.length < 6) {
                  setDialogState(() => errorMessage = 'Le mot de passe doit contenir au moins 6 caractères');
                  return;
                }
                if (newPass != confirm) {
                  setDialogState(() => errorMessage = 'Les mots de passe ne correspondent pas');
                  return;
                }

                setDialogState(() {
                  isLoading = true;
                  errorMessage = null;
                });

                try {
                  final authService = ref.read(authServiceProvider);
                  final result = await authService.changePassword(
                    currentPassword: current,
                    newPassword: newPass,
                  );

                  if (!context.mounted) return;

                  if (result.success) {
                    Navigator.pop(ctx);
                    _showSnackBar('Mot de passe modifié avec succès ✅');
                  } else {
                    setDialogState(() {
                      isLoading = false;
                      errorMessage = result.error ?? 'Erreur inconnue';
                    });
                  }
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                    errorMessage = 'Erreur: $e';
                  });
                }
              },
              child: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Modifier'),
            ),
          ],
        ),
      ),
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Widget _buildBiometricSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.marineBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_biometricIcon, color: AppTheme.marineBlue),
            ),
            title: Text(_biometricLabel),
            subtitle: Text(
              _biometricAvailable
                  ? 'Reconnexion rapide avec votre empreinte ou visage'
                  : 'Non disponible sur cet appareil',
            ),
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: _biometricAvailable ? _toggleBiometric : null,
              thumbColor: const WidgetStatePropertyAll(AppTheme.gold),
            ),
          ),
          if (!_biometricAvailable)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configurez une empreinte ou Face ID dans les paramètres de votre téléphone.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dialpad, color: AppTheme.gold),
            ),
            title: const Text('Code PIN'),
            subtitle: Text(
              _pinEnabled
                  ? 'Code à 4 chiffres configuré'
                  : 'Configurer un code de reconnexion rapide',
            ),
            trailing: _pinEnabled
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.add_circle_outline, color: Colors.grey),
            onTap: _pinEnabled ? null : _setupPin,
          ),
          if (_pinEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _changePin,
                      child: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _removePin,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Conseils de sécurité',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip('Activez la biométrie pour une connexion plus rapide et sécurisée'),
          _buildTip('N\'utilisez pas un code PIN évident (1234, 0000, date de naissance)'),
          _buildTip('Votre code PIN est stocké de manière chiffrée'),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.blue)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// =============== PIN SETUP DIALOG ===============

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _error;

  void _onDigit(String digit) {
    setState(() {
      _error = null;
      if (_isConfirming) {
        if (_confirmPin.length < 4) _confirmPin += digit;
        if (_confirmPin.length == 4) _validateAndSubmit();
      } else {
        if (_pin.length < 4) _pin += digit;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _isConfirming = true);
          });
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  void _validateAndSubmit() {
    if (_pin == _confirmPin) {
      Navigator.pop(context, _pin);
    } else {
      setState(() {
        _error = 'Les codes ne correspondent pas';
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isConfirming ? 'Confirmer le code' : 'Nouveau code PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          _buildPinDots(_isConfirming ? _confirmPin : _pin),
          const SizedBox(height: 24),
          _buildMiniPinPad(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  Widget _buildPinDots(String currentPin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < currentPin.length ? AppTheme.marineBlue : Colors.transparent,
            border: Border.all(color: AppTheme.marineBlue, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildMiniPinPad() {
    return Column(
      children: [
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int col = 0; col < 3; col++)
                _buildKey('${row * 3 + col + 1}'),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 50),
            _buildKey('0'),
            _buildKey('⌫', onTap: _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String value, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap ?? () => _onDigit(value),
      child: Container(
        margin: const EdgeInsets.all(4),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}

// =============== PIN CHANGE DIALOG ===============

class _PinChangeDialog extends StatefulWidget {
  const _PinChangeDialog();

  @override
  State<_PinChangeDialog> createState() => _PinChangeDialogState();
}

class _PinChangeDialogState extends State<_PinChangeDialog> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final oldPin = _oldController.text;
    final newPin = _newController.text;
    final confirm = _confirmController.text;

    if (oldPin.length != 4 || newPin.length != 4) {
      setState(() => _error = 'Le code doit contenir 4 chiffres');
      return;
    }
    if (newPin != confirm) {
      setState(() => _error = 'Les nouveaux codes ne correspondent pas');
      return;
    }

    Navigator.pop(context, {'old': oldPin, 'new': newPin});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le code PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _oldController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Ancien code'),
          ),
          TextField(
            controller: _newController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Nouveau code'),
          ),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Confirmer'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Modifier'),
        ),
      ],
    );
  }
}
