import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tontetic/features/admin/data/transparency_report_service.dart';
import 'package:tontetic/features/advertising/data/moderation_service.dart';

/// V11.4 - PDF Report Generator for Transparency Reports
/// Creates professional PDF documents for regulatory compliance

class TransparencyPdfGenerator {
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF1E3A5F);
  static const PdfColor _goldColor = PdfColor.fromInt(0xFFD4AF37);
  static const PdfColor _greenColor = PdfColor.fromInt(0xFF27AE60);
  static const PdfColor _redColor = PdfColor.fromInt(0xFFE74C3C);
  static const PdfColor _grayColor = PdfColor.fromInt(0xFF7F8C8D);

  /// Generate PDF from TransparencyReport
  static Future<Uint8List> generatePdf(TransparencyReport report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(report, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildExecutiveSummary(report),
          pw.SizedBox(height: 20),
          _buildUserStats(report),
          pw.SizedBox(height: 20),
          _buildCircleStats(report),
          pw.SizedBox(height: 20),
          _buildMerchantStats(report),
          pw.SizedBox(height: 20),
          _buildModerationStats(report),
          pw.SizedBox(height: 20),
          _buildComplianceStats(report),
          pw.SizedBox(height: 20),
          _buildConclusion(report),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(TransparencyReport report, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TONTETIC',
                style: pw.TextStyle(
                  color: _goldColor,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Rapport de Transparence',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 14),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                report.period,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Réf: ${report.id}',
                style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Document confidentiel - Usage interne et réglementaire uniquement',
            style: pw.TextStyle(color: _grayColor, fontSize: 8),
          ),
          pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(color: _grayColor, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(TransparencyReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _goldColor, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('1. Résumé Exécutif'),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildKpiBox('Score de Santé', '${report.ecosystemHealthScore}/100', 
                color: report.ecosystemHealthScore >= 80 ? _greenColor : _redColor),
              _buildKpiBox('Utilisateurs Actifs', '${report.totalUsers}', color: _primaryColor),
              _buildKpiBox('Circles Actifs', '${report.circlesActive}', color: _primaryColor),
              _buildKpiBox('Signalements', '${report.totalReports}', 
                color: report.totalReports > 100 ? _redColor : _greenColor),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildUserStats(TransparencyReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('2. Statistiques d\'Utilisation'),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildTableHeader(['Indicateur', 'Valeur', 'Évolution']),
            _buildTableRow(['Utilisateurs totaux', '${report.totalUsers}', '+${report.newUsersThisMonth} ce mois']),
            _buildTableRow(['Comptes Particuliers', '${report.individualUsers}', '${(report.individualUsers / report.totalUsers * 100).toStringAsFixed(1)}%']),
            _buildTableRow(['Comptes Entreprise', '${report.businessUsers}', '${(report.businessUsers / report.totalUsers * 100).toStringAsFixed(1)}%']),
            _buildTableRow(['Taux d\'engagement', '${report.engagementRate.toStringAsFixed(1)}%', 'Actifs dans ≥1 cercle']),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCircleStats(TransparencyReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('3. Activité des Cercles'),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildTableHeader(['Indicateur', 'Valeur', 'Note']),
            _buildTableRow(['Cercles créés', '${report.totalCirclesCreated}', 'Total cumulé']),
            _buildTableRow(['Cercles terminés', '${report.circlesCompleted}', 'Avec succès']),
            _buildTableRow(['Cercles actifs', '${report.circlesActive}', 'En cours']),
            _buildTableRow(['Taille moyenne', '${report.averageCircleSize.toStringAsFixed(1)} membres', 'Par cercle']),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMerchantStats(TransparencyReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('4. Espace Marchand'),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildTableHeader(['Indicateur', 'Valeur', 'Revenu/Impact']),
            _buildTableRow(['Publications', '${report.totalPublications}', 'Photos/Vidéos']),
            _buildTableRow(['Boosts activés', '${report.boostsActivated}', '${report.boostRevenue.toStringAsFixed(2)}€']),
            _buildTableRow(['Clics vers cercles', '${report.clicksToCircles}', 'Conversions']),
            _buildTableRow(['Taux de conversion', '${report.conversionRate.toStringAsFixed(1)}%', 'Clic → Cercle']),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildModerationStats(TransparencyReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('5. Rapport de Modération & Sécurité', isCritical: true),
        pw.SizedBox(height: 12),
        
        // Summary row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildKpiBox('Signalements', '${report.totalReports}', color: _primaryColor),
            _buildKpiBox('Supprimés', '${report.contentRemoved}', color: _redColor),
            _buildKpiBox('Réhabilités', '${report.contentRestored}', color: _greenColor),
            _buildKpiBox('Délai moyen', '${report.averageResolutionMinutes} min', color: _grayColor),
          ],
        ),
        
        pw.SizedBox(height: 16),
        
        // Tags breakdown
        pw.Text('Répartition par Tags:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildTableHeader(['Tag', 'Nombre', 'Pourcentage']),
            ...report.reportsByTag.entries.map((e) => 
              _buildTableRow([
                e.key.label,
                '${e.value}',
                '${(e.value / report.totalReports * 100).toStringAsFixed(1)}%'
              ])
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildComplianceStats(TransparencyReport report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('6. Conformité KYC/KYB'),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _buildTableHeader(['Vérification', 'Soumis', 'Validés', 'Taux']),
            _buildTableRow([
              'KYC (Particuliers)', 
              '${report.kycSubmitted}', 
              '${report.kycApproved}',
              '${report.kycSuccessRate.toStringAsFixed(1)}%'
            ]),
            _buildTableRow([
              'KYB (Entreprises)', 
              '${report.kybSubmitted}', 
              '${report.kybApproved}',
              '${(report.kybApproved / report.kybSubmitted * 100).toStringAsFixed(1)}%'
            ]),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildKpiBox('Incidents Paiement', '${report.paymentIncidents}', 
              color: report.paymentIncidents == 0 ? _greenColor : _redColor),
            _buildKpiBox('Score d\'Honneur Moyen', report.averageHonorScore.toStringAsFixed(0), 
              color: _goldColor),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildConclusion(TransparencyReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('7. Conclusion et Engagements'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Déclaration de Conformité',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Tontetic certifie agir en qualité d\'intermédiaire technique et confirme la non-détention '
            'des fonds des utilisateurs. Toutes les transactions financières transitent directement '
            'via les infrastructures sécurisées de Stripe (Zone Euro) et Wave (Zone FCFA).',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Actions Correctives Prévues',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Bullet(text: 'Renforcement de la modération sur les tags #Arnaque et #ProduitInterdit'),
          pw.Bullet(text: 'Amélioration du délai de traitement des signalements (objectif: < 30 min)'),
          pw.Bullet(text: 'Campagne de sensibilisation des marchands sur la Charte de Modération'),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Généré automatiquement le'),
                  pw.Text(
                    '${report.generatedAt.day}/${report.generatedAt.month}/${report.generatedAt.year} à ${report.generatedAt.hour}:${report.generatedAt.minute.toString().padLeft(2, '0')}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  static pw.Widget _buildSectionTitle(String title, {bool isCritical = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: isCritical ? _redColor : _primaryColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildKpiBox(String label, String value, {required PdfColor color}) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: _grayColor),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.TableRow _buildTableHeader(List<String> cells) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _primaryColor),
      children: cells.map((cell) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          cell,
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      )).toList(),
    );
  }

  static pw.TableRow _buildTableRow(List<String> cells) {
    return pw.TableRow(
      children: cells.map((cell) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(cell, style: const pw.TextStyle(fontSize: 10)),
      )).toList(),
    );
  }
}
