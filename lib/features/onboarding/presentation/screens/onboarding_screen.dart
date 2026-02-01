import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Tontetic',
      'description': 'La tontine moderne et solidaire.',
      'icon': Icons.groups,
    },
    {
      'title': 'Finance Éthique',
      'description': 'Une finance transparente, 100% sans intérêts.',
      'icon': Icons.volunteer_activism,
    },
    {
      'title': 'Confiance',
      'description': 'Gérez vos cercles en toute confiance, où que vous soyez.',
      'icon': Icons.security,
    },
  ];

  void _navigateToLogin() {
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : AppTheme.marineBlue,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _navigateToLogin(),
                child: Text('Passer', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold.withValues(alpha: 0.7) : Colors.white54)),
              ),
            ),
            // V_Guest: Bouton Découvrir
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                   ref.read(isGuestModeProvider.notifier).state = true;
                   context.go('/');
                },
                icon: const Icon(Icons.timer_outlined, size: 16),
                label: const Text('Découvrir l\'application (60s)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.gold,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) => setState(() => _currentPage = page),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _pages[index]['icon'] as IconData,
                          size: 100,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _pages[index]['title']! as String,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppTheme.gold,
                            fontSize: 32,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _pages[index]['description']! as String,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.white.withValues(alpha: 0.9), 
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_pages.length, (index) => _buildDot(index)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _navigateToLogin();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.marineBlue,
                    ),
                    child: Text(_currentPage == _pages.length - 1 ? 'Commencer' : 'Suivant'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Debug: Host=${Uri.base.host} | v1.0.2', 
                style: TextStyle(color: Colors.grey.withValues(alpha: 0.3), fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      height: 10,
      width: _currentPage == index ? 25 : 10,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: _currentPage == index 
            ? AppTheme.gold 
            : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.white24),
      ),
    );
  }
}
