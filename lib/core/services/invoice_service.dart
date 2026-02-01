import 'package:flutter/foundation.dart';
import 'package:tontetic/core/services/notification_service.dart';

/// Invoice Service - B2B Enterprise Invoice Generation
/// 
/// Generates invoices for enterprise subscriptions:
/// - Monthly subscription fees
/// - Abondement (employer contribution)
/// - PDF export
/// - Payment tracking

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }
enum PaymentMethod { stripe, bankTransfer, check }

class Invoice {
  final String id;
  final String invoiceNumber;
  final String companyId;
  final String companyName;
  final String companyAddress;
  final String companySiret;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double total;
  final String currency;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final DateTime? paidAt;
  final InvoiceStatus status;
  final PaymentMethod? paymentMethod;
  final String? paymentReference;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.companyId,
    required this.companyName,
    required this.companyAddress,
    required this.companySiret,
    required this.items,
    required this.subtotal,
    this.taxRate = 18.0, // TVA Sénégal
    required this.taxAmount,
    required this.total,
    this.currency = 'FCFA',
    required this.invoiceDate,
    required this.dueDate,
    this.paidAt,
    this.status = InvoiceStatus.draft,
    this.paymentMethod,
    this.paymentReference,
  });

  Invoice copyWith({
    InvoiceStatus? status,
    DateTime? paidAt,
    PaymentMethod? paymentMethod,
    String? paymentReference,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      companyId: companyId,
      companyName: companyName,
      companyAddress: companyAddress,
      companySiret: companySiret,
      items: items,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
      currency: currency,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      paidAt: paidAt ?? this.paidAt,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }

  bool get isOverdue => status != InvoiceStatus.paid && DateTime.now().isAfter(dueDate);
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  }) : total = quantity * unitPrice;
}

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  final List<Invoice> _invoices = [];
  int _invoiceCounter = 1;

  // Initialize - no demo data, all data from Firestore
  void initDemoData() {
    // PRODUCTION: No demo data - all invoices come from Firestore 'invoices' collection
    debugPrint('[Invoice] Service initialized (no demo data)');
  }

  // CRUD Operations
  List<Invoice> getAllInvoices() => List.unmodifiable(_invoices);

  List<Invoice> getInvoicesByStatus(InvoiceStatus status) =>
    _invoices.where((i) => i.status == status).toList();

  List<Invoice> getInvoicesByCompany(String companyId) =>
    _invoices.where((i) => i.companyId == companyId).toList();

  List<Invoice> getOverdueInvoices() =>
    _invoices.where((i) => i.isOverdue && i.status != InvoiceStatus.paid).toList();

  Invoice? getInvoiceById(String id) {
    try {
      return _invoices.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  String generateInvoice({
    required String companyId,
    required String companyName,
    required String companyAddress,
    required String companySiret,
    required List<InvoiceItem> items,
    double taxRate = 18.0,
  }) {
    final invoiceId = 'inv_${(_invoices.length + 1).toString().padLeft(3, '0')}';
    final invoiceNumber = 'TONT-${DateTime.now().year}-${_invoiceCounter.toString().padLeft(4, '0')}';
    _invoiceCounter++;

    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final taxAmount = subtotal * (taxRate / 100);
    final total = subtotal + taxAmount;

    final invoice = Invoice(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      companyId: companyId,
      companyName: companyName,
      companyAddress: companyAddress,
      companySiret: companySiret,
      items: items,
      subtotal: subtotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      total: total,
      invoiceDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 15)),
      status: InvoiceStatus.draft,
    );

    _invoices.add(invoice);
    debugPrint('[Invoice] Generated: $invoiceNumber for $companyName');
    return invoiceId;
  }

  void sendInvoice(String invoiceId) {
    final index = _invoices.indexWhere((i) => i.id == invoiceId);
    if (index == -1) return;

    _invoices[index] = _invoices[index].copyWith(status: InvoiceStatus.sent);
    debugPrint('[Invoice] Sent: ${_invoices[index].invoiceNumber}');
    
    // Trigger email intent 
    // In production this would be a backend call, but for now we use client-side intent
    // We assume the company has an email (not in model yet, so using logic placeholder)
    NotificationService.sendInvoiceEmail(
      email: "contact@${_invoices[index].companyName.replaceAll(' ', '').toLowerCase()}.com", 
      invoiceNumber: _invoices[index].invoiceNumber,
      amount: _invoices[index].total,
      currency: _invoices[index].currency,
    );
  }

  void markAsPaid(String invoiceId, PaymentMethod method, String reference) {
    final index = _invoices.indexWhere((i) => i.id == invoiceId);
    if (index == -1) return;

    _invoices[index] = _invoices[index].copyWith(
      status: InvoiceStatus.paid,
      paidAt: DateTime.now(),
      paymentMethod: method,
      paymentReference: reference,
    );
    debugPrint('[Invoice] Paid: ${_invoices[index].invoiceNumber}');
  }

  void cancelInvoice(String invoiceId) {
    final index = _invoices.indexWhere((i) => i.id == invoiceId);
    if (index == -1) return;

    _invoices[index] = _invoices[index].copyWith(status: InvoiceStatus.cancelled);
    debugPrint('[Invoice] Cancelled: ${_invoices[index].invoiceNumber}');
  }

  // Statistics
  Map<String, dynamic> getStats() {
    final paid = _invoices.where((i) => i.status == InvoiceStatus.paid);
    final pending = _invoices.where((i) => i.status == InvoiceStatus.sent);
    final overdue = getOverdueInvoices();

    return {
      'totalInvoices': _invoices.length,
      'paidInvoices': paid.length,
      'pendingInvoices': pending.length,
      'overdueInvoices': overdue.length,
      'totalPaid': paid.fold<double>(0, (sum, i) => sum + i.total),
      'totalPending': pending.fold<double>(0, (sum, i) => sum + i.total),
      'totalOverdue': overdue.fold<double>(0, (sum, i) => sum + i.total),
    };
  }

  // PDF Generation (placeholder - uses pdf_export_service)
  String generatePdfContent(Invoice invoice) {
    return '''
FACTURE
=======

Numéro: ${invoice.invoiceNumber}
Date: ${_formatDate(invoice.invoiceDate)}
Échéance: ${_formatDate(invoice.dueDate)}

CLIENT:
${invoice.companyName}
${invoice.companyAddress}
SIRET: ${invoice.companySiret}

DÉTAIL:
${invoice.items.map((i) => '${i.description}: ${i.quantity} x ${i.unitPrice} = ${i.total} ${invoice.currency}').join('\n')}

Sous-total: ${invoice.subtotal} ${invoice.currency}
TVA (${invoice.taxRate}%): ${invoice.taxAmount} ${invoice.currency}
TOTAL: ${invoice.total} ${invoice.currency}

Statut: ${_getStatusLabel(invoice.status)}
''';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Brouillon';
      case InvoiceStatus.sent: return 'Envoyée';
      case InvoiceStatus.paid: return 'Payée';
      case InvoiceStatus.overdue: return 'En retard';
      case InvoiceStatus.cancelled: return 'Annulée';
    }
  }

  // ============ EXPORT METHODS ============

  /// Export single invoice to JSON
  Map<String, dynamic> invoiceToJson(Invoice invoice) {
    return {
      'id': invoice.id,
      'invoiceNumber': invoice.invoiceNumber,
      'companyId': invoice.companyId,
      'companyName': invoice.companyName,
      'companyAddress': invoice.companyAddress,
      'companySiret': invoice.companySiret,
      'items': invoice.items.map((i) => {
        'description': i.description,
        'quantity': i.quantity,
        'unitPrice': i.unitPrice,
        'total': i.total,
      }).toList(),
      'subtotal': invoice.subtotal,
      'taxRate': invoice.taxRate,
      'taxAmount': invoice.taxAmount,
      'total': invoice.total,
      'currency': invoice.currency,
      'invoiceDate': invoice.invoiceDate.toIso8601String(),
      'dueDate': invoice.dueDate.toIso8601String(),
      'paidAt': invoice.paidAt?.toIso8601String(),
      'status': invoice.status.name,
      'paymentMethod': invoice.paymentMethod?.name,
      'paymentReference': invoice.paymentReference,
      'isOverdue': invoice.isOverdue,
    };
  }

  /// Export all invoices to JSON
  List<Map<String, dynamic>> exportToJson() {
    return _invoices.map(invoiceToJson).toList();
  }

  /// Export all invoices to CSV format
  String exportToCsv() {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('InvoiceNumber,CompanyName,CompanySiret,Subtotal,TaxRate,TaxAmount,Total,Currency,InvoiceDate,DueDate,PaidAt,Status,PaymentMethod,PaymentReference');
    
    // Data rows
    for (final i in _invoices) {
      buffer.writeln(
        '"${i.invoiceNumber}","${i.companyName}","${i.companySiret}","${i.subtotal}","${i.taxRate}","${i.taxAmount}","${i.total}","${i.currency}","${i.invoiceDate.toIso8601String()}","${i.dueDate.toIso8601String()}","${i.paidAt?.toIso8601String() ?? ''}","${i.status.name}","${i.paymentMethod?.name ?? ''}","${i.paymentReference ?? ''}"'
      );
    }
    return buffer.toString();
  }

  /// Export stats to JSON
  Map<String, dynamic> exportStatsToJson() {
    final stats = getStats();
    stats['exportDate'] = DateTime.now().toIso8601String();
    return stats;
  }
}
