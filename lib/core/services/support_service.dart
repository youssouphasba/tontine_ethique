import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Support Service - Ticket System for User Support
/// 
/// Handles support tickets from users with:
/// - Ticket creation and tracking (Firestore-backed)
/// - Admin responses
/// - Priority management
/// - SLA tracking

enum TicketStatus { open, inProgress, waitingUser, resolved, closed }
enum TicketPriority { low, medium, high, urgent }
enum TicketCategory { general, payment, circle, merchant, subscription, technical, other }

class SupportTicket {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final TicketCategory category;
  final String subject;
  final List<TicketMessage> messages;
  final TicketStatus status;
  final TicketPriority priority;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? assignedAdmin;
  final int satisfactionRating; // 1-5, 0 = not rated

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.category,
    required this.subject,
    required this.messages,
    this.status = TicketStatus.open,
    this.priority = TicketPriority.medium,
    required this.createdAt,
    this.resolvedAt,
    this.assignedAdmin,
    this.satisfactionRating = 0,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      category: TicketCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => TicketCategory.general,
      ),
      subject: data['subject'] ?? '',
      messages: (data['messages'] as List<dynamic>? ?? [])
          .map((m) => TicketMessage.fromMap(m))
          .toList(),
      status: TicketStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TicketStatus.open,
      ),
      priority: TicketPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TicketPriority.medium,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      assignedAdmin: data['assignedAdmin'],
      satisfactionRating: data['satisfactionRating'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'category': category.name,
      'subject': subject,
      'messages': messages.map((m) => m.toMap()).toList(),
      'status': status.name,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'assignedAdmin': assignedAdmin,
      'satisfactionRating': satisfactionRating,
    };
  }

  SupportTicket copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    List<TicketMessage>? messages,
    String? assignedAdmin,
    DateTime? resolvedAt,
    int? satisfactionRating,
  }) {
    return SupportTicket(
      id: id,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      category: category,
      subject: subject,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      assignedAdmin: assignedAdmin ?? this.assignedAdmin,
      satisfactionRating: satisfactionRating ?? this.satisfactionRating,
    );
  }

  Duration get responseTime {
    if (messages.length < 2) return Duration.zero;
    final firstUserMsg = messages.first;
    final firstAdminMsg = messages.firstWhere(
      (m) => m.isFromAdmin,
      orElse: () => firstUserMsg,
    );
    return firstAdminMsg.timestamp.difference(firstUserMsg.timestamp);
  }

  Duration get resolutionTime {
    if (resolvedAt == null) return Duration.zero;
    return resolvedAt!.difference(createdAt);
  }
}

class TicketMessage {
  final String id;
  final String content;
  final bool isFromAdmin;
  final String senderName;
  final DateTime timestamp;
  final List<String> attachmentUrls;

  TicketMessage({
    required this.id,
    required this.content,
    required this.isFromAdmin,
    required this.senderName,
    required this.timestamp,
    this.attachmentUrls = const [],
  });

  factory TicketMessage.fromMap(Map<String, dynamic> map) {
    return TicketMessage(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      isFromAdmin: map['isFromAdmin'] ?? false,
      senderName: map['senderName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachmentUrls: List<String>.from(map['attachmentUrls'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'isFromAdmin': isFromAdmin,
      'senderName': senderName,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachmentUrls': attachmentUrls,
    };
  }
}

class SupportStats {
  final int totalTickets;
  final int openTickets;
  final int inProgressTickets;
  final int resolvedToday;
  final Duration avgResponseTime;
  final Duration avgResolutionTime;
  final double satisfactionScore;
  final Map<TicketCategory, int> ticketsByCategory;

  SupportStats({
    required this.totalTickets,
    required this.openTickets,
    required this.inProgressTickets,
    required this.resolvedToday,
    required this.avgResponseTime,
    required this.avgResolutionTime,
    required this.satisfactionScore,
    required this.ticketsByCategory,
  });
}

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'support_tickets';

  // ============ FIRESTORE QUERIES ============

