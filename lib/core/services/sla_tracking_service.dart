import 'package:flutter/foundation.dart';

/// SLA Tracking Service - Service Level Agreement Monitoring
/// 
/// Monitors response times and escalates issues:
/// - First response SLA
/// - Resolution SLA
/// - Automatic escalation
/// - Priority-based timeouts

enum SlaType { firstResponse, resolution }
enum EscalationLevel { none, level1, level2, level3 }

class SlaConfig {
  final Duration firstResponseTarget;
  final Duration resolutionTarget;
  final Duration escalationLevel1;
  final Duration escalationLevel2;
  final Duration escalationLevel3;

  const SlaConfig({
    this.firstResponseTarget = const Duration(hours: 4),
    this.resolutionTarget = const Duration(hours: 24),
    this.escalationLevel1 = const Duration(hours: 6),
    this.escalationLevel2 = const Duration(hours: 12),
    this.escalationLevel3 = const Duration(hours: 24),
  });

  // Priority-based configs
  static SlaConfig forPriority(String priority) {
    switch (priority) {
      case 'urgent':
        return const SlaConfig(
          firstResponseTarget: Duration(minutes: 30),
          resolutionTarget: Duration(hours: 4),
          escalationLevel1: Duration(hours: 1),
          escalationLevel2: Duration(hours: 2),
          escalationLevel3: Duration(hours: 4),
        );
      case 'high':
        return const SlaConfig(
          firstResponseTarget: Duration(hours: 1),
          resolutionTarget: Duration(hours: 8),
          escalationLevel1: Duration(hours: 2),
          escalationLevel2: Duration(hours: 4),
          escalationLevel3: Duration(hours: 8),
        );
      case 'medium':
        return const SlaConfig(
          firstResponseTarget: Duration(hours: 4),
          resolutionTarget: Duration(hours: 24),
          escalationLevel1: Duration(hours: 6),
          escalationLevel2: Duration(hours: 12),
          escalationLevel3: Duration(hours: 24),
        );
      case 'low':
      default:
        return const SlaConfig(
          firstResponseTarget: Duration(hours: 8),
          resolutionTarget: Duration(hours: 48),
          escalationLevel1: Duration(hours: 12),
          escalationLevel2: Duration(hours: 24),
          escalationLevel3: Duration(hours: 48),
        );
    }
  }
}

class SlaStatus {
  final String ticketId;
  final SlaConfig config;
  final DateTime createdAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final EscalationLevel escalationLevel;
  final bool isBreached;
  final String? assignedTo;

  SlaStatus({
    required this.ticketId,
    required this.config,
    required this.createdAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.escalationLevel = EscalationLevel.none,
    this.isBreached = false,
    this.assignedTo,
  });

  Duration get timeElapsed => DateTime.now().difference(createdAt);
  
  Duration get timeToFirstResponse {
    if (firstResponseAt == null) return config.firstResponseTarget - timeElapsed;
    return firstResponseAt!.difference(createdAt);
  }

  Duration get timeToResolution {
    if (resolvedAt == null) return config.resolutionTarget - timeElapsed;
    return resolvedAt!.difference(createdAt);
  }

  double get firstResponseSlaPercent {
    if (firstResponseAt != null) {
      return (timeToFirstResponse.inMinutes / config.firstResponseTarget.inMinutes * 100).clamp(0, 200);
    }
    return (timeElapsed.inMinutes / config.firstResponseTarget.inMinutes * 100).clamp(0, 200);
  }

  double get resolutionSlaPercent {
    if (resolvedAt != null) {
      return (timeToResolution.inMinutes / config.resolutionTarget.inMinutes * 100).clamp(0, 200);
    }
    return (timeElapsed.inMinutes / config.resolutionTarget.inMinutes * 100).clamp(0, 200);
  }

  bool get isFirstResponseBreached => 
    firstResponseAt == null && timeElapsed > config.firstResponseTarget;

  bool get isResolutionBreached => 
    resolvedAt == null && timeElapsed > config.resolutionTarget;

