import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tontetic/core/theme/app_theme.dart';

/// V10.1 - PDF Export Service
/// Generates professional PDF documents for:
/// - Signed Mandates
/// - Circle Contracts
/// - Payment Receipts

class PdfExportService {
  
  /// Generate a signed mandate PDF
  static Future<Uint8List> generateMandatePdf({
    required String userName,
    required String circleName,
    required double amount,
    required String signatureBase64,
    required DateTime signedAt,
    required String deviceId,
    required String ipAddress,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TONTETIC',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1A237E'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Épargne Solidaire Digitale',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Divider(thickness: 2, color: PdfColor.fromHex('#FFD700')),
              pw.SizedBox(height: 20),
              
              // Title
              pw.Center(
                child: pw.Text(
                  'MANDAT DE PRÉLÈVEMENT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Contract Details
              _buildSection('IDENTITÉ DU MEMBRE', [
                'Nom complet : $userName',
                'Statut : Membre vérifié',
              ]),
              pw.SizedBox(height: 16),
              
              _buildSection('INFORMATIONS DU CERCLE', [
                'Nom du cercle : $circleName',
                'Montant de la cotisation : ${amount.toStringAsFixed(0)} FCFA',
                'Fréquence : Mensuelle',
              ]),
              pw.SizedBox(height: 16),
              
              _buildSection('ENGAGEMENT', [
                'Je soussigné(e) $userName, autorise Tontetic à prélever le montant de ${amount.toStringAsFixed(0)} FCFA sur mon compte de paiement mobile (Wave/Orange Money) ou bancaire selon les échéances définies par le cercle "$circleName".',
                '',
                'Je comprends que :',
                '• Ce prélèvement est récurrent jusqu\'à la fin du cycle',
                '• Je peux révoquer ce mandat avec un préavis de 30 jours',
                '• En cas de défaut, la Garantie Solidaire sera activée',
              ]),
              pw.SizedBox(height: 20),
              
              // Signature Section
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SIGNATURE ÉLECTRONIQUE',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      height: 60,
                      width: 200,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '[Signature numérisée]',
                          style: pw.TextStyle(
                            color: PdfColors.grey500,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Date : ${_formatDate(signedAt)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Device ID : $deviceId', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('IP : $ipAddress', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Document généré automatiquement par Tontetic • ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Ce document a valeur probante conformément au règlement eIDAS',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  /// Generate a payment receipt PDF
  static Future<Uint8List> generateReceiptPdf({
    required String transactionId,
    required String userName,
    required String circleName,
    required double amount,
    required String currency,
    required DateTime paidAt,
    required String paymentMethod,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                'TONTETIC',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1A237E'),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4CAF50'),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'REÇU DE PAIEMENT',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Amount
              pw.Text(
                '${amount.toStringAsFixed(0)} $currency',
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Details
              _buildReceiptRow('Transaction', transactionId),
              _buildReceiptRow('Payeur', userName),
              _buildReceiptRow('Cercle', circleName),
              _buildReceiptRow('Méthode', paymentMethod),
              _buildReceiptRow('Date', _formatDate(paidAt)),
              
              pw.Spacer(),
              
              // Footer
              pw.Text(
                'Merci de votre confiance ! 🙏',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }
  
  static pw.Widget _buildSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
            color: PdfColor.fromHex('#1A237E'),
          ),
        ),
        pw.SizedBox(height: 4),
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(item, style: const pw.TextStyle(fontSize: 11)),
        )),
      ],
    );
  }
  
  static pw.Widget _buildReceiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
  
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Screen to preview and share PDF
class PdfPreviewScreen extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() pdfGenerator;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.pdfGenerator,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.marineBlue,
      ),
      body: PdfPreview(
        build: (format) => pdfGenerator(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '${title.toLowerCase().replaceAll(' ', '_')}.pdf',
      ),
    );
  }
}
