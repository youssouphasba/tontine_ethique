import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tontetic/core/providers/subscription_provider.dart';
import 'package:tontetic/core/services/enterprise_limit_override_service.dart';

/// V17: Widget de contact support pour le dashboard entreprise
/// Permet aux entreprises de demander des ajustements de limites

class EnterpriseSupportWidget extends ConsumerStatefulWidget {
  final String companyId;
  final String companyName;
  final String requesterId;
  final int currentEmployees;
  final int maxEmployees;
  final int currentTontines;
  final int maxTontines;

  const EnterpriseSupportWidget({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.requesterId,
    required this.currentEmployees,
    required this.maxEmployees,
    required this.currentTontines,
    required this.maxTontines,
  });

  @override
  ConsumerState<EnterpriseSupportWidget> createState() => _EnterpriseSupportWidgetState();
}

class _EnterpriseSupportWidgetState extends ConsumerState<EnterpriseSupportWidget> {
  bool _isExpanded = false;
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();
  final _employeesController = TextEditingController();
  final _tontinesController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _employeesController.dispose();
    _tontinesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNearLimit = widget.currentEmployees >= widget.maxEmployees * 0.8 ||
                        widget.currentTontines >= widget.maxTontines * 0.8;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNearLimit 
            ? [Colors.orange.shade600, Colors.deepOrange.shade700]
            : [Colors.teal.shade600, Colors.teal.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isNearLimit ? Colors.orange : Colors.teal).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isNearLimit ? Icons.warning_rounded : Icons.support_agent,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNearLimit 
                            ? 'Limite presque atteinte'
                            : 'Besoin de flexibilité ?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contactez notre support pour un ajustement',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // Expanded form
          if (_isExpanded) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current limits info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${widget.currentEmployees}/${widget.maxEmployees}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: widget.currentEmployees >= widget.maxEmployees
                                      ? Colors.red.shade600
                                      : Colors.teal.shade700,
                                  ),
                                ),
                                const Text('Salariés', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${widget.currentTontines}/${widget.maxTontines}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: widget.currentTontines >= widget.maxTontines
                                      ? Colors.red.shade600
                                      : Colors.teal.shade700,
                                  ),
                                ),
                                const Text('Tontines', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Flexibility note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              PlanLimits.flexibilityNote,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Demander un ajustement',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    // Requested employees
                    TextFormField(
                      controller: _employeesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nombre de salariés souhaité',
                        hintText: 'Ex: ${widget.maxEmployees + 10}',
                        prefixIcon: const Icon(Icons.people),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requis';
                        final n = int.tryParse(v);
                        if (n == null || n < widget.maxEmployees) {
                          return 'Doit être supérieur à ${widget.maxEmployees}';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Requested tontines
                    TextFormField(
                      controller: _tontinesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nombre de tontines souhaité',
                        hintText: 'Ex: ${widget.maxTontines + 2}',
                        prefixIcon: const Icon(Icons.groups),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requis';
                        final n = int.tryParse(v);
                        if (n == null || n < widget.maxTontines) {
                          return 'Doit être supérieur à ${widget.maxTontines}';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Reason
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Raison de la demande',
                        hintText: 'Ex: Recrutement prévu, nombre impair de salariés...',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 50),
                          child: Icon(Icons.note),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 10) return 'Minimum 10 caractères';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isSubmitting 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                        label: Text(_isSubmitting ? 'Envoi en cours...' : 'Envoyer la demande'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(enterpriseLimitOverrideServiceProvider);
      await service.requestAdjustment(
        companyId: widget.companyId,
        companyName: widget.companyName,
        requesterId: widget.requesterId,
        requestedEmployees: int.parse(_employeesController.text),
        requestedTontines: int.parse(_tontinesController.text),
        reason: _reasonController.text,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isExpanded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Demande envoyée ! Notre équipe vous répondra sous 24h.'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        _employeesController.clear();
        _tontinesController.clear();
        _reasonController.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }
}

/// Quick contact button for dashboard header
class EnterpriseSupportButton extends StatelessWidget {
  final VoidCallback onPressed;

  const EnterpriseSupportButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Stack(
        children: [
          const Icon(Icons.support_agent, size: 28),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
            ),
          ),
        ],
      ),
      tooltip: 'Contacter le support',
    );
  }
}
