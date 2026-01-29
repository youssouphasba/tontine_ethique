import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/localization_provider.dart';

/// MainShell provides persistent bottom navigation across all app pages
/// Uses go_router's ShellRoute pattern
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncTabWithRoute();
      }
    });
  }

  void _syncTabWithRoute() {
    try {
      final location = GoRouterState.of(context).matchedLocation;
      int newIndex = 0;
      
      if (location.startsWith('/tontines') || location.startsWith('/tontine') || 
          location.startsWith('/create-tontine') || location.startsWith('/explorer')) {
        newIndex = 1;
      } else if (location.startsWith('/wallet')) {
        newIndex = 2;
      } else if (location.startsWith('/boutique')) {
        newIndex = 3;
      } else if (location.startsWith('/settings') || location.startsWith('/subscription')) {
        newIndex = 4;
      }
      
      if (newIndex != _selectedIndex && mounted) {
        setState(() => _selectedIndex = newIndex);
      }
    } catch (e) {
      // Ignore if router state is not available
      debugPrint('MainShell: Could not sync tab with route: $e');
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return; // Don't navigate if already on tab
    
    setState(() => _selectedIndex = index);
    
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/tontines');
        break;
      case 2:
        context.go('/wallet');
        break;
      case 3:
        context.go('/boutique');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(localizationProvider);
    
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.marineBlue,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l10n.translate('tab_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.groups),
            label: l10n.translate('my_tontines'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: l10n.translate('tab_wallet'),
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Boutique',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
