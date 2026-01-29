import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// V17: Admin Support Service - Firestore-backed
/// Gère les demandes de support avec distinction Users vs Entreprises
/// 
/// Catégories:
/// - Support Users: questions, bugs, réclamations (particuliers)
/// - Support Entreprise: demandes d'ajustement limites, facturation, SSO

// =============== ENUMS ===============

enum SupportCategory {
  users,      // Particuliers
  enterprise, // Entreprises B2B
}

enum TicketPriority {
  low,
  medium,
  high,
  urgent,
}

enum TicketStatus {
  open,
  inProgress,
  pendingUser,
  pendingAdmin,
  resolved,
  closed,
}

enum TicketType {
  // User types
  question,
  bug,
  complaint,
  featureRequest,
  accountIssue,
  paymentIssue,
  
  // Enterprise types
  limitAdjustment,
  billing,
  ssoSetup,
  apiIntegration,
  accountManager,
  training,
}

String getTicketTypeLabel(TicketType type) {
  switch (type) {
    case TicketType.question: return '❓ Question';
    case TicketType.bug: return '🐛 Bug';
    case TicketType.complaint: return '😤 Réclamation';
    case TicketType.featureRequest: return '💡 Suggestion';
    case TicketType.accountIssue: return '👤 Problème compte';
    case TicketType.paymentIssue: return '💳 Problème paiement';
    case TicketType.limitAdjustment: return '📊 Ajustement limites';
    case TicketType.billing: return '💰 Facturation';
    case TicketType.ssoSetup: return '🔐 Configuration SSO';
    case TicketType.apiIntegration: return '🔌 Intégration API';
    case TicketType.accountManager: return '📞 Contact manager';
    case TicketType.training: return '🎓 Formation';
  }
}

// =============== DATA CLASSES ===============

class SupportTicket {
  final String id;
  final SupportCategory category;
  final TicketType type;
  final TicketPriority priority;
  final TicketStatus status;
  final String subject;
  final String description;
  final String submitterId;
  final String? companyId; // Only for enterprise
  final String? companyName;
  final String? assignedTo; // Admin ID
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TicketMessage> messages;
  final Map<String, dynamic>? metadata; // For limit requests, etc.

  SupportTicket({
    required this.id,
    required this.category,
    required this.type,
    required this.priority,
    required this.status,
    required this.subject,
    required this.description,
    required this.submitterId,
    this.companyId,
    this.companyName,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.metadata,
  });

  factory SupportTicket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupportTicket(
      id: doc.id,
      category: SupportCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => SupportCategory.users,
      ),
      type: TicketType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TicketType.question,
      ),
      priority: TicketPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TicketPriority.medium,
      ),
      status: TicketStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TicketStatus.open,
      ),
      subject: data['subject'] ?? '',
      description: data['description'] ?? '',
      submitterId: data['submitterId'] ?? '',
      companyId: data['companyId'],
      companyName: data['companyName'],
      assignedTo: data['assignedTo'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      messages: (data['messages'] as List<dynamic>? ?? [])
          .map((m) => TicketMessage.fromMap(m))
          .toList(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category.name,
      'type': type.name,
      'priority': priority.name,
      'status': status.name,
      'subject': subject,
      'description': description,
      'submitterId': submitterId,
      'companyId': companyId,
      'companyName': companyName,
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'messages': messages.map((m) => m.toMap()).toList(),
      'metadata': metadata,
    };
  }

  bool get isEnterprise => category == SupportCategory.enterprise;
  bool get isOpen => status == TicketStatus.open || status == TicketStatus.inProgress;
  bool get needsAdminAction => status == TicketStatus.pendingAdmin || status == TicketStatus.open;

  SupportTicket copyWith({
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedTo,
    DateTime? updatedAt,
    List<TicketMessage>? messages,
  }) {
    return SupportTicket(
      id: id,
      category: category,
      type: type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      subject: subject,
      description: description,
      submitterId: submitterId,
      companyId: companyId,
      companyName: companyName,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      messages: messages ?? this.messages,
      metadata: metadata,
    );
  }
}

