import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/auth_provider.dart';
import 'dart:async';

class OtpDialog extends ConsumerStatefulWidget {
  final String phone;
  final Function(String)? onVerificationSuccess;

  const OtpDialog({
    super.key, 
    required this.phone,
    this.onVerificationSuccess,
  });

  static Future<String?> show(BuildContext context, {required String phone}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => OtpDialog(phone: phone),
    );
  }

  @override
  ConsumerState<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends ConsumerState<OtpDialog> {
  final _controller = TextEditingController();
  int _timeLeft = 60;
  Timer? _timer;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timeLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Code trop court');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.validateOtp(code);
      
      if (result.success) {
        if (mounted) Navigator.pop(context, 'SUCCESS');
      } else {
        setState(() {
          _isLoading = false;
          _error = result.error ?? 'Code invalide';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur: $e';
      });
    }
  }

  Future<void> _resend() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final result = await authService.sendOtp(widget.phone);
    setState(() => _isLoading = false);

    if (result.success) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code renvoyé !'), backgroundColor: Colors.green),
      );
    } else {
      setState(() => _error = result.error ?? 'Erreur envoi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          const Icon(Icons.lock_clock_outlined, size: 48, color: AppTheme.gold),
          const SizedBox(height: 16),
          const Text('Vérification OTP', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Code envoyé au ${widget.phone}',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '------',
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _timeLeft > 0 ? 'Expire dans ${_timeLeft}s' : 'Code expiré',
            style: TextStyle(
              color: _timeLeft > 0 ? Colors.grey : AppTheme.errorRed,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (_timeLeft == 0)
            TextButton(
              onPressed: _isLoading ? null : _resend,
              child: const Text('Renvoyer le code'),
            ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annuler', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.marineBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Vérifier'),
        ),
      ],
    );
  }
}