  SlaStatus copyWith({
    DateTime? firstResponseAt,
    DateTime? resolvedAt,
    EscalationLevel? escalationLevel,
    bool? isBreached,
    String? assignedTo,
  }) {
    return SlaStatus(
      ticketId: ticketId,
      config: config,
      createdAt: createdAt,
      firstResponseAt: firstResponseAt ?? this.firstResponseAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      isBreached: isBreached ?? this.isBreached,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}

class EscalationEvent {
  final String id;
  final String ticketId;
  final EscalationLevel level;
  final DateTime escalatedAt;
  final String reason;
  final String? escalatedTo;
  final bool acknowledged;

  EscalationEvent({
    required this.id,
    required this.ticketId,
    required this.level,
    required this.escalatedAt,
    required this.reason,
    this.escalatedTo,
    this.acknowledged = false,
  });
}

class SlaTrackingService {
  static final SlaTrackingService _instance = SlaTrackingService._internal();
  factory SlaTrackingService() => _instance;
  SlaTrackingService._internal();

  final Map<String, SlaStatus> _slaStatuses = {};
  final List<EscalationEvent> _escalations = [];

  // Initialize SLA tracking for a ticket
  void startTracking(String ticketId, String priority) {
    final config = SlaConfig.forPriority(priority);
    _slaStatuses[ticketId] = SlaStatus(
      ticketId: ticketId,
      config: config,
      createdAt: DateTime.now(),
    );
    debugPrint('[SLA] Started tracking: $ticketId with $priority priority');
  }

  // Record first response
  void recordFirstResponse(String ticketId, String responder) {
    final status = _slaStatuses[ticketId];
    if (status == null || status.firstResponseAt != null) return;

    _slaStatuses[ticketId] = status.copyWith(
      firstResponseAt: DateTime.now(),
      assignedTo: responder,
    );
    debugPrint('[SLA] First response recorded for: $ticketId');
  }

  // Record resolution
  void recordResolution(String ticketId) {
    final status = _slaStatuses[ticketId];
    if (status == null || status.resolvedAt != null) return;

    _slaStatuses[ticketId] = status.copyWith(
      resolvedAt: DateTime.now(),
    );
    debugPrint('[SLA] Resolution recorded for: $ticketId');
  }

  // Check and perform escalations
  void checkEscalations() {
    for (final entry in _slaStatuses.entries) {
      final ticketId = entry.key;
      final status = entry.value;

      if (status.resolvedAt != null) continue;

      final elapsed = status.timeElapsed;
      EscalationLevel newLevel = EscalationLevel.none;
      String reason = '';

      if (elapsed > status.config.escalationLevel3) {
        newLevel = EscalationLevel.level3;
        reason = 'Dépassement critique - Plus de ${status.config.escalationLevel3.inHours}h sans résolution';
      } else if (elapsed > status.config.escalationLevel2) {
        newLevel = EscalationLevel.level2;
        reason = 'Escalade niveau 2 - Plus de ${status.config.escalationLevel2.inHours}h sans résolution';
      } else if (elapsed > status.config.escalationLevel1) {
        newLevel = EscalationLevel.level1;
        reason = 'Escalade niveau 1 - Plus de ${status.config.escalationLevel1.inHours}h sans résolution';
      }

      if (newLevel.index > status.escalationLevel.index) {
        _slaStatuses[ticketId] = status.copyWith(
          escalationLevel: newLevel,
          isBreached: newLevel.index >= 2,
        );

        _escalations.add(EscalationEvent(
          id: 'esc_${_escalations.length + 1}',
          ticketId: ticketId,
          level: newLevel,
          escalatedAt: DateTime.now(),
          reason: reason,
          escalatedTo: _getEscalationTarget(newLevel),
        ));

        debugPrint('[SLA] Escalation: $ticketId to level ${newLevel.index}');
      }
    }
  }

  String _getEscalationTarget(EscalationLevel level) {
    switch (level) {
      case EscalationLevel.none: return '';
      case EscalationLevel.level1: return 'Support Lead';
      case EscalationLevel.level2: return 'Support Manager';
      case EscalationLevel.level3: return 'Direction';
    }
  }

  // Get SLA status for a ticket
  SlaStatus? getStatus(String ticketId) => _slaStatuses[ticketId];

  // Get all active SLAs
  List<SlaStatus> getActiveSlAs() => 
    _slaStatuses.values.where((s) => s.resolvedAt == null).toList();

  // Get breached SLAs
  List<SlaStatus> getBreachedSlAs() =>
    _slaStatuses.values.where((s) => s.isBreached).toList();

  // Get escalation events
  List<EscalationEvent> getEscalations() => List.unmodifiable(_escalations);

  List<EscalationEvent> getPendingEscalations() =>
    _escalations.where((e) => !e.acknowledged).toList();

  // Acknowledge escalation
  void acknowledgeEscalation(String escalationId) {
    final index = _escalations.indexWhere((e) => e.id == escalationId);
    if (index == -1) return;

    _escalations[index] = EscalationEvent(
      id: _escalations[index].id,
      ticketId: _escalations[index].ticketId,
      level: _escalations[index].level,
      escalatedAt: _escalations[index].escalatedAt,
      reason: _escalations[index].reason,
      escalatedTo: _escalations[index].escalatedTo,
      acknowledged: true,
    );
    debugPrint('[SLA] Escalation acknowledged: $escalationId');
  }

  // Statistics
  Map<String, dynamic> getStats() {
    final all = _slaStatuses.values.toList();
    final resolved = all.where((s) => s.resolvedAt != null).toList();
    final breached = all.where((s) => s.isBreached).length;
    
    // Calculate averages
    Duration totalFirstResponse = Duration.zero;
    Duration totalResolution = Duration.zero;
    int firstResponseCount = 0;
    int resolutionCount = 0;

    for (final s in resolved) {
      if (s.firstResponseAt != null) {
        totalFirstResponse += s.firstResponseAt!.difference(s.createdAt);
        firstResponseCount++;
      }
      totalResolution += s.resolvedAt!.difference(s.createdAt);
      resolutionCount++;
    }

    final avgFirstResponse = firstResponseCount > 0 
      ? Duration(seconds: totalFirstResponse.inSeconds ~/ firstResponseCount)
      : Duration.zero;
    final avgResolution = resolutionCount > 0
      ? Duration(seconds: totalResolution.inSeconds ~/ resolutionCount)
      : Duration.zero;

    // SLA compliance
    int metFirstResponseSla = 0;
    int metResolutionSla = 0;

    for (final s in resolved) {
      if (s.firstResponseAt != null && 
          s.firstResponseAt!.difference(s.createdAt) <= s.config.firstResponseTarget) {
        metFirstResponseSla++;
      }
      if (s.resolvedAt!.difference(s.createdAt) <= s.config.resolutionTarget) {
        metResolutionSla++;
      }
    }

    return {
      'totalTracked': all.length,
      'activeTickets': all.where((s) => s.resolvedAt == null).length,
      'resolvedTickets': resolved.length,
      'breachedTickets': breached,
      'avgFirstResponse': '${avgFirstResponse.inMinutes} min',
      'avgResolution': '${avgResolution.inHours}h ${avgResolution.inMinutes % 60}min',
      'firstResponseCompliance': resolved.isEmpty ? '100%' : '${(metFirstResponseSla / resolved.length * 100).toStringAsFixed(1)}%',
      'resolutionCompliance': resolved.isEmpty ? '100%' : '${(metResolutionSla / resolved.length * 100).toStringAsFixed(1)}%',
      'pendingEscalations': getPendingEscalations().length,
      'level1Escalations': _escalations.where((e) => e.level == EscalationLevel.level1).length,
      'level2Escalations': _escalations.where((e) => e.level == EscalationLevel.level2).length,
      'level3Escalations': _escalations.where((e) => e.level == EscalationLevel.level3).length,
    };
  }

  String formatDuration(Duration d) {
    if (d.isNegative) return 'Dépassé !';
    if (d.inDays > 0) return '${d.inDays}j ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }

  String getEscalationLevelLabel(EscalationLevel level) {
    switch (level) {
      case EscalationLevel.none: return 'Normal';
      case EscalationLevel.level1: return '⚠️ Niveau 1';
      case EscalationLevel.level2: return '🔶 Niveau 2';
      case EscalationLevel.level3: return '🔴 Niveau 3 (Critique)';
    }
  }

  // ============ EXPORT METHODS ============

  /// Export SLA status to JSON
  Map<String, dynamic> slaStatusToJson(SlaStatus status) {
    return {
      'ticketId': status.ticketId,
      'createdAt': status.createdAt.toIso8601String(),
      'firstResponseAt': status.firstResponseAt?.toIso8601String(),
      'resolvedAt': status.resolvedAt?.toIso8601String(),
      'escalationLevel': status.escalationLevel.name,
      'isBreached': status.isBreached,
      'assignedTo': status.assignedTo,
      'timeElapsedMinutes': status.timeElapsed.inMinutes,
      'firstResponseSlaPercent': status.firstResponseSlaPercent,
      'resolutionSlaPercent': status.resolutionSlaPercent,
      'isFirstResponseBreached': status.isFirstResponseBreached,
      'isResolutionBreached': status.isResolutionBreached,
    };
  }

  /// Export all SLA statuses to JSON
  List<Map<String, dynamic>> exportToJson() {
    return _slaStatuses.values.map(slaStatusToJson).toList();
  }

  /// Export all SLA data to CSV format
  String exportToCsv() {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('TicketId,CreatedAt,FirstResponseAt,ResolvedAt,EscalationLevel,IsBreached,AssignedTo,TimeElapsedMin,FirstResponseSLA%,ResolutionSLA%');
    
    // Data rows
    for (final s in _slaStatuses.values) {
      buffer.writeln(
        '"${s.ticketId}","${s.createdAt.toIso8601String()}","${s.firstResponseAt?.toIso8601String() ?? ''}","${s.resolvedAt?.toIso8601String() ?? ''}","${s.escalationLevel.name}","${s.isBreached}","${s.assignedTo ?? ''}","${s.timeElapsed.inMinutes}","${s.firstResponseSlaPercent.toStringAsFixed(1)}","${s.resolutionSlaPercent.toStringAsFixed(1)}"'
      );
    }
    return buffer.toString();
  }

  /// Export escalations to JSON
  List<Map<String, dynamic>> exportEscalationsToJson() {
    return _escalations.map((e) => {
      'id': e.id,
      'ticketId': e.ticketId,
      'level': e.level.name,
      'escalatedAt': e.escalatedAt.toIso8601String(),
      'reason': e.reason,
      'escalatedTo': e.escalatedTo,
      'acknowledged': e.acknowledged,
    }).toList();
  }

  /// Export stats to JSON
  Map<String, dynamic> exportStatsToJson() {
    final stats = getStats();
    stats['exportDate'] = DateTime.now().toIso8601String();
    return stats;
  }
}
