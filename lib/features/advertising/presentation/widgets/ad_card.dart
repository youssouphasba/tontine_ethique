import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/tontine/presentation/widgets/sponsored_badge.dart';

class AdCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String description;
  final String objectiveMatch;
  final VoidCallback onAction;

  const AdCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.objectiveMatch,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: _getImageProvider(),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.darken),
        ),
      ),
      child: Stack(
        children: [
          // Header: Sponsorisé Badge
          const Positioned(
            top: 40,
            right: 16,
            child: SponsoredBadge(),
          ),

          // Content Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI Match Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.gold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          "Match: $objectiveMatch",
                          style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: onAction,
                            icon: const Icon(Icons.savings),
                            label: const Text("Épargner"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.marineBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.favorite_border, color: Colors.white),
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté à votre Wishlist ❤️')));
                          },
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20), // Bottom padding for navigation bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _getImageProvider() {
    if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    }
    // PRODUCTION: No image provided - component should show loading or error state
    // Return a placeholder pattern
    return const NetworkImage('https://via.placeholder.com/800x600/1a4d7c/ffffff?text=Ad');
  }
}
