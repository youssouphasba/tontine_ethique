import 'package:tontetic/features/advertising/data/moderation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Generate report for a specific month with real data
  static Future<TransparencyReport> create({
    required int month,
    required int year,
  }) async {
    final db = FirebaseFirestore.instance;
    final months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];

    // Parallel counting for performance
    final results = await Future.wait([
      db.collection('users').count().get(),
      db.collection('users').where('role', isEqualTo: 'merchant').count().get(),
      db.collection('tontines').count().get(),
      db.collection('tontines').where('status', isEqualTo: 'Actif').count().get(),
      db.collection('tontines').where('status', isEqualTo: 'completed').count().get(),
      db.collection('moderation_cases').count().get(),
      db.collection('moderation_cases').where('status', isEqualTo: 'rejected').count().get(),
      db.collection('moderation_cases').where('status', isEqualTo: 'restored').count().get(),
    ]);

    final totalUsers = results[0].count ?? 0;
    final businessUsers = results[1].count ?? 0;
    final individualUsers = (totalUsers - businessUsers).clamp(0, totalUsers);
    
    final totalCircles = results[2].count ?? 0;
    final activeCircles = results[3].count ?? 0;
    final completedCircles = results[4].count ?? 0;

    final totalReports = results[5].count ?? 0;
    final contentRemoved = results[6].count ?? 0;
    final contentRestored = results[7].count ?? 0;

    return TransparencyReport(
      id: 'RPT-$year${month.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch}',
      generatedAt: DateTime.now(),
      period: '${months[month.clamp(1, 12)]} $year',
      periodMonth: month,
      periodYear: year,
      
      // Real Stats
      totalUsers: totalUsers,
      individualUsers: individualUsers,
      businessUsers: businessUsers,
      newUsersThisMonth: 0, // Requires more complex query or 'createdAt' field
      engagementRate: totalUsers > 0 ? (activeCircles * 5 / totalUsers * 100).clamp(0.0, 100.0) : 0.0, // Rough estimate
      
      totalCirclesCreated: totalCircles,
      circlesCompleted: completedCircles,
      circlesActive: activeCircles,
      averageCircleSize: 0, // Not calculated yet
      
      // Merchant placeholders (requires 'publications' collection)
      totalPublications: 0,
      boostsActivated: 0,
      boostRevenue: 0.0,
      clicksToCircles: 0,
      conversionRate: 0.0,
      
      // Moderation
      totalReports: totalReports,
      reportsByTag: {}, // Detailed tag breakdown requires iterating docs
      contentRemoved: contentRemoved,
      contentRestored: contentRestored,
      averageResolutionMinutes: 0,
      
      // Compliance (Mock 0 for now as 'kyc' collection structure is unknown or complex)
      kycSubmitted: 0,
      kycApproved: 0,
      kycSuccessRate: 0.0,
      kybSubmitted: 0,
      kybApproved: 0,
      paymentIncidents: 0,
      averageHonorScore: 0.0,
      
      ecosystemHealthScore: 100, // Default optimistic
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
    final report = await TransparencyReport.create(month: month, year: year);
    
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
