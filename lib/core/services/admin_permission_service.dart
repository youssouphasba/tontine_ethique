import 'package:flutter/foundation.dart';

/// Admin Role-Based Access Control (RBAC) Service
/// 
/// Manages admin permissions with granular access levels:
/// - Read-only: Can view but not modify
/// - Modify: Can view and modify
/// - No access: Cannot view or modify
/// 
/// Each admin section can have independent permission levels.

enum AccessLevel {
  none,     // No access - section hidden
  readOnly, // Can view but not modify
  modify,   // Full access - view and modify
}

/// Admin sections that can have independent permissions
enum AdminSection {
  dashboard,     // Overview & stats
  plans,         // NEW: Membership & Pricing management
  users,         // User management
  circles,       // Circle/Tontine management
  moderation,    // Content moderation
  merchants,     // Merchant management
  enterprises,   // B2B enterprise management
  payments,      // Payment transactions (READ-ONLY always)
  reports,       // Reports & disputes
  support,       // Support tickets
  campaigns,     // Marketing campaigns
  referral,      // Referral/sponsorship
  security,      // NEW: Security pillars & audit logs
  audit,         // Audit logs (legacy/detailed)
  settings,      // Global settings
}

/// Admin roles with predefined permission sets
enum AdminRole {
  superAdmin,     // Full access to everything
  admin,          // Full access except settings
  moderator,      // Moderation, reports, support only
  support,        // Support and user view only
  analyst,        // Read-only access to all data
  marketing,      // Campaigns and referral only
  viewer,         // Read-only access to limited sections
}

class AdminPermissions {
  final String adminId;
  final String adminName;
  final String email;
  final AdminRole role;
  final Map<AdminSection, AccessLevel> customPermissions;
  final bool mfaEnabled;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  AdminPermissions({
    required this.adminId,
    required this.adminName,
    required this.email,
    required this.role,
    Map<AdminSection, AccessLevel>? customPermissions,
    this.mfaEnabled = false,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  }) : customPermissions = customPermissions ?? {};

  /// Get effective access level for a section
  AccessLevel getAccessLevel(AdminSection section) {
    // Check custom permissions first
    if (customPermissions.containsKey(section)) {
      return customPermissions[section]!;
    }
    
    // Fall back to role-based permissions
    return _getRolePermission(role, section);
  }

  /// Check if admin can view a section
  bool canView(AdminSection section) {
    final level = getAccessLevel(section);
    return level == AccessLevel.readOnly || level == AccessLevel.modify;
  }

  /// Check if admin can modify a section
  bool canModify(AdminSection section) {
    // Payments are ALWAYS read-only (security requirement)
    if (section == AdminSection.payments) return false;
    
    return getAccessLevel(section) == AccessLevel.modify;
  }

