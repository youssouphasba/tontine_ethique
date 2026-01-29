import 'package:flutter/material.dart';
import 'package:tontetic/core/theme/app_theme.dart';

class SponsoredBadge extends StatelessWidget {
  final bool isCompact;

  const SponsoredBadge({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Text('Pub', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.marineBlue.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sponsorisé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.marineBlue)),
        ],
      ),
    );
  }
}
