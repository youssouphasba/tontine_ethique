import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/social/presentation/screens/profile_screen.dart';
import '../../features/tontine/presentation/screens/circle_details_screen.dart';
import '../../features/tontine/presentation/screens/circle_chat_screen.dart';
import '../../features/social/presentation/screens/conversations_list_screen.dart';
import '../../features/shop/presentation/screens/boutique_screen.dart';
import '../../features/ai/presentation/screens/smart_coach_screen.dart';
import '../../features/tontine/presentation/screens/create_tontine_screen.dart';
import '../../features/tontine/presentation/screens/explorer_screen.dart';
import '../../features/tontine/presentation/screens/tontine_simulator_screen.dart';
import '../../features/tontine/presentation/screens/qr_invitation_screen.dart';
import '../../features/tontine/presentation/screens/invitation_landing_screen.dart';
import '../../features/tontine/presentation/screens/my_circles_screen.dart';
import '../../features/wallet/presentation/screens/wallet_tab_screen.dart';
import '../../features/auth/presentation/screens/type_selection_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/social/presentation/screens/direct_chat_screen.dart';
import '../presentation/auth_wrapper.dart';
import '../presentation/main_shell.dart';
import '../../features/subscription/presentation/screens/subscription_selection_screen.dart';
import '../../features/subscription/presentation/screens/payment_success_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';


/// Stores the pending redirect URL for after login (e.g., /join links)
final pendingRedirectProvider = StateProvider<String?>((ref) => null);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isGuestMode = ref.watch(isGuestModeProvider);
  
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final user = authState.value;
      final isLoading = authState.isLoading;

      // 1. Wait for Auth to initialize
      if (isLoading) return null;

      // 2. Define routes that don't require authentication
      final path = state.matchedLocation;
      final fullUri = state.uri.toString();
      final isPublicRoute = path == '/onboarding' || 
                           path == '/auth' || 
                           path == '/type-selection' ||
                           path.startsWith('/join');

      // 3. Authorization Logic
      // If we are in Guest Mode, we allow everything (Dashboard will handle specific blockers)
      if (isGuestMode) return null;

      // 4. If not logged in and not on a public route, force onboarding
      // Store /join links for after login
      if (user == null) {
        if (path.startsWith('/join') && !isPublicRoute) {
          // Store the intended join destination for after login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(pendingRedirectProvider.notifier).state = fullUri;
          });
        }
        return isPublicRoute ? null : '/onboarding';
      }

      // 4. If logged in but on onboarding, check for pending redirect
      if (path == '/onboarding') {
        final pendingRedirect = ref.read(pendingRedirectProvider);
        if (pendingRedirect != null && pendingRedirect.isNotEmpty) {
          // Clear the pending redirect and go there
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(pendingRedirectProvider.notifier).state = null;
          });
          return pendingRedirect;
        }
        return '/';
      }
      
      // 5. If we just logged in and have a pending redirect, use it
      final pendingRedirect = ref.read(pendingRedirectProvider);
      if (pendingRedirect != null && pendingRedirect.isNotEmpty && path == '/') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(pendingRedirectProvider.notifier).state = null;
        });
        return pendingRedirect;
      }

      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/type-selection',
        builder: (context, state) => const TypeSelectionScreen(),
      ),
      
      // Invitation links - redirect to circle details with isJoined=false
      GoRoute(
        path: '/join/:circleId',
        builder: (context, state) {
          final circleId = state.pathParameters['circleId'] ?? '';
          return InvitationLandingScreen(invitationCode: circleId);
        },
      ),
      GoRoute(
        path: '/join-circle',
        builder: (context, state) {
          final circleId = state.uri.queryParameters['id'] ?? '';
          return InvitationLandingScreen(invitationCode: circleId);
        },
      ),
      
      // Payment routes (no shell - external redirect)
      GoRoute(
        path: '/payment/success',
        builder: (context, state) {
          final returnUrl = state.uri.queryParameters['returnUrl'];
          final planId = state.uri.queryParameters['planId'];
          return PaymentSuccessScreen(returnUrl: returnUrl, planId: planId);
        },
      ),
      GoRoute(
        path: '/payment/cancel',
        redirect: (context, state) {
          final returnUrl = state.uri.queryParameters['returnUrl'];
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Paiement annulé. Vous pouvez réessayer.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          });
          
          return returnUrl ?? '/';
        },
        builder: (context, state) => const DashboardScreen(),
      ),
      
      // Main app routes WITH persistent bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const AuthWrapper(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) {
              final indexStr = state.uri.queryParameters['index'];
              final index = int.tryParse(indexStr ?? '0') ?? 0;
              return DashboardScreen(initialIndex: index);
            },
          ),
          GoRoute(
            path: '/tontines',
            builder: (context, state) => const MyCirclesScreen(),
          ),
          GoRoute(
            path: '/wallet',
            builder: (context, state) => const WalletTabScreen(),
          ),
          GoRoute(
            path: '/boutique',
            builder: (context, state) => const BoutiqueScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),

          GoRoute(
            path: '/profile',
            builder: (context, state) {
              final isMe = state.uri.queryParameters['isMe'] == 'true';
              return ProfileScreen(userName: state.uri.queryParameters['name'] ?? 'Utilisateur', isMe: isMe);
            },
          ),
          GoRoute(
            path: '/tontine/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final name = state.uri.queryParameters['name'] ?? 'Détails Tontine';
              final isJoinedParam = state.uri.queryParameters['isJoined'];
              // If isJoined=false is explicitly passed (from invitation links), show join button
              final isJoined = isJoinedParam != 'false'; 
              return CircleDetailsScreen(circleId: id, circleName: name, isJoined: isJoined);
            },
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final name = state.uri.queryParameters['name'] ?? 'Chat de groupe';
              return CircleChatScreen(circleId: id, circleName: name);
            },
          ),
          GoRoute(
            path: '/direct-chat/:userId',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              final userName = state.uri.queryParameters['name'] ?? 'Membre';
              return DirectChatScreen(friendId: userId, friendName: userName);
            },
          ),
          GoRoute(
            path: '/conversations',
            builder: (context, state) => const ConversationsListScreen(),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) => const SubscriptionSelectionScreen(),
          ),
          GoRoute(
            path: '/coach',
            builder: (context, state) {
              final prompt = state.uri.queryParameters['text'];
              return SmartCoachScreen(initialVoiceTranscription: prompt);
            },
          ),
          GoRoute(
            path: '/create-tontine',
            builder: (context, state) => const CreateTontineScreen(),
          ),
          GoRoute(
            path: '/explorer',
            builder: (context, state) => const ExplorerScreen(),
          ),
          GoRoute(
            path: '/simulator',
            builder: (context, state) => const TontineSimulatorScreen(),
          ),
          GoRoute(
            path: '/qr-invitation',
            builder: (context, state) => const QRInvitationScreen(),
          ),
        ],
      ),
    ],
  );
});
