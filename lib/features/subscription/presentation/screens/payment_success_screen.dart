import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:tontetic/core/providers/merchant_account_provider.dart';
import 'package:tontetic/features/merchant/presentation/screens/merchant_dashboard_screen.dart';

/// Payment Success Screen
/// 
/// This screen is shown after a successful Stripe Checkout.
/// It waits for the Stripe webhook to update Firestore before redirecting,
/// ensuring the user sees their updated plan.

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  final String? returnUrl;
  final String? planId; // Plan to apply after successful payment
  final String? type;   // 'merchant' or 'subscription'
  final String? shopId; // For merchant activation
  
  const PaymentSuccessScreen({super.key, this.returnUrl, this.planId, this.type, this.shopId});

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  bool _planUpdated = false;
  String? _newPlanId;
  int _secondsWaited = 0;
  Timer? _timer;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startListeningForPlanUpdate();
  }

  void _startListeningForPlanUpdate() async {
    // 0. Check for Merchant Activation FIRST
    await _checkAndApplyMerchantActivation();
    if (widget.type == 'merchant' || Uri.base.queryParameters['type'] == 'merchant') {
       // Stop here, don't listen for plan update (it's a shop update)
       return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _redirectToDestination();
      return;
    }

    // First, check if there's a pending plan update from URL or localStorage
    // This is a fallback mechanism in case the webhook is slow
    await _checkAndApplyPendingPlanUpdate(uid);

    // Listen to user document for plan changes
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      
      final data = doc.data();
      if (data != null) {
        final planId = data['planId'] as String?;
        
        // Check if plan is now NOT the free plan (updated by webhook or our fallback)
        if (planId != null && planId.isNotEmpty && !planId.contains('gratuit') && planId != 'plan_gratuit') {
          setState(() {
            _planUpdated = true;
            _newPlanId = planId;
          });
          
          // Don't auto-redirect - let user choose where to go
          _timer?.cancel();
        }
      }
    });

    // Also start a timer to track waiting time
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() => _secondsWaited++);
      
      // If we've waited too long, redirect anyway with a message
      if (_secondsWaited >= 15 && !_planUpdated) {
        timer.cancel();
        _redirectToDestination(showDelayMessage: true);
      }
    });
  }

  /// Fallback mechanism: If webhook is slow, apply plan update directly
  Future<void> _checkAndApplyPendingPlanUpdate(String uid) async {
    try {
      // Use planId from widget (passed by GoRouter) or from URL query params
      String? pendingPlanId = widget.planId;
      
      // Fallback: Check URL query params if not passed directly
      if (pendingPlanId == null || pendingPlanId.isEmpty) {
        final uri = Uri.base;
        pendingPlanId = uri.queryParameters['planId'];
      }
      
      debugPrint('[PAYMENT_SUCCESS] Pending planId: $pendingPlanId');
      
      if (pendingPlanId != null && pendingPlanId.isNotEmpty && !pendingPlanId.contains('gratuit')) {
        debugPrint('[PAYMENT_SUCCESS] Applying planId: $pendingPlanId');
        
        // Apply directly to Firestore - ONLY write planId (isPremium/subscriptionStatus are protected by security rules)
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'planId': pendingPlanId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        debugPrint('[PAYMENT_SUCCESS] ✅ Applied pending plan update: $pendingPlanId');
        
        // Force update the userProvider state immediately (don't wait for Firestore listener)
        ref.read(userProvider.notifier).setPlanId(pendingPlanId);
        
        setState(() {
          _planUpdated = true;
          _newPlanId = pendingPlanId;
        });
      } else {
        debugPrint('[PAYMENT_SUCCESS] No valid planId found, waiting for webhook...');
      }
    } catch (e) {
      debugPrint('[PAYMENT_SUCCESS] Could not apply pending update: $e');
    }
  }

  Future<void> _checkAndApplyMerchantActivation() async {
    // Check if this is a merchant payment
    String? type = widget.type;
    String? shopId = widget.shopId;
    
    // Fallback URL params
    if (type == null) {
       final uri = Uri.base;
       type = uri.queryParameters['type'];
       shopId = uri.queryParameters['shopId'];
    }

    if (type == 'merchant' && shopId != null && shopId.isNotEmpty) {
      debugPrint('[PAYMENT_SUCCESS] Activating Shop: $shopId');
      try {
        await ref.read(merchantAccountProvider.notifier).activateShop(shopId);
        
        setState(() {
          _planUpdated = true;
          // Use a special sentinel or just rely on manual text override in build
        });
      } catch (e) {
        debugPrint("Error activating shop: $e");
      }
    }
  }

  void _redirectToDestination({bool showDelayMessage = false}) {
    _timer?.cancel();
    _subscription?.cancel();
    
    if (!mounted) return;
    
    if (showDelayMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Votre plan sera mis à jour dans quelques instants. Rechargez la page si nécessaire.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Paiement réussi ! Plan mis à jour: ${_getPlanDisplayName(_newPlanId)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    
    // Invalidate plans provider to force refresh of subscription page
    ref.invalidate(userPlansProvider);
    
    // Redirect to return URL or subscription page
    final destination = widget.returnUrl ?? '/subscription';
    context.go(destination);
  }

  String _getPlanDisplayName(String? planId) {
    if (planId == null) return 'Premium';
    if (planId.contains('starter')) return 'Starter';
    if (planId.contains('standard')) return 'Standard';
    if (planId.contains('premium')) return 'Premium';
    return planId;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_planUpdated) ...[
                // Success state
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  '🎉 Paiement Réussi !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Votre plan a été mis à jour:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.type == 'merchant' || Uri.base.queryParameters['type'] == 'merchant' 
                      ? 'Compte Marchand Activé' 
                      : _getPlanDisplayName(_newPlanId),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Redirection en cours...',
                  style: TextStyle(color: Colors.grey),
                ),
              ] else ...[
                // Waiting state
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.marineBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Finalisation du paiement...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Veuillez patienter quelques instants.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mise à jour de votre compte...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                if (_secondsWaited > 5) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Cela peut prendre quelques secondes...',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 48),
              
              // Single action button - go to tontine creation
              if (_planUpdated) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.type == 'merchant' || Uri.base.queryParameters['type'] == 'merchant') {
                         ref.read(merchantAccountProvider.notifier).switchToMerchant();
                         Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MerchantDashboardScreen()));
                      } else {
                         context.go('/'); // Redirect to Dashboard
                      }
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Retour à l\'accueil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ] else ...[
                  // Skip button while waiting
                TextButton(
                  onPressed: () {
                    context.go('/'); // Redirect to Dashboard
                  },
                  child: const Text('Aller à l\'accueil →'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
