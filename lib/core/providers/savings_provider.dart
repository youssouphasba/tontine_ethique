import 'package:flutter_riverpod/flutter_riverpod.dart';

/// V14: Savings Projects State Management
/// Manages savings "coffre-fort" projects with real state

class SavingsProject {
  final String id;
  final String name;
  final double goalAmount;
  final double currentAmount;
  final DateTime createdAt;
  final DateTime? targetDate;
  final bool isLocked;

  SavingsProject({
    required this.id,
    required this.name,
    required this.goalAmount,
    this.currentAmount = 0,
    required this.createdAt,
    this.targetDate,
    this.isLocked = false,
  });

  SavingsProject copyWith({
    double? currentAmount,
    bool? isLocked,
  }) {
    return SavingsProject(
      id: id,
      name: name,
      goalAmount: goalAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      createdAt: createdAt,
      targetDate: targetDate,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  double get progress => goalAmount > 0 ? currentAmount / goalAmount : 0;
  bool get isComplete => currentAmount >= goalAmount;
}

class SavingsState {
  final List<SavingsProject> projects;
  final double totalSaved;

  SavingsState({
    this.projects = const [],
    this.totalSaved = 0,
  });

  SavingsState copyWith({
    List<SavingsProject>? projects,
    double? totalSaved,
  }) {
    return SavingsState(
      projects: projects ?? this.projects,
      totalSaved: totalSaved ?? this.totalSaved,
    );
  }
}

class SavingsNotifier extends StateNotifier<SavingsState> {
  SavingsNotifier() : super(SavingsState());

  void createProject({
    required String name,
    required double goalAmount,
    DateTime? targetDate,
  }) {
    final newProject = SavingsProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      goalAmount: goalAmount,
      createdAt: DateTime.now(),
      targetDate: targetDate,
    );

    state = state.copyWith(
      projects: [...state.projects, newProject],
    );
  }

  void addToProject(String projectId, double amount) {
    final updated = state.projects.map((p) {
      if (p.id == projectId) {
        return p.copyWith(currentAmount: p.currentAmount + amount);
      }
      return p;
    }).toList();

    state = state.copyWith(
      projects: updated,
      totalSaved: state.totalSaved + amount,
    );
  }

  void withdrawFromProject(String projectId, double amount) {
    final updated = state.projects.map((p) {
      if (p.id == projectId && !p.isLocked) {
        final newAmount = (p.currentAmount - amount).clamp(0.0, p.goalAmount).toDouble();
        return p.copyWith(currentAmount: newAmount);
      }
      return p;
    }).toList();

    state = state.copyWith(
      projects: updated,
      totalSaved: (state.totalSaved - amount).clamp(0.0, double.infinity).toDouble(),
    );
  }

  void lockProject(String projectId) {
    final updated = state.projects.map((p) {
      if (p.id == projectId) {
        return p.copyWith(isLocked: true);
      }
      return p;
    }).toList();

    state = state.copyWith(projects: updated);
  }

  void unlockProject(String projectId) {
    final updated = state.projects.map((p) {
      if (p.id == projectId) {
        return p.copyWith(isLocked: false);
      }
      return p;
    }).toList();

    state = state.copyWith(projects: updated);
  }

  void deleteProject(String projectId) {
    final projectIndex = state.projects.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return; // Project not found, nothing to delete
    
    final project = state.projects[projectIndex];
    state = state.copyWith(
      projects: state.projects.where((p) => p.id != projectId).toList(),
      totalSaved: state.totalSaved - project.currentAmount,
    );
  }
}

final savingsProvider = StateNotifierProvider<SavingsNotifier, SavingsState>((ref) {
  return SavingsNotifier();
});
