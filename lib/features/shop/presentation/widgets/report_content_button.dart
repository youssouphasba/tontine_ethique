import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/services/content_moderation_service.dart';
import 'package:tontetic/core/services/voice_service.dart';
import 'dart:async';

// Report Content Button
// Allows users to report inappropriate content
// 
// Features:
// - Multiple violation types
// - Optional description
// - Confirmation feedback

class ReportContentButton extends ConsumerWidget {
  final String contentId;
  final ContentType contentType;
  final String reporterId;
  final Color? iconColor;
  final double? iconSize;

  const ReportContentButton({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.reporterId,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.flag_outlined, color: iconColor ?? Colors.grey, size: iconSize ?? 24),
      tooltip: 'Signaler ce contenu',
      onPressed: () => _showReportDialog(context, ref),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    ViolationType? selectedType;
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Signaler ce contenu',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Pourquoi signalez-vous ce contenu ?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),

                // Violation types
                ..._buildViolationOptions(selectedType, (type) {
                  setState(() => selectedType = type);
                }),

                const SizedBox(height: 16),

                // Description options
                const Text('Décrivez le problème :', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                
                // Text input
                TextField(
                  controller: descController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Écrivez votre message',
                    hintText: 'Décrivez le problème...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 12),

                // Voice option
                Builder(
                  builder: (context) {
                    bool isRecording = false;
                    int recordingSeconds = 0;
                    bool hasVoiceMessage = false;

                    return StatefulBuilder(
                      builder: (context, setVoiceState) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRecording ? Colors.red.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isRecording ? Colors.red : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasVoiceMessage ? Icons.check_circle : Icons.mic,
                              color: hasVoiceMessage ? Colors.green : (isRecording ? Colors.red : Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: hasVoiceMessage
                                ? Row(
                                    children: [
                                      const Icon(Icons.graphic_eq, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text('Message vocal enregistré (${recordingSeconds}s)', 
                                        style: const TextStyle(color: Colors.green)),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => setVoiceState(() => hasVoiceMessage = false),
                                        child: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      ),
                                    ],
                                  )
                                : isRecording
                                  ? Row(
                                      children: [
                                        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(recordingSeconds % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () async {
                                            await ref.read(voiceServiceProvider).stopRecording();
                                            setVoiceState(() {
                                              isRecording = false;
                                              hasVoiceMessage = true;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Text('Stop', style: TextStyle(color: Colors.white, fontSize: 12)),
                                          ),
                                        ),
                                      ],
                                    )
                                   : GestureDetector(
                                      onTap: () async {
                                        final voiceService = ref.read(voiceServiceProvider);
                                        await voiceService.startRecording();
                                        
                                        setVoiceState(() {
                                          isRecording = true;
                                          recordingSeconds = 0;
                                        });

                                        Timer.periodic(const Duration(seconds: 1), (timer) {
                                          if (!isRecording) {
                                            timer.cancel();
                                            return;
                                          }
                                          setVoiceState(() => recordingSeconds++);
                                        });
                                      },
                                      child: const Text(
                                        'Ou enregistrez un message vocal',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Legal note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Votre signalement sera examiné par notre équipe de modération.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedType != null
                      ? () {
                          ContentModerationService().reportContent(
                            contentId: contentId,
                            contentType: contentType,
                            reporterId: reporterId,
                            violationType: selectedType!,
                            description: descController.text.isNotEmpty ? descController.text : null,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Merci ! Votre signalement a été envoyé.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Envoyer le signalement', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildViolationOptions(ViolationType? selected, Function(ViolationType) onSelect) {
    final options = [
      (ViolationType.fraud, '💰 Arnaque / Fraude', 'Produit trompeur ou mensonger'),
      (ViolationType.financialProduct, '📈 Produit financier interdit', 'Investissement, rendement, tontine'),
      (ViolationType.stolenContent, '📸 Contenu volé', 'Images ou vidéos non autorisées'),
      (ViolationType.drugs, '💊 Drogue / Médicaments', 'Substances interdites'),
      (ViolationType.weapons, '🔫 Armes', 'Vente d\'armes'),
      (ViolationType.nudity, '🔞 Contenu pour adultes', 'Pornographie ou nudité'),
      (ViolationType.hate, '🚫 Contenu haineux', 'Discrimination, racisme'),
      (ViolationType.misleading, '⚠️ Trompeur', 'Fausses promesses'),
      (ViolationType.spam, '📧 Spam', 'Contenu répétitif ou non sollicité'),
      (ViolationType.other, '❓ Autre', 'Autre raison'),
    ];

    return options.map((opt) => RadioListTile<ViolationType>(
      value: opt.$1,
      // ignore: deprecated_member_use
      groupValue: selected,
      // ignore: deprecated_member_use
      onChanged: (val) => onSelect(val!),
      title: Text(opt.$2, style: const TextStyle(fontSize: 14)),
      subtitle: Text(opt.$3, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    )).toList();
  }
}

/// Inline Report Button (smaller, for feeds)
class ReportContentIconButton extends StatelessWidget {
  final String contentId;
  final ContentType contentType;
  final String reporterId;

  const ReportContentIconButton({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.reporterId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showQuickReport(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.flag_outlined, color: Colors.white, size: 18),
      ),
    );
  }

  void _showQuickReport(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler ce contenu ?'),
        content: const Text('Ce contenu sera examiné par notre équipe de modération.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              ContentModerationService().reportContent(
                contentId: contentId,
                contentType: contentType,
                reporterId: reporterId,
                violationType: ViolationType.other,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signalement envoyé'), backgroundColor: Colors.orange),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Signaler', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
