import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/services/biometric_auth_service.dart';
import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:tontetic/features/auth/presentation/screens/auth_screen.dart';

/// Quick Login Screen
/// Allows fast reconnection via biometrics or PIN
/// 
/// Shows:
/// - User avatar & name
/// - Biometric button (if available)
/// - PIN pad (if enabled)
/// - "Use another account" option

class QuickLoginScreen extends ConsumerStatefulWidget {
  final String? userName;
  final String? userAvatar;

  const QuickLoginScreen({
    super.key,
    this.userName,
    this.userAvatar,
  });

  @override
  ConsumerState<QuickLoginScreen> createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends ConsumerState<QuickLoginScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _failedAttempts = 0;
  bool _showPinPad = false;

  @override
  void initState() {
    super.initState();
    _checkAutoAuth();
  }

  Future<void> _checkAutoAuth() async {
    final status = await ref.read(biometricAuthServiceProvider).getQuickAuthStatus();
    if (status.biometricEnabled && mounted) {
      // Auto-trigger biometric on screen load
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _authenticateWithBiometric();
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(biometricAuthServiceProvider);
    final result = await authService.authenticateWithBiometric();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _onAuthSuccess();
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  void _onPinDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onPinBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);

    final authService = ref.read(biometricAuthServiceProvider);
    final result = await authService.verifyPin(_pin);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _onAuthSuccess();
    } else {
      _failedAttempts++;
      setState(() {
        _pin = '';
        _errorMessage = result.error;
      });

      // Lock after 5 failed attempts
      if (_failedAttempts >= 5) {
        _showLockedDialog();
      }
    }
  }

  void _onAuthSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte verrouillé'),
        content: const Text(
          'Trop de tentatives incorrectes.\n'
          'Veuillez vous reconnecter avec vos identifiants.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _useAnotherAccount();
            },
            child: const Text('Se reconnecter'),
          ),
        ],
      ),
    );
  }

  void _useAnotherAccount() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quickAuthStatus = ref.watch(quickAuthStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.marineBlue,
      body: SafeArea(
        child: quickAuthStatus.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.gold)),
          error: (error, stack) => _buildFullLoginButton(),
          data: (status) => _buildContent(status),
        ),
      ),
    );
  }

  Widget _buildContent(QuickAuthStatus status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          
          // User Avatar
          _buildUserAvatar(),
          const SizedBox(height: 24),
          
          // Welcome message
          Text(
            'Bonjour${widget.userName != null ? ', ${widget.userName}' : ''} 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showPinPad ? 'Entrez votre code PIN' : 'Reconnexion rapide',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
          ),
          
          const SizedBox(height: 48),
          
          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Auth options
          if (_showPinPad)
            _buildPinPad()
          else
            _buildAuthOptions(status),
          
          const Spacer(flex: 2),
          
          // Use another account
          TextButton(
            onPressed: _useAnotherAccount,
            child: Text(
              'Utiliser un autre compte',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse animation for biometric
        if (_isLoading)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5), width: 3),
            ),
          ),
        CircleAvatar(
          radius: 50,
          backgroundColor: AppTheme.gold,
          backgroundImage: widget.userAvatar != null ? NetworkImage(widget.userAvatar!) : null,
          child: widget.userAvatar == null
              ? const Icon(Icons.person, size: 50, color: AppTheme.marineBlue)
              : null,
        ),
        if (_isLoading)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.gold, strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthOptions(QuickAuthStatus status) {
    return Column(
      children: [
        // Biometric button
        if (status.biometricEnabled) ...[
          _buildBiometricButton(status),
          const SizedBox(height: 16),
        ],
        
        // PIN button
        if (status.pinEnabled) ...[
          if (status.biometricEnabled)
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ou', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
          const SizedBox(height: 16),
          _buildPinButton(),
        ],
        
        // If neither is enabled
        if (!status.biometricEnabled && !status.pinEnabled)
          _buildFullLoginButton(),
      ],
    );
  }

  Widget _buildBiometricButton(QuickAuthStatus status) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _authenticateWithBiometric,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.marineBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(status.biometricIcon, size: 28),
        label: Text(
          'Continuer avec ${status.biometricLabel}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPinButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _showPinPad = true),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white54),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.dialpad),
        label: const Text('Utiliser le code PIN', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildPinPad() {
    return Column(
      children: [
        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AppTheme.gold : Colors.transparent,
                border: Border.all(color: AppTheme.gold, width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        
        // Number pad
        ...List.generate(3, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (col) {
              final number = row * 3 + col + 1;
              return _buildPinKey('$number');
            }),
          );
        }),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPinKey('', icon: Icons.arrow_back, onTap: () => setState(() => _showPinPad = false)),
            _buildPinKey('0'),
            _buildPinKey('', icon: Icons.backspace_outlined, onTap: _onPinBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildPinKey(String value, {IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? (value.isNotEmpty ? () => _onPinDigitPressed(value) : null),
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 24)
              : Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFullLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _useAnotherAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.marineBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