  AdminPermissions copyWith({
    AdminRole? role,
    Map<AdminSection, AccessLevel>? customPermissions,
    bool? mfaEnabled,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return AdminPermissions(
      adminId: adminId,
      adminName: adminName,
      email: email,
      role: role ?? this.role,
      customPermissions: customPermissions ?? this.customPermissions,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Default role permissions
  static AccessLevel _getRolePermission(AdminRole role, AdminSection section) {
    switch (role) {
      case AdminRole.superAdmin:
        // Full access to everything (except payments always read-only)
        return section == AdminSection.payments 
          ? AccessLevel.readOnly 
          : AccessLevel.modify;
      
      case AdminRole.admin:
        // Full access except settings
        if (section == AdminSection.settings) return AccessLevel.readOnly;
        if (section == AdminSection.payments) return AccessLevel.readOnly;
        return AccessLevel.modify;
      
      case AdminRole.moderator:
        // Moderation, reports, support, users (read)
        switch (section) {
          case AdminSection.moderation:
          case AdminSection.reports:
          case AdminSection.support:
            return AccessLevel.modify;
          case AdminSection.users:
          case AdminSection.circles:
          case AdminSection.merchants:
          case AdminSection.dashboard:
            return AccessLevel.readOnly;
          default:
            return AccessLevel.none;
        }
      
      case AdminRole.support:
        // Support tickets and user view
        switch (section) {
          case AdminSection.support:
            return AccessLevel.modify;
          case AdminSection.users:
          case AdminSection.circles:
          case AdminSection.dashboard:
            return AccessLevel.readOnly;
          default:
            return AccessLevel.none;
        }
      
      case AdminRole.analyst:
        // Read-only access to all data sections
        if (section == AdminSection.settings) return AccessLevel.none;
        return AccessLevel.readOnly;
      
      case AdminRole.marketing:
        // Campaigns and referral
        switch (section) {
          case AdminSection.campaigns:
          case AdminSection.referral:
            return AccessLevel.modify;
          case AdminSection.users:
          case AdminSection.dashboard:
            return AccessLevel.readOnly;
          default:
            return AccessLevel.none;
        }
      
      case AdminRole.viewer:
        // Limited read-only access
        switch (section) {
          case AdminSection.dashboard:
          case AdminSection.users:
          case AdminSection.circles:
            return AccessLevel.readOnly;
          default:
            return AccessLevel.none;
        }
    }
  }
}

class AdminPermissionService {
  static final AdminPermissionService _instance = AdminPermissionService._internal();
  factory AdminPermissionService() => _instance;
  AdminPermissionService._internal();

  final List<AdminPermissions> _admins = [];
  AdminPermissions? _currentAdmin;

  // Initialize - no demo data, admins come from Firestore
  void initDemoData() {
    // PRODUCTION: No demo data - all admin accounts are managed via Firestore
    // Admins are authenticated via Firebase Auth with Custom Claims
    // and their permissions are stored in the 'admin_users' collection
    debugPrint('[AdminPermission] Service initialized (no demo data)');
  }

  // ============ CURRENT ADMIN ============

  AdminPermissions? get currentAdmin => _currentAdmin;

  void setCurrentAdmin(String adminId) {
    try {
      _currentAdmin = _admins.firstWhere((a) => a.adminId == adminId);
      debugPrint('[AdminPermission] Set current admin: ${_currentAdmin?.adminName}');
    } catch (e) {
      debugPrint('[AdminPermission] Admin not found: $adminId');
    }
  }

  /// Check if current admin can view section
  bool canView(AdminSection section) {
    return _currentAdmin?.canView(section) ?? false;
  }

  /// Check if current admin can modify section
  bool canModify(AdminSection section) {
    return _currentAdmin?.canModify(section) ?? false;
  }

  /// Get access level for current admin
  AccessLevel getAccessLevel(AdminSection section) {
    return _currentAdmin?.getAccessLevel(section) ?? AccessLevel.none;
  }

  // ============ ADMIN MANAGEMENT ============

  List<AdminPermissions> getAllAdmins() => List.unmodifiable(_admins);

  AdminPermissions? getAdminById(String adminId) {
    try {
      return _admins.firstWhere((a) => a.adminId == adminId);
    } catch (e) {
      return null;
    }
  }

  /// Create new admin
  String createAdmin({
    required String name,
    required String email,
    required AdminRole role,
    Map<AdminSection, AccessLevel>? customPermissions,
  }) {
    final id = 'admin_${(_admins.length + 1).toString().padLeft(3, '0')}';
    
    _admins.add(AdminPermissions(
      adminId: id,
      adminName: name,
      email: email,
      role: role,
      customPermissions: customPermissions,
      createdAt: DateTime.now(),
    ));

    debugPrint('[AdminPermission] Created admin: $name with role ${role.name}');
    return id;
  }

  /// Update admin role
  void updateAdminRole(String adminId, AdminRole newRole) {
    final index = _admins.indexWhere((a) => a.adminId == adminId);
    if (index == -1) return;

    _admins[index] = _admins[index].copyWith(role: newRole);
    debugPrint('[AdminPermission] Updated role for $adminId to ${newRole.name}');
  }

  /// Set custom permission for admin
  void setCustomPermission(String adminId, AdminSection section, AccessLevel level) {
    final index = _admins.indexWhere((a) => a.adminId == adminId);
    if (index == -1) return;

    final admin = _admins[index];
    final newPermissions = Map<AdminSection, AccessLevel>.from(admin.customPermissions);
    newPermissions[section] = level;

    _admins[index] = admin.copyWith(customPermissions: newPermissions);
    debugPrint('[AdminPermission] Set custom permission for $adminId: ${section.name} = ${level.name}');
  }

  /// Remove custom permission (revert to role default)
  void removeCustomPermission(String adminId, AdminSection section) {
    final index = _admins.indexWhere((a) => a.adminId == adminId);
    if (index == -1) return;

    final admin = _admins[index];
    final newPermissions = Map<AdminSection, AccessLevel>.from(admin.customPermissions);
    newPermissions.remove(section);

    _admins[index] = admin.copyWith(customPermissions: newPermissions);
    debugPrint('[AdminPermission] Removed custom permission for $adminId: ${section.name}');
  }

  /// Toggle admin active status
  void toggleAdminStatus(String adminId) {
    final index = _admins.indexWhere((a) => a.adminId == adminId);
    if (index == -1) return;

    _admins[index] = _admins[index].copyWith(isActive: !_admins[index].isActive);
    debugPrint('[AdminPermission] Toggled status for $adminId: ${_admins[index].isActive}');
  }

  /// Toggle MFA for admin
  void toggleMfa(String adminId) {
    final index = _admins.indexWhere((a) => a.adminId == adminId);
    if (index == -1) return;

    _admins[index] = _admins[index].copyWith(mfaEnabled: !_admins[index].mfaEnabled);
    debugPrint('[AdminPermission] Toggled MFA for $adminId: ${_admins[index].mfaEnabled}');
  }

  // ============ LABELS ============

  String getRoleLabel(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin: return '👑 Super Admin';
      case AdminRole.admin: return '🔑 Admin';
      case AdminRole.moderator: return '🛡️ Modérateur';
      case AdminRole.support: return '💬 Support';
      case AdminRole.analyst: return '📊 Analyste';
      case AdminRole.marketing: return '📢 Marketing';
      case AdminRole.viewer: return '👁️ Lecteur';
    }
  }

  String getAccessLevelLabel(AccessLevel level) {
    switch (level) {
      case AccessLevel.none: return '🚫 Aucun';
      case AccessLevel.readOnly: return '👁️ Lecture';
      case AccessLevel.modify: return '✏️ Modification';
    }
  }

  String getSectionLabel(AdminSection section) {
    switch (section) {
      case AdminSection.dashboard: return 'Tableau de bord';
      case AdminSection.plans: return 'Gestion des Plans';
      case AdminSection.users: return 'Utilisateurs';
      case AdminSection.circles: return 'Gestion des Cercles';
      case AdminSection.moderation: return 'Modération';
      case AdminSection.merchants: return 'Marchands';
      case AdminSection.enterprises: return 'Entreprises';
      case AdminSection.payments: return 'Finance';
      case AdminSection.reports: return 'Signalements';
      case AdminSection.support: return 'Support';
      case AdminSection.campaigns: return 'Campagnes';
      case AdminSection.referral: return 'Parrainage';
      case AdminSection.security: return 'Sécurité';
      case AdminSection.audit: return 'Audit';
      case AdminSection.settings: return 'Paramètres';
    }
  }

  // ============ EXPORT ============

  List<Map<String, dynamic>> exportToJson() {
    return _admins.map((a) => {
      'adminId': a.adminId,
      'adminName': a.adminName,
      'email': a.email,
      'role': a.role.name,
      'mfaEnabled': a.mfaEnabled,
      'isActive': a.isActive,
      'createdAt': a.createdAt.toIso8601String(),
      'lastLogin': a.lastLogin?.toIso8601String(),
      'customPermissions': a.customPermissions.map(
        (k, v) => MapEntry(k.name, v.name),
      ),
    }).toList();
  }

  /// Get permission matrix for an admin
  Map<String, String> getPermissionMatrix(String adminId) {
    final admin = getAdminById(adminId);
    if (admin == null) return {};

    final matrix = <String, String>{};
    for (final section in AdminSection.values) {
      matrix[section.name] = admin.getAccessLevel(section).name;
    }
    return matrix;
  }
}
