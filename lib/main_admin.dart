import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/screens/admin_wrapper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // --- PRODUCTION SAFETY GUARD ---
  if (kReleaseMode) {
    final bool mocksEnabled = dotenv.env['MOCK_ENABLED'] == 'true';
    if (mocksEnabled) {
       throw Exception('SECURITY FATAL: MOCK_ENABLED is true in RELEASE MODE. Aborting startup.');
    }
  }
  
  // Initialize Firebase
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('Firebase Admin initialized successfully');
  } catch (e) {
    debugPrint('Firebase Admin initialization failed: $e');
  }
  
  runApp(const ProviderScope(child: TonteticAdminApp()));
}

class TonteticAdminApp extends StatelessWidget {
  const TonteticAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tontetic Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Apply darker/denser theme tweak for admin if desired
      home: const AdminWrapper(),
    );
  }
}
