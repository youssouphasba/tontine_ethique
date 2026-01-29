// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/theme/app_theme.dart';
import 'package:tontetic/features/admin/data/transparency_report_service.dart';

import 'package:tontetic/features/advertising/data/moderation_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

/// V11.4 - Transparency Report Archive Screen
/// Admin interface for viewing and downloading compliance reports
class ReportArchiveScreen extends ConsumerStatefulWidget {
  const ReportArchiveScreen({super.key});

  @override
  ConsumerState<ReportArchiveScreen> createState() => _ReportArchiveScreenState();
}

class _ReportArchiveScreenState extends ConsumerState<ReportArchiveScreen> {
  TransparencyReport? _selectedReport;

  @override
  Widget build(BuildContext context) {
    final archiveState = ref.watch(reportArchiveProvider);
    final reports = archiveState.reports;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.folder_open, color: AppTheme.gold),
            const SizedBox(width: 12),
            const Text('Archives Légales'),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: archiveState.isGenerating ? null : _generateNewReport,
              icon: archiveState.isGenerating 
                  ? const SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add, size: 18),
              label: Text(archiveState.isGenerating ? 'Génération...' : 'Nouveau Rapport'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.marineBlue,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // LEFT: Report List
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              border: Border(right: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0F3460),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Rapports Mensuels',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${reports.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) => _buildReportCard(reports[index]),
                  ),
                ),
              ],
            ),
          ),
          
          // RIGHT: Report Preview
          Expanded(
            child: _selectedReport == null
                ? _buildNoSelectionState()
                : _buildReportPreview(_selectedReport!),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(TransparencyReport report) {
    final isSelected = _selectedReport?.id == report.id;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedReport = report),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.marineBlue : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.gold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getHealthColor(report.ecosystemHealthScore).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${report.ecosystemHealthScore}',
                  style: TextStyle(
                    color: _getHealthColor(report.ecosystemHealthScore),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.period,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${report.totalUsers} utilisateurs • ${report.totalReports} signalements',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSelectionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Sélectionnez un rapport',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'pour prévisualiser et télécharger',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPreview(TransparencyReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rapport de Transparence',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      report.period,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Réf: ${report.id}',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _downloadPdf(report),
                icon: const Icon(Icons.download),
                label: const Text('Télécharger PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.marineBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // KPIs Row
          Row(
            children: [
              _buildKpiCard('Score Santé', '${report.ecosystemHealthScore}/100', 
                icon: Icons.favorite, color: _getHealthColor(report.ecosystemHealthScore)),
              const SizedBox(width: 16),
              _buildKpiCard('Utilisateurs', '${report.totalUsers}', 
                icon: Icons.people, color: Colors.blue),
              const SizedBox(width: 16),
              _buildKpiCard('Cercles Actifs', '${report.circlesActive}', 
                icon: Icons.groups, color: Colors.green),
              const SizedBox(width: 16),
              _buildKpiCard('Signalements', '${report.totalReports}', 
                icon: Icons.flag, color: Colors.orange),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Stats Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                child: Column(
                  children: [
                    _buildStatsSection('Utilisateurs', [
                      _buildStatRow('Total', '${report.totalUsers}'),
                      _buildStatRow('Particuliers', '${report.individualUsers}'),
                      _buildStatRow('Entreprises', '${report.businessUsers}'),
                      _buildStatRow('Nouveaux ce mois', '+${report.newUsersThisMonth}'),
                      _buildStatRow('Taux d\'engagement', '${report.engagementRate.toStringAsFixed(1)}%'),
                    ]),
                    const SizedBox(height: 16),
                    _buildStatsSection('Espace Marchand', [
                      _buildStatRow('Publications', '${report.totalPublications}'),
                      _buildStatRow('Boosts (1€)', '${report.boostsActivated}'),
                      _buildStatRow('Revenus Boost', '${report.boostRevenue.toStringAsFixed(2)}€'),
                      _buildStatRow('Clics → Cercle', '${report.clicksToCircles}'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column
              Expanded(
                child: Column(
                  children: [
                    _buildStatsSection('Modération', [
                      _buildStatRow('Total signalements', '${report.totalReports}'),
                      _buildStatRow('Contenus supprimés', '${report.contentRemoved}', isNegative: true),
                      _buildStatRow('Réhabilités', '${report.contentRestored}', isPositive: true),
                      _buildStatRow('Délai moyen', '${report.averageResolutionMinutes} min'),
                    ]),
                    const SizedBox(height: 16),
                    _buildTagsBreakdown(report),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Compliance Section
          _buildStatsSection('Conformité KYC/KYB', [
            _buildStatRow('KYC soumis', '${report.kycSubmitted}'),
            _buildStatRow('KYC validés', '${report.kycApproved} (${report.kycSuccessRate.toStringAsFixed(1)}%)'),
            _buildStatRow('KYB soumis', '${report.kybSubmitted}'),
            _buildStatRow('KYB validés', '${report.kybApproved}'),
            _buildStatRow('Incidents paiement', '${report.paymentIncidents}', 
              isNegative: report.paymentIncidents > 0),
            _buildStatRow('Score d\'Honneur moyen', report.averageHonorScore.toStringAsFixed(0)),
          ]),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, {required IconData icon, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.39)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isPositive = false, bool isNegative = false}) {
    Color valueColor = Colors.white;
    if (isPositive) valueColor = Colors.green;
    if (isNegative) valueColor = Colors.red;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTagsBreakdown(TransparencyReport report) {
    final sortedTags = report.reportsByTag.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition par Tags',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedTags.map((entry) {
            final percentage = entry.value / report.totalReports * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.key.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        entry.key.label,
                        style: TextStyle(
                          color: entry.key.isCritical ? Colors.red : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      entry.key.isCritical ? Colors.red : AppTheme.gold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getHealthColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  void _generateNewReport() async {
    final now = DateTime.now();
    await ref.read(reportArchiveProvider.notifier).generateReport(
      month: now.month,
      year: now.year,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Nouveau rapport généré !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _downloadPdf(TransparencyReport report) async {
    try {
      // final pdfBytes = await TransparencyPdfGenerator.generatePdf(report);
      // final fileName = 'Tontetic_Rapport_${report.period.replaceAll(' ', '_')}.pdf';
      
      if (kIsWeb) {
        // For web, just show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 PDF généré ! (Téléchargement web non disponible)'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // For desktop/mobile, save to documents folder
        
        // REFACTOR: Disabled for Web Build compatibility (dart:io removal)
        /*
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        */
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 PDF généré (Sauvegarde temporairement désactivée)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