  /// Get all tickets from Firestore
  Future<List<SupportTicket>> getAllTickets() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[Support] Error fetching tickets: $e');
      return [];
    }
  }

  /// Get tickets for a specific user
  Future<List<SupportTicket>> getUserTickets(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[Support] Error fetching user tickets: $e');
      return [];
    }
  }

  /// Get open tickets
  Future<List<SupportTicket>> getOpenTickets() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[Support] Error fetching open tickets: $e');
      return [];
    }
  }

  /// Get tickets by status
  Future<List<SupportTicket>> getTicketsByStatus(TicketStatus status) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[Support] Error fetching tickets by status: $e');
      return [];
    }
  }

  /// Get tickets by priority
  Future<List<SupportTicket>> getTicketsByPriority(TicketPriority priority) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('priority', isEqualTo: priority.name)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[Support] Error fetching tickets by priority: $e');
      return [];
    }
  }

  /// Get ticket by ID
  Future<SupportTicket?> getTicketById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return SupportTicket.fromFirestore(doc);
    } catch (e) {
      debugPrint('[Support] Error fetching ticket: $e');
      return null;
    }
  }

  /// Stream tickets for real-time updates
  Stream<List<SupportTicket>> streamAllTickets() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList());
  }

  /// Stream user's tickets
  Stream<List<SupportTicket>> streamUserTickets(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList());
  }

  // ============ CRUD OPERATIONS ============

  /// Create a new ticket
  Future<String?> createTicket({
    required String userId,
    required String userEmail,
    required String userName,
    required TicketCategory category,
    required String subject,
    required String message,
  }) async {
    try {
      final docRef = await _firestore.collection(_collection).add({
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'category': category.name,
        'subject': subject,
        'messages': [
          {
            'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
            'content': message,
            'isFromAdmin': false,
            'senderName': userName,
            'timestamp': Timestamp.now(),
            'attachmentUrls': [],
          }
        ],
        'status': TicketStatus.open.name,
        'priority': TicketPriority.medium.name,
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'assignedAdmin': null,
        'satisfactionRating': 0,
      });
      debugPrint('[Support] Ticket created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[Support] Error creating ticket: $e');
      return null;
    }
  }

  /// Reply to ticket
  Future<bool> replyToTicket(String ticketId, String message, String adminName) async {
    try {
      final newMessage = {
        'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
        'content': message,
        'isFromAdmin': true,
        'senderName': adminName,
        'timestamp': Timestamp.now(),
        'attachmentUrls': [],
      };

      await _firestore.collection(_collection).doc(ticketId).update({
        'messages': FieldValue.arrayUnion([newMessage]),
        'status': TicketStatus.waitingUser.name,
        'assignedAdmin': adminName,
      });
      debugPrint('[Support] Reply added to ticket: $ticketId');
      return true;
    } catch (e) {
      debugPrint('[Support] Error replying to ticket: $e');
      return false;
    }
  }

  /// Update ticket status
  Future<bool> updateTicketStatus(String ticketId, TicketStatus status) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
      };
      if (status == TicketStatus.resolved) {
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection(_collection).doc(ticketId).update(updates);
      debugPrint('[Support] Ticket $ticketId status updated to: $status');
      return true;
    } catch (e) {
      debugPrint('[Support] Error updating ticket status: $e');
      return false;
    }
  }

  /// Update ticket priority
  Future<bool> updateTicketPriority(String ticketId, TicketPriority priority) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'priority': priority.name,
      });
      debugPrint('[Support] Ticket $ticketId priority updated to: $priority');
      return true;
    } catch (e) {
      debugPrint('[Support] Error updating ticket priority: $e');
      return false;
    }
  }

  /// Close ticket with optional rating
  Future<bool> closeTicket(String ticketId, {int? satisfactionRating}) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'status': TicketStatus.closed.name,
        'resolvedAt': FieldValue.serverTimestamp(),
        if (satisfactionRating != null) 'satisfactionRating': satisfactionRating,
      });
      debugPrint('[Support] Ticket closed: $ticketId');
      return true;
    } catch (e) {
      debugPrint('[Support] Error closing ticket: $e');
      return false;
    }
  }

  // ============ STATISTICS ============

  /// Get statistics from Firestore
  Future<SupportStats> getStats() async {
    try {
      final allTickets = await getAllTickets();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final openCount = allTickets.where((t) => t.status == TicketStatus.open).length;
      final inProgressCount = allTickets.where((t) => t.status == TicketStatus.inProgress).length;
      final resolvedTodayCount = allTickets.where((t) => 
        t.status == TicketStatus.resolved && 
        t.resolvedAt != null && 
        t.resolvedAt!.isAfter(todayStart)
      ).length;

      // Calculate average response time
      final ticketsWithResponse = allTickets.where((t) => t.messages.length >= 2);
      final totalResponseTime = ticketsWithResponse.fold<Duration>(
        Duration.zero,
        (total, t) => total + t.responseTime,
      );
      final avgResponse = ticketsWithResponse.isEmpty 
        ? Duration.zero 
        : Duration(seconds: totalResponseTime.inSeconds ~/ ticketsWithResponse.length);

      // Calculate average resolution time
      final resolvedTickets = allTickets.where((t) => t.resolvedAt != null);
      final totalResolutionTime = resolvedTickets.fold<Duration>(
        Duration.zero,
        (total, t) => total + t.resolutionTime,
      );
      final avgResolution = resolvedTickets.isEmpty 
        ? Duration.zero 
        : Duration(seconds: totalResolutionTime.inSeconds ~/ resolvedTickets.length);

      // Calculate satisfaction
      final ratedTickets = allTickets.where((t) => t.satisfactionRating > 0);
      final totalSatisfaction = ratedTickets.fold<int>(0, (total, t) => total + t.satisfactionRating);
      final avgSatisfaction = ratedTickets.isEmpty ? 0.0 : totalSatisfaction / ratedTickets.length;

      // Categories breakdown
      final byCategory = <TicketCategory, int>{};
      for (final cat in TicketCategory.values) {
        byCategory[cat] = allTickets.where((t) => t.category == cat).length;
      }

      return SupportStats(
        totalTickets: allTickets.length,
        openTickets: openCount,
        inProgressTickets: inProgressCount,
        resolvedToday: resolvedTodayCount,
        avgResponseTime: avgResponse,
        avgResolutionTime: avgResolution,
        satisfactionScore: avgSatisfaction,
        ticketsByCategory: byCategory,
      );
    } catch (e) {
      debugPrint('[Support] Error calculating stats: $e');
      return SupportStats(
        totalTickets: 0,
        openTickets: 0,
        inProgressTickets: 0,
        resolvedToday: 0,
        avgResponseTime: Duration.zero,
        avgResolutionTime: Duration.zero,
        satisfactionScore: 0,
        ticketsByCategory: {},
      );
    }
  }

  // ============ EXPORT METHODS ============

  /// Export single ticket to JSON
  Map<String, dynamic> ticketToJson(SupportTicket ticket) {
    return {
      'id': ticket.id,
      'userId': ticket.userId,
      'userEmail': ticket.userEmail,
      'userName': ticket.userName,
      'category': ticket.category.name,
      'subject': ticket.subject,
      'status': ticket.status.name,
      'priority': ticket.priority.name,
      'createdAt': ticket.createdAt.toIso8601String(),
      'resolvedAt': ticket.resolvedAt?.toIso8601String(),
      'assignedAdmin': ticket.assignedAdmin,
      'satisfactionRating': ticket.satisfactionRating,
      'messagesCount': ticket.messages.length,
      'responseTimeMinutes': ticket.responseTime.inMinutes,
      'resolutionTimeMinutes': ticket.resolutionTime.inMinutes,
    };
  }

  /// Export all tickets to JSON
  Future<List<Map<String, dynamic>>> exportToJson() async {
    final tickets = await getAllTickets();
    return tickets.map(ticketToJson).toList();
  }

  /// Export all tickets to CSV format
  Future<String> exportToCsv() async {
    final tickets = await getAllTickets();
    final buffer = StringBuffer();
    // Header
    buffer.writeln('ID,UserId,UserEmail,UserName,Category,Subject,Status,Priority,CreatedAt,ResolvedAt,AssignedAdmin,SatisfactionRating,MessagesCount,ResponseTimeMin,ResolutionTimeMin');
    
    // Data rows
    for (final t in tickets) {
      buffer.writeln(
        '"${t.id}","${t.userId}","${t.userEmail}","${t.userName}","${t.category.name}","${t.subject.replaceAll('"', '""')}","${t.status.name}","${t.priority.name}","${t.createdAt.toIso8601String()}","${t.resolvedAt?.toIso8601String() ?? ''}","${t.assignedAdmin ?? ''}","${t.satisfactionRating}","${t.messages.length}","${t.responseTime.inMinutes}","${t.resolutionTime.inMinutes}"'
      );
    }
    return buffer.toString();
  }

  /// Export stats to JSON
  Future<Map<String, dynamic>> exportStatsToJson() async {
    final stats = await getStats();
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'totalTickets': stats.totalTickets,
      'openTickets': stats.openTickets,
      'inProgressTickets': stats.inProgressTickets,
      'resolvedToday': stats.resolvedToday,
      'avgResponseTimeMinutes': stats.avgResponseTime.inMinutes,
      'avgResolutionTimeMinutes': stats.avgResolutionTime.inMinutes,
      'satisfactionScore': stats.satisfactionScore,
      'ticketsByCategory': stats.ticketsByCategory.map((k, v) => MapEntry(k.name, v)),
    };
  }
}
