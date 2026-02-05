import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/security/security_service.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// V11.5 - Security Middleware Widgets
/// Reusable components for security checks

/// Widget that checks KYC status before allowing action
class KycGate extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onBlocked;

  const KycGate({
    super.key,
    required this.child,
    this.fallback,
    this.onBlocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // V4.0 - KYC Disabled by user request
    return child;
  }
}

/// Widget that checks if user can join circle
class CircleJoinGate extends ConsumerWidget {
  final Widget child;
  final String circleId;

  const CircleJoinGate({
    super.key,
    required this.child,
    required this.circleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    // final security = ref.watch(securityProvider); - UNUSED
    final securityNotifier = ref.read(securityProvider.notifier);
    
    final result = securityNotifier.canJoinCircle(
      userId: user.phoneNumber,
      isKycVerified: user.isKyVerified,
      honorScore: user.honorScore,
      currentActiveCircles: securityNotifier.getActiveCircleCount(user.phoneNumber),
    );
    
    if (!result.allowed) {
      return _buildBlockedCard(context, result);
    }
    
    if (result.warning != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWarningBanner(result.warning!),
          child,
        ],
      );
    }
    
    return child;
  }

  Widget _buildBlockedCard(BuildContext context, SecurityCheckResult result) {
    IconData icon;
    Color color;
    String title;
    
    switch (result.reason) {
      case SecurityDenialReason.kycRequired:
        icon = Icons.verified_user;
        color = Colors.orange;
        title = 'Vérification Requise';
        break;
      case SecurityDenialReason.walletFrozen:
        icon = Icons.lock;
        color = Colors.red;
        title = 'Portefeuille Gelé';
        break;
      case SecurityDenialReason.lowHonorScore:
        icon = Icons.trending_down;
        color = Colors.red;
        title = 'Score Insuffisant';
        break;
      default:
        icon = Icons.block;
        color = Colors.red;
        title = 'Accès Bloqué';
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            result.message ?? 'Vous ne pouvez pas rejoindre ce cercle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String warning) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warning,
              style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button that checks mutual follow before showing invite option
class MutualFollowInviteButton extends ConsumerWidget {
  final String targetUserId;
  final String targetUserName;
  final bool currentUserFollowsTarget;
  final bool targetFollowsCurrentUser;
  final VoidCallback onInvite;

  const MutualFollowInviteButton({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.currentUserFollowsTarget,
    required this.targetFollowsCurrentUser,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final securityNotifier = ref.read(securityProvider.notifier);
    
    final result = securityNotifier.checkMutualFollow(
      inviterId: user.phoneNumber,
      inviteeId: targetUserId,
      inviterFollowsInvitee: currentUserFollowsTarget,
      inviteeFollowsInviter: targetFollowsCurrentUser,
    );
    
    if (result.canInvite) {
      return ElevatedButton.icon(
        onPressed: onInvite,
        icon: const Icon(Icons.group_add, size: 18),
        label: const Text('Inviter à un Cercle'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.marineBlue,
        ),
      );
    }
    
    return _buildDisabledButton(context, result);
  }

  Widget _buildDisabledButton(BuildContext context, MutualFollowResult result) {
    return Tooltip(
      message: result.message ?? 'Suivi mutuel requis',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invitation impossible',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                Row(
                  children: [
                    Icon(
                      result.inviterFollowsInvitee ? Icons.check : Icons.close,
                      size: 12,
                      color: result.inviterFollowsInvitee ? Colors.green : Colors.red,
                    ),
                    Text(' Vous suivez ', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    Icon(
                      result.inviteeFollowsInviter ? Icons.check : Icons.close,
                      size: 12,
                      color: result.inviteeFollowsInviter ? Colors.green : Colors.red,
                    ),
                    Text(' Vous suit', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick report user button
class ReportUserButton extends StatelessWidget {
  final String userId;
  final String userName;
  final bool iconOnly;

  const ReportUserButton({
    super.key,
    required this.userId,
    required this.userName,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        icon: Icon(Icons.flag, color: Colors.red.shade400, size: 20),
        onPressed: () => _showReportDialog(context),
        tooltip: 'Signaler cet utilisateur',
      );
    }
    
    return TextButton.icon(
      onPressed: () => _showReportDialog(context),
      icon: Icon(Icons.flag, color: Colors.red.shade400, size: 18),
      label: Text('Signaler', style: TextStyle(color: Colors.red.shade400)),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => UserReportDialog(
        userId: userId,
        userName: userName,
      ),
    );
  }
}

/// User Report Dialog
class UserReportDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const UserReportDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserReportDialog> createState() => _UserReportDialogState();
}

class _UserReportDialogState extends State<UserReportDialog> {
  String? _selectedReason;
  final _detailsController = TextEditingController();

  final List<Map<String, dynamic>> _reasons = [
    {'id': 'scam', 'label': 'Arnaque / Escroquerie', 'icon': Icons.warning},
    {'id': 'harassment', 'label': 'Harcèlement', 'icon': Icons.person_off},
    {'id': 'fake_identity', 'label': 'Fausse identité', 'icon': Icons.badge},
    {'id': 'spam', 'label': 'Spam', 'icon': Icons.report},
    {'id': 'payment_fraud', 'label': 'Fraude au paiement', 'icon': Icons.money_off},
    {'id': 'other', 'label': 'Autre', 'icon': Icons.help_outline},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Signaler ${widget.userName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_reasons.map((r) => RadioListTile<String>(
              value: r['id'],
              // ignore: deprecated_member_use
              groupValue: _selectedReason,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _selectedReason = v),
              title: Row(
                children: [
                  Icon(r['icon'], size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(r['label']),
                ],
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ))),
            if (_selectedReason != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Détails (optionnel)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedReason != null ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Signaler'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Signalement envoyé. Nous allons examiner ce profil.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
