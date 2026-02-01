import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Context Provider
/// Manages the current user context (enterprise vs personal)
/// 
/// A single user can have multiple contexts:
/// - Enterprise context: tontines managed by employer
/// - Personal context: private tontines with friends/family
/// 
/// PSP is shared but payment references are separate per tontine

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tontetic/core/providers/auth_provider.dart';

enum UserContext {
  personal,   // Tontines personnelles
  enterprise, // Tontines de l'entreprise
}

class EmployeeLink {
  final String companyId;
  final String companyName;
  final DateTime linkedAt;
  final bool isActive;

  EmployeeLink({
    required this.companyId,
    required this.companyName,
    required this.linkedAt,
    this.isActive = true,
  });
}

class ContextState {
  final UserContext currentContext;
  final List<EmployeeLink> employeeLinks; // Companies this user is linked to
  final String? activeCompanyId; // Current company context

  ContextState({
    this.currentContext = UserContext.personal,
    this.employeeLinks = const [],
    this.activeCompanyId,
  });

  bool get isEmployee => employeeLinks.isNotEmpty;
  bool get hasMultipleCompanies => employeeLinks.length > 1;
  
  EmployeeLink? get currentCompany {
    if (activeCompanyId == null) return null;
    return employeeLinks.where((e) => e.companyId == activeCompanyId).firstOrNull;
  }

  ContextState copyWith({
    UserContext? currentContext,
    List<EmployeeLink>? employeeLinks,
    String? activeCompanyId,
  }) {
    return ContextState(
      currentContext: currentContext ?? this.currentContext,
      employeeLinks: employeeLinks ?? this.employeeLinks,
      activeCompanyId: activeCompanyId ?? this.activeCompanyId,
    );
  }
}

class ContextNotifier extends StateNotifier<ContextState> {
  final Ref ref;

  ContextNotifier(this.ref) : super(ContextState());

  /// Switch to personal context
  void switchToPersonal() {
    state = state.copyWith(
      currentContext: UserContext.personal,
      activeCompanyId: null,
    );
    debugPrint('[Context] Switched to personal context');
  }

  /// Switch to enterprise context
  void switchToEnterprise(String companyId) {
    final hasLink = state.employeeLinks.any((e) => e.companyId == companyId);
    if (!hasLink) {
      debugPrint('[Context] Error: Not linked to company $companyId');
      return;
    }
    
    state = state.copyWith(
      currentContext: UserContext.enterprise,
      activeCompanyId: companyId,
    );
    debugPrint('[Context] Switched to enterprise context: $companyId');
  }

  /// Link account to a company (employee invitation accepted)
  Future<void> linkToCompany({
    required String companyId,
    required String companyName,
  }) async {
    // Check if already linked
    if (state.employeeLinks.any((e) => e.companyId == companyId)) {
      debugPrint('[Context] Already linked to company $companyId');
      return;
    }

    final newLink = EmployeeLink(
      companyId: companyId,
      companyName: companyName,
      linkedAt: DateTime.now(),
    );

    state = state.copyWith(
      employeeLinks: [...state.employeeLinks, newLink],
    );
    
    // PERSISTENCE
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'organizationId': companyId, // Defines the current employer context
          // 'employeeLinks': ... // If supporting multiple employers, store array here
        });
        
        // Also add to enterprise employees subcollection (optional but good for listing)
        await FirebaseFirestore.instance
            .collection('enterprises')
            .doc(companyId)
            .collection('employees')
            .doc(user.uid)
            .set({
              'uid': user.uid,
              'joinedAt': FieldValue.serverTimestamp(),
              'status': 'active',
              'role': 'employee',
              'email': user.email ?? '',
            });

      } catch (e) {
         debugPrint('[Context] Persistence Error: $e');
      }
    }

    debugPrint('[Context] Linked to company: $companyName ($companyId)');
  }

  /// Unlink from a company
  void unlinkFromCompany(String companyId) {
    state = state.copyWith(
      employeeLinks: state.employeeLinks.where((e) => e.companyId != companyId).toList(),
    );
    
    // If was in that company context, switch to personal
    if (state.activeCompanyId == companyId) {
      switchToPersonal();
    }
    debugPrint('[Context] Unlinked from company: $companyId');
  }

  /// Check if user is linked to a specific company
  bool isLinkedTo(String companyId) {
    return state.employeeLinks.any((e) => e.companyId == companyId);
  }
}

final contextProvider = StateNotifierProvider<ContextNotifier, ContextState>((ref) {
  return ContextNotifier(ref);
});
