import 'dart:async';
// ignore_for_file: depend_on_referenced_packages
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/user_provider.dart';
import 'package:tontetic/core/services/security_service.dart';
import 'package:tontetic/core/services/stripe_service.dart';
import 'core/services/encryption_service.dart'; // E2E
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';

import 'core/providers/auth_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/routing/router.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Web URL Strategy removed for Android build compatibility

  
  // Initialize date formatting for French locale
  try {
    await initializeDateFormatting('fr_FR', null);
  } catch (e) {
    debugPrint('Fatal: Failed to initialize date formatting: $e');
  }

  // Initialize Security Service
  try {
    await SecurityService.initialize();
    debugPrint('Security service initialized successfully');
  } catch (e) {
    debugPrint('Fatal: Failed to initialize SecurityService: $e');
  }
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // Initialize Stripe
  try {
    await StripeService.initialize();
  } catch (e) {
    debugPrint('Fatal: Failed to initialize StripeService: $e');
  }

  // --- PRODUCTION SAFETY GUARD ---
  // Ensure we never ship a Release build with Mocks enabled
  if (kReleaseMode) {
    final bool mocksEnabled = dotenv.env['MOCK_ENABLED'] == 'true';
    // Assert logic requested by User: assert(!kReleaseMode || !mockEnabled);
    // Since asserts are stripped in release, we use an explicit runtime check.
    if (mocksEnabled) {
       // Stop execution immediately
       throw Exception('SECURITY FATAL: MOCK_ENABLED is true in RELEASE MODE. Aborting startup.');
    }
  }
  
  // Initialize Firebase with error handling
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('Firebase initialized successfully: ${Firebase.app().options.projectId}');
    
    // Background Sync (One-time) - Populate Enterprise Plans if missing
    _seedEnterprisePlansInBackground();
    
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Custom Error Widget for the grey screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Une erreur est survenue lors du chargement',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Force refresh or retry
                    runApp(const ProviderScope(child: TonteticApp()));
                  }),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
  
  runApp(const ProviderScope(child: TonteticApp()));
}

