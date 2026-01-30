import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/business/subscription_service.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/core/theme/app_theme.dart';
// import 'package:tontetic/core/services/support_service.dart'; - UNUSED
// import 'package:tontetic/core/providers/localization_provider.dart'; - UNUSED
import 'package:tontetic/core/services/stripe_service.dart';
import 'package:tontetic/core/models/plan_model.dart';
import 'package:tontetic/core/providers/plans_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionSelectionScreen extends ConsumerWidget {
  const SubscriptionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final plansAsync = ref.watch(userPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans & Abonnements'),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: plansAsync.when(
        data: (plans) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Choisissez le plan adapté à vos ambitions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.marineBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toutes les fonctionnalités sont disponibles dans tous les plans',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            
            // Dynamic Plans from Firestore
            ...plans.map((plan) {
              // Map some colors based on plan order or ID for variety
              final color = _getPlanColor(plan);
              final gradient = _getPlanGradient(plan);
              
              return _buildDynamicPlanCard(
                context,
                ref,
                plan: plan,
                user: user,
                color: color,
                gradientColors: gradient,
                isRecommended: plan.isRecommended,
              );
            }),
            
            const SizedBox(height: 24),
            
            // Fonctionnalités communes
            _buildCommonFeaturesCard(),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur lors du chargement des offres : $err')),
      ),
    );
  }

  Color _getPlanColor(Plan plan) {
    if (plan.id.contains('premium')) return AppTheme.gold;
    if (plan.id.contains('standard')) return Colors.purple.shade600;
    if (plan.id.contains('starter')) return Colors.blue.shade600;
    return Colors.grey.shade500;
  }

  List<Color> _getPlanGradient(Plan plan) {
    if (plan.id.contains('premium')) return [Colors.amber.shade400, Colors.orange.shade700];
    if (plan.id.contains('standard')) return [Colors.purple.shade400, Colors.purple.shade700];
    if (plan.id.contains('starter')) return [Colors.blue.shade400, Colors.blue.shade700];
    return [Colors.grey.shade400, Colors.grey.shade600];
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text('Vous devez être connecté pour souscrire à un plan et profiter des avantages Premium.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/auth');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicPlanCard(
    BuildContext context,
    WidgetRef ref, {
    required Plan plan,
    required UserState user,
    required Color color,
    required List<Color> gradientColors,
    bool isRecommended = false,
  }) {
    final isCurrent = user.planId == plan.id;
    final priceText = SubscriptionService.formatPlanPrice(plan, user.zone);
    final maxCircles = plan.getLimit<int>('maxCircles', 1);
    final remainingCircles = SubscriptionService.getRemainingCircles(plan, user.activeCirclesCount);

    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: isCurrent ? 8 : 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isCurrent 
              ? BorderSide(color: color, width: 3) 
              : BorderSide.none,
          ),
          child: Column(
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(plan.emoji ?? '🆓', style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  plan.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                                  onPressed: () => _showDynamicPlanDetails(context, plan, user),
                                  padding: const EdgeInsets.only(left: 8),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontSize: 14, 
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: color, size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              'ACTUEL',
                              style: TextStyle(
                                color: Colors.black, // Use neutral black for readability on white
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (plan.description != null)
                      Text(
                        plan.description!,
                        style: TextStyle(
                          fontStyle: FontStyle.italic, 
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    // Limits
                    _buildLimitRow(
                      context,
                      Icons.donut_large, 
                      'Tontines simultanées', 
                      '$maxCircles max',
                      color,
                    ),
                    _buildLimitRow(
                      context,
                      Icons.groups, 
                      'Participants par tontine', 
                      '${plan.getLimit<int>('maxMembers', 5)} max',
                      color,
                    ),
                    if (plan.supportLevel != null)
                      _buildLimitRow(
                        context,
                        Icons.support_agent, 
                        'Support', 
                        plan.supportLevel!,
                        color,
                      ),
                    
                    if (plan.getLimit<bool>('hasAlerts', false) || plan.getLimit<bool>('hasPriorityAI', false)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (plan.getLimit<bool>('hasAlerts', false))
                            _buildBadge('🔔 Alertes', Colors.amber),
                          if (plan.getLimit<bool>('hasPriorityAI', false))
                            _buildBadge('🤖 IA Prioritaire', Colors.purple),
                        ],
                      ),
                    ],
                    
                    if (isCurrent) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tontines restantes',
                              style: TextStyle(color: color, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '$remainingCircles / $maxCircles',
                              style: TextStyle(
                                color: color, 
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    if (!isCurrent)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _handleDynamicPlanSelection(context, ref, plan, user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: plan.getPrice(user.zone == UserZone.zoneEuro ? 'EUR' : 'XOF') == 0 ? Colors.grey : color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            plan.getPrice(user.zone == UserZone.zoneEuro ? 'EUR' : 'XOF') == 0 
                              ? 'Passer au Gratuit' 
                              : 'Choisir ${plan.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Recommended badge
        if (isRecommended && !isCurrent)
          Positioned(
            top: 0,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8), 
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'RECOMMANDÉ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLimitRow(BuildContext context, IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade700)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color is MaterialColor ? color.shade700 : color),
      ),
    );
  }

  Widget _buildCommonFeaturesCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Inclus dans TOUS les plans',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              'Accès illimité aux tontines publiques',
              'Paiements sécurisés via PSP',
              'Support client 7j/7',
              'Zéro frais cachés'
            ].map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check, color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Text(feature),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _handleDynamicPlanSelection(
    BuildContext context, 
    WidgetRef ref, 
    Plan plan, 
    UserState user,
  ) {
    // Get user ID from provider or fallback to Firebase Auth
    String userId = user.uid;
    if (userId.isEmpty) {
      userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    
    debugPrint('[PLAN_SELECTION] START - Plan: ${plan.id}, User: $userId, FirebaseUser: ${FirebaseAuth.instance.currentUser?.uid}');
    
    // Check if user is authenticated
    if (userId.isEmpty) {
      debugPrint('[PLAN_SELECTION] ERROR: User not authenticated');
      _showLoginRequiredDialog(context);
      return;
    }
    
    try {
      final maxCircles = plan.getLimit<int>('maxCircles', 1);
      debugPrint('[PLAN_SELECTION] maxCircles: $maxCircles');
      
      final isFree = plan.getPrice(user.zone == UserZone.zoneEuro ? 'EUR' : 'XOF') == 0;
      debugPrint('[PLAN_SELECTION] isFree: $isFree, zone: ${user.zone}');
      
      // DOWNGRADE CHECK 1: Number of active tontines
      if (user.activeCirclesCount > maxCircles) {
        debugPrint('[PLAN_SELECTION] BLOCKED - Too many circles');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible : Vous avez ${user.activeCirclesCount} tontines actives, '
              'le plan ${plan.name} n\'en autorise que $maxCircles.\n'
              'Terminez ou quittez des tontines avant de changer de plan.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      
      // Direct action without confirmation popup
      if (isFree) {
        debugPrint('[PLAN_SELECTION] Switching to FREE plan');
        // Valid selection for free plan
        ref.read(userProvider.notifier).setPlanId(plan.id); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Passage au plan ${plan.name} réussi !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        debugPrint('[PLAN_SELECTION] Starting Stripe checkout for paid plan');
        // PRO FLOW: Stripe Checkout for paid plans
        _startDynamicStripeCheckout(context, ref, plan, user).catchError((error, stackTrace) {
          debugPrint('[PLAN_SELECTION] ERROR in checkout: $error');
          debugPrint('[PLAN_SELECTION] Stack: $stackTrace');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur de paiement : ${error.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[PLAN_SELECTION] EXCEPTION: $e');
      debugPrint('[PLAN_SELECTION] Stack: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur inattendue : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDowngradeWarningIfNeeded(
    BuildContext context,
    Plan plan,
    int maxCircles,
    int maxMembers,
    VoidCallback onConfirm,
  ) {
    // Check if this is a downgrade by comparing with current plan
    // For simplicity, we'll show the confirmation dialog for all plan changes
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.marineBlue),
            const SizedBox(width: 8),
            Text('Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vous allez souscrire au plan ${plan.name}.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Limites de ce plan :', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('• Maximum $maxCircles tontine(s) actives'),
                  Text('• Maximum $maxMembers membres par tontine'),
                  const SizedBox(height: 8),
                  const Text(
                    'Si vos tontines actuelles dépassent ces limites, '
                    'vous devrez les ajuster avant le prochain cycle.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.marineBlue),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startDynamicStripeCheckout(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
    UserState user,
  ) async {
    // Get user ID from provider or fallback to Firebase Auth
    String userId = user.uid;
    if (userId.isEmpty) {
      userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    
    debugPrint('[PLAN_CLICK] plan=${plan.id}, user=$userId, isWeb=$kIsWeb');
    
    if (userId.isEmpty) return;
    
    final priceId = plan.stripePriceId;
    if (priceId == null) {
      debugPrint('[PLAN_CLICK] ERROR: No stripePriceId for plan ${plan.id}');
      return;
    }

    try {
      String email = user.email;
      if (email.isEmpty) {
        final firebaseEmail = FirebaseAuth.instance.currentUser?.email;
        if (firebaseEmail != null && firebaseEmail.isNotEmpty) {
          email = firebaseEmail;
        }
      }
      
      if (email.isEmpty) {
        final phoneRaw = user.phoneNumber;
        final phone = phoneRaw.isNotEmpty ? phoneRaw.replaceAll(RegExp(r'[^0-9]'), '') : '';
        if (phone.isNotEmpty) {
          email = '$phone@tontetic.app';
        } else {
          email = '$userId@tontetic.app';
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Préparation du paiement sécurisé...'),
          duration: Duration(seconds: 2),
        ),
      );

      String currentPath = '/subscription';
      try {
        currentPath = GoRouter.of(context).routerDelegate.currentConfiguration.last.matchedLocation;
      } catch (e) {
        currentPath = '/subscription';
      }
      final encodedReturnUrl = Uri.encodeComponent(currentPath);
      
      final successUrl = kIsWeb 
          ? 'https://tontetic-app.web.app/payment/success?returnUrl=$encodedReturnUrl&planId=${plan.id}&source=web'
          : 'tontetic://app/payment/success?returnUrl=$encodedReturnUrl&planId=${plan.id}';
          
      final cancelUrl = kIsWeb
          ? 'https://tontetic-app.web.app/payment/cancel?returnUrl=$encodedReturnUrl&source=web'
          : 'tontetic://app/payment/cancel?returnUrl=$encodedReturnUrl';

      final checkoutUrl = await StripeService.createCheckoutSession(
        priceId: priceId,
        email: email,
        customerId: user.stripeCustomerId,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
        userId: userId,
        planId: plan.id,
      );

      debugPrint('[REDIRECT_PREPARE] checkoutUrl=$checkoutUrl');

      if (!context.mounted) return;

      // 2. Launch Browser / Redirect
      final uri = Uri.parse(checkoutUrl);
      
      if (uri.scheme.isEmpty || uri.host.isEmpty) {
        debugPrint('[REDIRECT_FAILED] Invalid URL: $checkoutUrl');
        throw 'URL de paiement invalide générée par le serveur: $checkoutUrl';
      }

      // WEB: Use url_launcher with _self to redirect in same tab
      debugPrint('[REDIRECT_OK] Launching: $uri');
      
      await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
      
      debugPrint('[REDIRECT_OK] URL launched successfully');
    } catch (e, stackTrace) {
      debugPrint('[REDIRECT_FAILED] Error: $e');
      debugPrint('[REDIRECT_FAILED] Stack: $stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _showDynamicPlanDetails(BuildContext context, Plan plan, UserState user) {
    final maxCircles = plan.getLimit<int>('maxCircles', 1);
    final maxMembers = plan.getLimit<int>('maxMembers', 5);
    final hasAlerts = plan.getLimit<bool>('hasAlerts', false);
    final hasPriorityAI = plan.getLimit<bool>('hasPriorityAI', false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(plan.emoji ?? '🆓', style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Text(
                  'Détails du Plan ${plan.name}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.marineBlue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              SubscriptionService.formatPlanPrice(plan, user.zone),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildDetailSection('🎯 LIMITES DE GESTION', [
                    'Jusqu\'à $maxCircles tontine(s) active(s) simultanément.',
                    'Maximum $maxMembers participants par tontine.',
                    'Fonctionnalités complètes (Vote, Chat, Wallet, IA).',
                  ]),
                  _buildDetailSection('🎧 SUPPORT & SERVICE', [
                    'Niveau de support : ${plan.supportLevel ?? "Standard"}.',
                    if (hasAlerts) 'Système d\'alertes de sécurité avancées inclus.',
                    if (hasPriorityAI) 'Accès prioritaire à l\'IA Tontii pour vos conseils de gestion.',
                  ]),
                  _buildDetailSection('🔄 RÈGLES DE TRANSITION', [
                    '📈 UPGRADE (Montée en gamme) : Effet immédiat.',
                    '📉 DOWNGRADE (Rétrogradation) :',
                    '   • AUTOMATIQUE : Si votre usage actuel respecte les limites du plan inférieur.',
                    '   • CONDITIONNEL : Si vous dépassez les limites, accord administratif requis.',
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gavel, color: AppTheme.marineBlue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ces modalités font partie intégrante des CGU.',
                            style: TextStyle(fontSize: 12, color: AppTheme.marineBlue, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.marineBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('J\'AI COMPRIS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> bulletPoints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ...bulletPoints.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(point, style: const TextStyle(fontSize: 14, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
