import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/features/advertising/data/moderation_service.dart';

/// V11.4 - Transparency Report Generator
/// Compiles monthly statistics for regulatory compliance

class TransparencyReport {
  final String id;
  final DateTime generatedAt;
  final String period; // "Janvier 2026"
  final int periodMonth;
  final int periodYear;
  
  // 1. User Statistics
  final int totalUsers;
  final int individualUsers;
  final int businessUsers;
  final int newUsersThisMonth;
  final double engagementRate; // % in at least one circle
  
  // 2. Circle Activity
  final int totalCirclesCreated;
  final int circlesCompleted;
  final int circlesActive;
  final double averageCircleSize;
  
  // 3. Merchant Activity
  final int totalPublications;
  final int boostsActivated;
  final double boostRevenue; // in EUR
  final int clicksToCircles;
  final double conversionRate;
  
  // 4. Moderation Stats
  final int totalReports;
  final Map<ReportTag, int> reportsByTag;
  final int contentRemoved;
  final int contentRestored;
  final int averageResolutionMinutes;
  
  // 5. Compliance Stats
  final int kycSubmitted;
  final int kycApproved;
  final double kycSuccessRate;
  final int kybSubmitted;
  final int kybApproved;
  final int paymentIncidents;
  final double averageHonorScore;
  
  // 6. Health Score (0-100)
  final int ecosystemHealthScore;

  TransparencyReport({
    required this.id,
    required this.generatedAt,
    required this.period,
    required this.periodMonth,
    required this.periodYear,
    required this.totalUsers,
    required this.individualUsers,
    required this.businessUsers,
    required this.newUsersThisMonth,
    required this.engagementRate,
    required this.totalCirclesCreated,
    required this.circlesCompleted,
    required this.circlesActive,
    required this.averageCircleSize,
    required this.totalPublications,
    required this.boostsActivated,
    required this.boostRevenue,
    required this.clicksToCircles,
    required this.conversionRate,
    required this.totalReports,
    required this.reportsByTag,
    required this.contentRemoved,
    required this.contentRestored,
    required this.averageResolutionMinutes,
    required this.kycSubmitted,
    required this.kycApproved,
    required this.kycSuccessRate,
    required this.kybSubmitted,
    required this.kybApproved,
    required this.paymentIncidents,
    required this.averageHonorScore,
    required this.ecosystemHealthScore,
  });

  /// Generate report for a specific month
  static Future<TransparencyReport> generate({
    required int month,
    required int year,
  }) async {
    final months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];

    // In production: This should be a Cloud Function call or a sophisticated aggregation
    // For now, we return a initialized report with 0 values to avoid misleading "Demo" stats.
    
    return TransparencyReport(
      id: 'RPT-$year${month.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      period: '${months[month]} $year',
      periodMonth: month,
      periodYear: year,
      
      // Real stats - defaulted to 0 until Aggregation Service is ready
      totalUsers: 0, 
      individualUsers: 0,
      businessUsers: 0,
      newUsersThisMonth: 0,
      engagementRate: 0.0,
      
      // Circle stats
      totalCirclesCreated: 0,
      circlesCompleted: 0,
      circlesActive: 0,
      averageCircleSize: 0.0,
      
      // Merchant stats
      totalPublications: 0,
      boostsActivated: 0,
      boostRevenue: 0.0,
      clicksToCircles: 0,
      conversionRate: 0.0,
      
      // Moderation stats
      totalReports: 0,
      reportsByTag: {},
      contentRemoved: 0,
      contentRestored: 0,
      averageResolutionMinutes: 0,
      
      // Compliance stats
      kycSubmitted: 0,
      kycApproved: 0,
      kycSuccessRate: 0.0,
      kybSubmitted: 0,
      kybApproved: 0,
      paymentIncidents: 0,
      averageHonorScore: 0.0,
      
      // Health score
      ecosystemHealthScore: 100,
    );
  }

  /// Calculate health score based on metrics
  static int calculateHealthScore({
    required double kycSuccessRate,
    required int totalReports,
    required int totalUsers,
    required double engagementRate,
    required int paymentIncidents,
  }) {
    int score = 100;
    
    // Deduct for low KYC rate
    if (kycSuccessRate < 90) score -= 10;
    if (kycSuccessRate < 80) score -= 10;
    
    // Deduct for high report ratio
    final reportRatio = totalReports / totalUsers;
    if (reportRatio > 0.01) score -= 15;
    if (reportRatio > 0.02) score -= 15;
    
    // Deduct for low engagement
    if (engagementRate < 50) score -= 10;
    
    // Deduct for payment incidents
    score -= paymentIncidents * 5;
    
    return score.clamp(0, 100);
  }

  /// Get tag percentage for charts
  Map<String, double> get tagPercentages {
    final total = totalReports > 0 ? totalReports : 1;
    return reportsByTag.map((key, value) => 
      MapEntry(key.label, (value / total * 100).roundToDouble())
    );
  }
}

class ReportArchiveState {
  final List<TransparencyReport> reports;
  final bool isGenerating;

  ReportArchiveState({
    this.reports = const [],
    this.isGenerating = false,
  });

  ReportArchiveState copyWith({
    List<TransparencyReport>? reports,
    bool? isGenerating,
  }) {
    return ReportArchiveState(
      reports: reports ?? this.reports,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

class ReportArchiveNotifier extends StateNotifier<ReportArchiveState> {
  ReportArchiveNotifier() : super(ReportArchiveState()) {
    _loadDemoReports();
  }

  void _loadDemoReports() {
    // Demo data removed.
    // In production, reports are generated from real data aggregation.
  }

  Future<TransparencyReport> generateReport({
    required int month,
    required int year,
  }) async {
    state = state.copyWith(isGenerating: true);
    
    // Generation (Direct)

    
    final report = await TransparencyReport.generate(month: month, year: year);
    
    final updatedReports = [report, ...state.reports];
    state = state.copyWith(reports: updatedReports, isGenerating: false);
    
    return report;
  }

  TransparencyReport? getReport(String id) {
    try {
      return state.reports.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

final reportArchiveProvider = StateNotifierProvider<ReportArchiveNotifier, ReportArchiveState>((ref) {
  return ReportArchiveNotifier();
});