/// BACKGROUND SYNC: Seeds Enterprise Plans into Firestore if they are missing.
/// This will be removed after confirmation of success.
void _seedEnterprisePlansInBackground() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final enterpriseSnapshot = await firestore.collection('plans').where('type', isEqualTo: 'enterprise').limit(1).get();
    
    if (enterpriseSnapshot.docs.isNotEmpty) {
      debugPrint('[SYNC] Enterprise plans already exist. Skipping seed.');
      return;
    }

    debugPrint('[SYNC] 🚀 Seeding Enterprise Plans into Firestore...');
    final plans = [
      {
        'code': 'starter_pro',
        'type': 'enterprise',
        'name': 'Starter Pro',
        'prices': {'EUR': 29.99, 'XOF': 19500.0},
        'limits': {'maxMembers': 24, 'maxCircles': 2},
        'features': ['24 salariés max', '2 tontines', 'Dashboard complet', 'Messagerie interne', 'Support flexible'],
        'stripePriceId': 'price_1Suh1rCpguZvNb1UL4HZHv2v',
        'isRecommended': false,
        'status': 'active',
        'sortOrder': 10,
      },
      {
        'code': 'team',
        'type': 'enterprise',
        'name': 'Team',
        'prices': {'EUR': 39.99, 'XOF': 26000.0},
        'limits': {'maxMembers': 48, 'maxCircles': 4},
        'features': ['48 salariés max', '4 tontines', 'Dashboard complet', 'Tontines multi-équipes', 'Support flexible'],
        'stripePriceId': 'price_1Suh3WCpguZvNb1UqkodV50W',
        'isRecommended': true,
        'status': 'active',
        'sortOrder': 20,
      },
      {
        'code': 'team_pro',
        'type': 'enterprise',
        'name': 'Team Pro',
        'prices': {'EUR': 49.99, 'XOF': 32500.0},
        'limits': {'maxMembers': 60, 'maxCircles': 4},
        'features': ['60 salariés max', '4 tontines', 'Dashboard complet', 'Tontines multi-services', 'Support prioritaire'],
        'stripePriceId': 'price_1Suh6tCpguZvNb1Ufn4GQOZd',
        'isRecommended': false,
        'status': 'active',
        'sortOrder': 30,
      },
      {
        'code': 'department',
        'type': 'enterprise',
        'name': 'Department',
        'prices': {'EUR': 69.99, 'XOF': 45500.0},
        'limits': {'maxMembers': 84, 'maxCircles': 7},
        'features': ['84 salariés max', '7 tontines', 'Suivi scores par équipe', 'Notifications avancées', 'Support prioritaire'],
        'stripePriceId': 'price_1Suh9NCpguZvNb1UrPDgTxqe',
        'isRecommended': false,
        'status': 'active',
        'sortOrder': 40,
      },
      {
        'code': 'enterprise',
        'type': 'enterprise',
        'name': 'Enterprise',
        'prices': {'EUR': 89.99, 'XOF': 58500.0},
        'limits': {'maxMembers': 108, 'maxCircles': 10},
        'features': ['108 salariés max', '10 tontines', 'Export PDF/CSV', 'Reporting consolidé', 'Support dédié'],
        'stripePriceId': 'price_1SuhCzCpguZvNb1UrmPmAZVb',
        'isRecommended': false,
        'status': 'active',
        'sortOrder': 50,
      },
    ];

    final batch = firestore.batch();
    for (var planData in plans) {
      final docRef = firestore.collection('plans').doc(planData['code'] as String);
      batch.set(docRef, {
        ...planData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    await batch.commit();
    debugPrint('[SYNC] ✅ Enterprise plans seeded successfully.');
  } catch (e) {
    debugPrint('[SYNC] ❌ Error seeding enterprise plans: $e');
  }
}


class TonteticApp extends ConsumerStatefulWidget {
  const TonteticApp({super.key});

  @override
  ConsumerState<TonteticApp> createState() => _TonteticAppState();
}

class _TonteticAppState extends ConsumerState<TonteticApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Check for initial link (Cold start / Refresh)
    try {
      final initialUri = await _appLinks.getInitialLink(); // Try getInitialLink instead of getInitialUri
      if (initialUri != null) {
        debugPrint('[DEEP_LINK] 🚀 Initial Link found: $initialUri');
        // Initial handling needs to wait for Navigator to be ready, but here we just process logic
        // For navigation, we might need to wait for AuthWrapper to build.
        // For now, let's just log and try handling. 
        // If it requires Context, it might fail if called too early.
        // Better strategy: Store it or use a microtask.
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('[DEEP_LINK] ⚠️ Error getting initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DEEP_LINK] 🔗 Lien reçu (Stream) : $uri');
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final uriString = uri.toString().toLowerCase();
    debugPrint('[DEEP_LINK] 🔗 Processing link: $uriString');
    
    // Use full URI string for robust path matching across different schemes (tontetic:// vs https://)
    final uriStringLower = uriString;
    
    // Navigation Logic based on Path
    // This allows the app to restore the screen on Refresh
    final context = _navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[DEEP_LINK] ⚠️ Context is null, cannot handle link yet');
      return;
    }

    if (uriStringLower.contains('payment/success')) {
       debugPrint('[DEEP_LINK] ✅ Payment Success detected');
       _showNotification('Succès !', 'Votre paiement a été validé. Vos avantages Premium sont activés.');
       // Redirect to home or refresh state
       ref.read(routerProvider).go('/');
    } else if (uriStringLower.contains('payment/cancel')) {
       debugPrint('[DEEP_LINK] ❌ Payment Cancelled detected');
       _showNotification('Annulé', 'Le paiement a été interrompu.', isError: true);
    } else if (uriStringLower.contains('/settings')) {
       ref.read(routerProvider).push('/settings');
    } else if (uriStringLower.contains('/profile')) {
       ref.read(routerProvider).push('/profile?isMe=true');
    } else if (uriStringLower.contains('/tontine/')) {
       final segments = uri.pathSegments;
       if (segments.contains('tontine')) {
         final id = segments.last;
         ref.read(routerProvider).push('/tontine/$id?name=Cercle');
       }
    }
  }

  void _showNotification(String title, String message, {bool isError = false}) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(message),
            ],
          ),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final goRouter = ref.watch(routerProvider);
    
    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'Tontetic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
    );
  }
}


