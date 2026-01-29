import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/core/providers/user_provider.dart';

/// V11.2 - Merchant Charter Signature Screen
/// Blocks first publication until charter is signed
class MerchantCharterScreen extends ConsumerStatefulWidget {
  final VoidCallback onSigned;
  
  const MerchantCharterScreen({super.key, required this.onSigned});

  @override
  ConsumerState<MerchantCharterScreen> createState() => _MerchantCharterScreenState();
}

class _MerchantCharterScreenState extends ConsumerState<MerchantCharterScreen> {
  bool _hasRead = false;
  bool _hasAgreed = false;
  final List<Offset> _signaturePoints = [];


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Charte Marchand'),
        backgroundColor: AppTheme.marineBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Warning Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vous devez signer cette charte avant de publier votre première annonce.',
                    style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          
          // Charter Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('📜 Charte de Modération et d\'Éthique Marchand', null),
                  
                  _buildSection('1. Qualité des Visuels 🎥', 
                    '• Les photos/vidéos doivent représenter le produit réel\n'
                    '• Aucun contenu violent, haineux ou à caractère sexuel\n'
                    '• Format recommandé : vertical (9:16), HD'),
                  
                  _buildSection('2. Transparence de l\'Offre 💰',
                    '• Prix clair sans frais cachés\n'
                    '• Stock disponible ou capacité de livraison garantie\n'
                    '• Mention "Sponsorisé" obligatoire sur les Boosts'),
                  
                  _buildSection('3. Engagement Client 🤝',
                    '• Réponse aux messages sous 48h ouvrées\n'
                    '• Aucune manipulation du Score d\'Honneur\n'
                    '• Responsabilité totale de la livraison'),
                  
                  _buildSection('4. Produits Interdits 🚫',
                    '• Armes, drogues, substances illicites\n'
                    '• Médicaments non régulés\n'
                    '• Schémas pyramidaux\n'
                    '• Produits contrefaits'),
                  
                  const SizedBox(height: 24),
                  
                  // Checkboxes
                  CheckboxListTile(
                    value: _hasRead,
                    onChanged: (v) => setState(() => _hasRead = v ?? false),
                    title: const Text('J\'ai lu et compris la charte complète'),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.marineBlue,
                  ),
                  
                  CheckboxListTile(
                    value: _hasAgreed,
                    onChanged: _hasRead ? (v) => setState(() => _hasAgreed = v ?? false) : null,
                    title: const Text('Je m\'engage à respecter ces règles'),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.marineBlue,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Signature Area
                  if (_hasAgreed) ...[
                    const Text('Signez ci-dessous :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.marineBlue, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            // _isSigning = true; - UNUSED
                            _signaturePoints.add(details.localPosition);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _signaturePoints.add(details.localPosition);
                          });
                        },
                        onPanEnd: (_) {
                          setState(() {
                            _signaturePoints.add(Offset.infinite); // Separator
                          });
                        },
                        child: CustomPaint(
                          painter: SignaturePainter(_signaturePoints),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _signaturePoints.clear()),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Effacer'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Merchant Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entreprise : ${user.displayName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text('Date : ${DateTime.now().toString().substring(0, 16)}'),
                          Text('ID : ${user.phoneNumber.hashCode}'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Submit Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_hasRead && _hasAgreed && _signaturePoints.length > 10) 
                  ? _submitSignature 
                  : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.marineBlue,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SIGNER ET ACCEPTER LA CHARTE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String? content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.marineBlue)),
          if (content != null) ...[
            const SizedBox(height: 8),
            Text(content, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
          ],
        ],
      ),
    );
  }

  void _submitSignature() {
    // Save signature state
    ref.read(userProvider.notifier).signMerchantCharter();
    
    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Charte signée ! Vous pouvez maintenant publier.'),
        backgroundColor: Colors.green,
      ),
    );
    
    widget.onSigned();
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.marineBlue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
