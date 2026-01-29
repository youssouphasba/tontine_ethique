import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

import 'package:tontetic/features/auth/presentation/screens/type_selection_screen.dart';
import 'package:tontetic/features/auth/presentation/screens/individual_registration_screen.dart';
import 'package:tontetic/features/dashboard/presentation/screens/dashboard_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _selectedCountryCode = '+33';

  bool _isLoading = false;
  bool _awaitingOtp = false;
  String? _errorMessage;

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Navigate to Dashboard and clear all previous routes
      debugPrint('DEBUG_AUTH: Email Sign-In successful! Navigating to Dashboard...');
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          context.go('/');
        }
      }
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        // Check if new user needs onboarding
        if (result.isNewUser) {
          debugPrint('DEBUG_AUTH: New Google user! Redirecting to registration...');
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const IndividualRegistrationScreen(
                skipEmailStep: true, // Email already provided by Google
              )),
              (route) => false,
            );
          }
        } else {
          // Existing user - Navigate to Dashboard
          debugPrint('DEBUG_AUTH: Existing Google user! Navigating to Dashboard...');
          if (mounted) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            } else {
              context.go('/');
            }
          }
        }
      } else {
        // Show error to user (including cancelled)
        debugPrint('DEBUG_AUTH: Google Sign-In failed: ${result.error}');
        if (result.error != 'Connexion annulée') {
          setState(() => _errorMessage = result.error ?? 'Erreur inconnue');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur Google: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('DEBUG_AUTH: Exception in _handleGoogleLogin: $e');
      setState(() => _errorMessage = 'Erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exception: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handlePhoneLogin() async {
    final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
    
    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre numéro');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithPhone(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _awaitingOtp = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Code envoyé')),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = '$_selectedCountryCode${_phoneController.text.trim()}';
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Code invalide');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.verifyOtp(phone: phone, token: otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Set user phone and automatically detect zone
      ref.read(userProvider.notifier).setUser(phone, false);

      // Navigate to Dashboard and clear all previous routes
      debugPrint('DEBUG_AUTH: OTP verification successful! Navigating to Dashboard...');
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          context.go('/');
        }
      }
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Entrez votre email d\'abord');
      return;
    }

    setState(() => _isLoading = true);
    
    final authService = ref.read(authServiceProvider);
    final result = await authService.resetPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success 
          ? 'Email de réinitialisation envoyé' 
          : result.error ?? 'Erreur'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.marineBlue,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        const Icon(Icons.lock_outline, size: 60, color: AppTheme.gold),
                        const SizedBox(height: 24),
                        Text(
                          'Connexion',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 32),

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
                          const SizedBox(height: 16),
                        ],

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            indicator: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: AppTheme.marineBlue,
                            unselectedLabelColor: Colors.white70,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Email'),
                              Tab(text: 'Téléphone'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // TabBarView with fixed height to avoid overflow
                        SizedBox(
                          height: 280, // Fixed height for form content
                          child: TabBarView(
                            children: [
                              SingleChildScrollView(child: _buildEmailForm()),
                              SingleChildScrollView(child: _buildPhoneForm()),
                            ],
                          ),
                        ),

                        const Spacer(),
                        _buildBottomLinks(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Adresse Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _passwordController,
          label: 'Mot de passe',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        _buildLoginButton(onPressed: _handleEmailLogin),
        const SizedBox(height: 16),
        _buildGoogleButton(),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleLogin,
        icon: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
          height: 24,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white),
        ),
        label: const Text('Continuer avec Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white30),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    if (_awaitingOtp) {
      return Column(
        children: [
          const Text(
            'Entrez le code reçu par SMS',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _otpController,
            label: 'Code à 6 chiffres',
            icon: Icons.pin,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          _buildLoginButton(onPressed: _verifyOtp, label: 'Vérifier'),
          TextButton(
            onPressed: () => setState(() => _awaitingOtp = false),
            child: const Text('Changer de numéro', style: TextStyle(color: Colors.white70)),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCountryCode,
                  dropdownColor: AppTheme.marineBlue,
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.gold),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: const [
                    DropdownMenuItem(value: '+221', child: Text('🇸🇳 +221')),
                    DropdownMenuItem(value: '+33', child: Text('🇫🇷 +33')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedCountryCode = value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _phoneController,
                label: 'Numéro de téléphone',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildLoginButton(onPressed: _handlePhoneLogin, label: 'Recevoir un code'),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.gold) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.gold),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildLoginButton({required VoidCallback onPressed, String label = 'Se connecter'}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.marineBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          disabledBackgroundColor: AppTheme.gold.withValues(alpha: 0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: AppTheme.marineBlue),
              )
            : Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomLinks() {
    return Column(
      children: [
        TextButton(
          onPressed: _handleForgotPassword,
          child: const Text('Mot de passe oublié ?', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Pas encore de compte ? ", style: TextStyle(color: Colors.white54)),
            GestureDetector(
              onTap: () {
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TypeSelectionScreen()));
                }
              },
              child: const Text(
                'Créer un compte',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.gold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
