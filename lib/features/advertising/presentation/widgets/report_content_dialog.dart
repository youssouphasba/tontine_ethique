import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/advertising/data/moderation_service.dart';

/// V11.3 - Quick Tag Report Dialog
/// 2-click maximum for fast reporting
class QuickReportDialog extends ConsumerStatefulWidget {
  final String contentId;
  final String merchantId;
  final String merchantName;
  final String contentTitle;
  final VoidCallback? onReported;

  const QuickReportDialog({
    super.key,
    required this.contentId,
    required this.merchantId,
    required this.merchantName,
    required this.contentTitle,
    this.onReported,
  });

  @override
  ConsumerState<QuickReportDialog> createState() => _QuickReportDialogState();
}

class _QuickReportDialogState extends ConsumerState<QuickReportDialog> {
  ReportTag? _selectedTag;
  final _commentController = TextEditingController();
  bool _showComment = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag, color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Signaler ce contenu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Tag Selection (Quick Chips)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sélectionnez le motif :',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  
                  // Critical Tags (Priority)
                  _buildTagSection('🚨 Prioritaires', [
                    ReportTag.arnaque,
                    ReportTag.produitInterdit,
                  ], isCritical: true),
                  
                  const SizedBox(height: 12),
                  
                  // Other Tags
                  _buildTagSection('📋 Autres', [
                    ReportTag.fakeProduct,
                    ReportTag.misleading,
                    ReportTag.inappropriate,
                    ReportTag.spam,
                    ReportTag.other,
                  ]),
                  
                  // Comment Section (Optional)
                  if (_selectedTag != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(() => _showComment = !_showComment),
                      child: Row(
                        children: [
                          Icon(
                            _showComment ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          Text(
                            'Ajouter un commentaire (optionnel)',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (_showComment) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 2,
                        maxLength: 200,
                        decoration: InputDecoration(
                          hintText: 'Décrivez le problème...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.all(12),
                          counterStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            
            // Submit Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedTag != null ? _submitReport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedTag?.isCritical == true 
                      ? Colors.red.shade700 
                      : AppTheme.marineBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _selectedTag?.isCritical == true 
                          ? 'SIGNALER (URGENT)' 
                          : 'ENVOYER LE SIGNALEMENT',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildTagSection(String title, List<ReportTag> tags, {bool isCritical = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isCritical ? Colors.red.shade700 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) => _buildTagChip(tag, isCritical: isCritical)).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(ReportTag tag, {bool isCritical = false}) {
    final isSelected = _selectedTag == tag;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTag = tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isCritical ? Colors.red.shade700 : AppTheme.marineBlue)
              : (isCritical ? Colors.red.shade50 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : (isCritical ? Colors.red.shade200 : Colors.grey.shade300),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.emoji,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected 
                    ? Colors.white 
                    : (isCritical ? Colors.red.shade700 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    final wasSuspended = await ref.read(moderationProvider.notifier).reportContent(
      contentId: widget.contentId,
      reporterId: 'current_user_${DateTime.now().millisecondsSinceEpoch}',
      tag: _selectedTag!,
      comment: _commentController.text.isNotEmpty ? _commentController.text : null,
      merchantId: widget.merchantId,
      merchantName: widget.merchantName,
      contentTitle: widget.contentTitle,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (wasSuspended) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(child: Text('🛡️ Contenu suspendu ! Merci pour votre vigilance.')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Signalement enregistré.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    widget.onReported?.call();
  }
}

/// Helper function to show quick report dialog
void showQuickReportDialog(
  BuildContext context, {
  required String contentId,
  required String merchantId,
  required String merchantName,
  required String contentTitle,
}) {
  showDialog(
    context: context,
    builder: (ctx) => QuickReportDialog(
      contentId: contentId,
      merchantId: merchantId,
      merchantName: merchantName,
      contentTitle: contentTitle,
    ),
  );
}