class TicketMessage {
  final String id;
  final String senderId;
  final String senderName;
  final bool isAdmin;
  final String content;
  final DateTime sentAt;
  final List<String>? attachments;

  TicketMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.isAdmin,
    required this.content,
    required this.sentAt,
    this.attachments,
  });

  factory TicketMessage.fromMap(Map<String, dynamic> map) {
    return TicketMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      content: map['content'] ?? '',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachments: map['attachments'] != null 
          ? List<String>.from(map['attachments']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'isAdmin': isAdmin,
      'content': content,
      'sentAt': Timestamp.fromDate(sentAt),
      'attachments': attachments,
    };
  }
}

// =============== SERVICE ===============

class AdminSupportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'support_tickets';

  // ============ QUERIES (FIRESTORE) ============

  /// Get all tickets for a category
  Future<List<SupportTicket>> getTicketsByCategory(SupportCategory category) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category.name)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[SUPPORT] Error fetching tickets by category: $e');
      return [];
    }
  }

  /// Get user support tickets
  Future<List<SupportTicket>> getUserTickets() => getTicketsByCategory(SupportCategory.users);

  /// Get enterprise support tickets
  Future<List<SupportTicket>> getEnterpriseTickets() => getTicketsByCategory(SupportCategory.enterprise);

  /// Get pending admin action tickets (for dashboard count)
  Future<List<SupportTicket>> getPendingTickets() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', whereIn: ['open', 'pendingAdmin'])
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[SUPPORT] Error fetching pending tickets: $e');
      return [];
    }
  }

  /// Stream all tickets for real-time updates
  Stream<List<SupportTicket>> streamAllTickets() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList());
  }

  /// Get stats for dashboard
  Future<Map<String, dynamic>> getStats() async {
    try {
      final allTickets = await _firestore.collection(_collection).get();
      final tickets = allTickets.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
      
      final userTickets = tickets.where((t) => t.category == SupportCategory.users).toList();
      final enterpriseTickets = tickets.where((t) => t.category == SupportCategory.enterprise).toList();
      
      // Calculate average response time (in minutes)
      int totalResponseMinutes = 0;
      int ticketsWithResponse = 0;
      for (final ticket in tickets) {
        if (ticket.messages.isNotEmpty) {
          final firstAdminMessage = ticket.messages.firstWhere(
            (m) => m.isAdmin, 
            orElse: () => ticket.messages.first,
          );
          final responseTime = firstAdminMessage.sentAt.difference(ticket.createdAt).inMinutes;
          totalResponseMinutes += responseTime;
          ticketsWithResponse++;
        }
      }
      final avgResponseMinutes = ticketsWithResponse > 0 
          ? (totalResponseMinutes / ticketsWithResponse).round() 
          : 0;
      final avgResponseText = avgResponseMinutes > 60 
          ? '${(avgResponseMinutes / 60).toStringAsFixed(1)}h'
          : '${avgResponseMinutes}min';
      
      // Calculate resolution rate
      final resolvedCount = tickets.where((t) => 
          t.status == TicketStatus.resolved || t.status == TicketStatus.closed).length;
      final resolutionRate = tickets.isNotEmpty 
          ? ((resolvedCount / tickets.length) * 100).round()
          : 0;

      return {
        'totalOpen': tickets.where((t) => t.isOpen).length,
        'usersPending': userTickets.where((t) => t.needsAdminAction).length,
        'enterprisePending': enterpriseTickets.where((t) => t.needsAdminAction).length,
        'usersTotal': userTickets.length,
        'enterpriseTotal': enterpriseTickets.length,
        'avgResponseTime': ticketsWithResponse > 0 ? avgResponseText : 'N/A',
        'resolutionRate': tickets.isNotEmpty ? '$resolutionRate%' : 'N/A',
      };
    } catch (e) {
      debugPrint('[SUPPORT] Error calculating stats: $e');
      return {
        'totalOpen': 0,
        'usersPending': 0,
        'enterprisePending': 0,
        'usersTotal': 0,
        'enterpriseTotal': 0,
        'avgResponseTime': 'N/A',
        'resolutionRate': 'N/A',
      };
    }
  }

  // ============ ACTIONS (FIRESTORE) ============

  /// Create a new ticket
  Future<SupportTicket?> createTicket({
    required SupportCategory category,
    required TicketType type,
    required TicketPriority priority,
    required String subject,
    required String description,
    required String submitterId,
    String? companyId,
    String? companyName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = await _firestore.collection(_collection).add({
        'category': category.name,
        'type': type.name,
        'priority': priority.name,
        'status': TicketStatus.open.name,
        'subject': subject,
        'description': description,
        'submitterId': submitterId,
        'companyId': companyId,
        'companyName': companyName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'messages': [],
        'metadata': metadata,
      });

      debugPrint('[SUPPORT] New ${category.name} ticket: ${docRef.id} - $subject');

      return SupportTicket(
        id: docRef.id,
        category: category,
        type: type,
        priority: priority,
        status: TicketStatus.open,
        subject: subject,
        description: description,
        submitterId: submitterId,
        companyId: companyId,
        companyName: companyName,
        createdAt: now,
        updatedAt: now,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[SUPPORT] Error creating ticket: $e');
      return null;
    }
  }

  /// Assign ticket to admin
  Future<bool> assignTicket(String ticketId, String adminId) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'assignedTo': adminId,
        'status': TicketStatus.inProgress.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[SUPPORT] Ticket $ticketId assigned to $adminId');
      return true;
    } catch (e) {
      debugPrint('[SUPPORT] Error assigning ticket: $e');
      return false;
    }
  }

  /// Add message to ticket
  Future<bool> addMessage(String ticketId, TicketMessage message) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'messages': FieldValue.arrayUnion([message.toMap()]),
        'status': message.isAdmin ? TicketStatus.pendingUser.name : TicketStatus.pendingAdmin.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[SUPPORT] Message added to ticket $ticketId');
      return true;
    } catch (e) {
      debugPrint('[SUPPORT] Error adding message: $e');
      return false;
    }
  }

  /// Resolve ticket
  Future<bool> resolveTicket(String ticketId, String resolution) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'status': TicketStatus.resolved.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[SUPPORT] Ticket $ticketId resolved');
      return true;
    } catch (e) {
      debugPrint('[SUPPORT] Error resolving ticket: $e');
      return false;
    }
  }

  /// Close ticket
  Future<bool> closeTicket(String ticketId) async {
    try {
      await _firestore.collection(_collection).doc(ticketId).update({
        'status': TicketStatus.closed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[SUPPORT] Ticket $ticketId closed');
      return true;
    } catch (e) {
      debugPrint('[SUPPORT] Error closing ticket: $e');
      return false;
    }
  }

  /// Process enterprise limit adjustment request
  Future<bool> processLimitAdjustment(String ticketId, bool approve, String adminId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(ticketId).get();
      if (!doc.exists) return false;
      
      final ticket = SupportTicket.fromFirestore(doc);
      if (ticket.type != TicketType.limitAdjustment) return false;

      if (approve) {
        // In production, call EnterpriseLimitOverrideService.setOverride()
        debugPrint('[SUPPORT] Limit adjustment APPROVED for ${ticket.companyName}');
      } else {
        debugPrint('[SUPPORT] Limit adjustment REJECTED for ${ticket.companyName}');
      }

      await _firestore.collection(_collection).doc(ticketId).update({
        'status': TicketStatus.resolved.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[SUPPORT] Error processing limit adjustment: $e');
      return false;
    }
  }
}

// =============== PROVIDERS ===============

final adminSupportServiceProvider = Provider<AdminSupportService>((ref) {
  return AdminSupportService();
});

final userTicketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  return ref.watch(adminSupportServiceProvider).getUserTickets();
});

final enterpriseTicketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  return ref.watch(adminSupportServiceProvider).getEnterpriseTickets();
});

final supportStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminSupportServiceProvider).getStats();
});
