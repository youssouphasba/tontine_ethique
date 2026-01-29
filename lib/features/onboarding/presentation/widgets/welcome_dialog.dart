import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';
import 'package:tontetic/features/auth/presentation/screens/type_selection_screen.dart';

class WelcomeDialog extends ConsumerStatefulWidget {
  const WelcomeDialog({super.key});

  @override
  ConsumerState<WelcomeDialog> createState() => _WelcomeDialogState();

  /// Shows the welcome dialog only once per user (after account creation)
  static Future<void> show(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'welcome_dialog_shown_$uid';
    final alreadyShown = prefs.getBool(key) ?? false;

    if (alreadyShown) {
      return; // Don't show again
    }

    // Show dialog and mark as shown
    if (context.mounted) {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (_) => const WelcomeDialog(),
      ).then((_) {
        // Mark as shown after dialog is closed
        prefs.setBool(key, true);
      });
    }
  }
}

class _WelcomeDialogState extends ConsumerState<WelcomeDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Finance Éthique & Solidaire',
      'icon': 'handshake', // mapped to icon below
      'content': '✅ 0% d\'intérêts (Ni payés, ni perçus)\n✅ Épargne 100% Solidaire\n✅ Entraide communautaire saine'
    },
    {
      'title': '0% de Commission',
      'icon': 'savings',
      'content': 'Tontetic ne prend AUCUNE commission sur votre épargne.\n\nNous appliquons uniquement des frais fixes de fonctionnement technique (ex: 200F ou 1€) pour la maintenance.'
    },
    {
      'title': 'Abonnements Transparents',
      'icon': 'diamond',
      'content': 'Choisissez le plan adapté à vos ambitions.\n\n💡 Facturation différée : Vous ne payez votre abonnement que lorsque votre tontine démarre !'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isGuest = user.status == AccountStatus.guest;
    
    // Button text based on user status
    String buttonText;
    if (_currentPage < _slides.length - 1) {
      buttonText = 'Suivant';
    } else if (isGuest) {
      buttonText = 'Créer un Compte';
    } else {
      buttonText = 'Commencer'; // Already has account
    }
    
    return AlertDialog(
      backgroundColor: AppTheme.marineBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        height: 420, // Increased to fix overflow
        width: double.maxFinite,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) => _buildSlide(_slides[index]),
              ),
            ),
            // Dots Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) => _buildDot(index)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold, 
                        foregroundColor: AppTheme.marineBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                        } else if (isGuest) {
                          // Go to account creation
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TypeSelectionScreen()));
                        } else {
                          // Already has account - just close
                          Navigator.pop(context);
                        }
                      },
                      child: Text(buttonText),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(Map<String, String> slide) {
    IconData iconData = Icons.handshake;
    if (slide['icon'] == 'savings') iconData = Icons.savings;
    if (slide['icon'] == 'diamond') iconData = Icons.diamond;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 60, color: AppTheme.gold),
          const SizedBox(height: 24),
          Text(
            slide['title']!,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide['content']!,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 12 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? AppTheme.gold : Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }


}
