import '../models/user_model.dart';

/// Role-Based Access Control (RBAC) utility class
class RBACManager {
  /// Role definitions
  static const String ROLE_ADMIN = 'admin';
  static const String ROLE_MANAGER = 'manager';
  static const String ROLE_TECHNICIAN = 'technician';
  static const String ROLE_STAFF = 'staff';
  static const String ROLE_VIEWER = 'viewer';

  /// Check if user can access dashboard
  static bool canAccessDashboard(User? user) {
    if (user == null) return false;
    // All roles can access the dashboard, but content is role-limited.
    return true;
  }

  /// Check if user can access monitors
  static bool canAccessMonitors(User? user) {
    if (user == null) return false;
    // All roles can access (ADMIN, MANAGER, TECHNICIAN, STAFF, VIEWER)
    return true;
  }

  /// Check if user can access units
  static bool canAccessUnits(User? user) {
    if (user == null) return false;
    // All roles can access (ADMIN, MANAGER, TECHNICIAN, STAFF, VIEWER)
    return true;
  }

  /// Check if user can access activity logs
  static bool canAccessActivityLogs(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Check if user can access users management
  static bool canAccessUsers(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Check if user can add monitor
  static bool canAddMonitor(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Check if user can edit monitor
  static bool canEditMonitor(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN ||
        user.role == ROLE_MANAGER ||
        user.role == ROLE_TECHNICIAN;
  }

  /// Check if user can delete monitor
  static bool canDeleteMonitor(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Check if user can add unit
  static bool canAddUnit(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Check if user can edit unit
  static bool canEditUnit(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN ||
        user.role == ROLE_MANAGER ||
        user.role == ROLE_TECHNICIAN;
  }

  /// Check if user can delete unit
  static bool canDeleteUnit(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Check if user can scan QR
  static bool canScanQR(User? user) {
    if (user == null) return false;
    // All roles can scan
    return true;
  }

  /// Check if user can print QR
  static bool canPrintQR(User? user) {
    if (user == null) return false;
    return user.role != ROLE_STAFF && user.role != ROLE_VIEWER;
  }

  /// Check if user has full dashboard access (limited for technician/staff)
  static bool hasFullDashboardAccess(User? user) {
    if (user == null) return false;
    return user.role == ROLE_ADMIN || user.role == ROLE_MANAGER;
  }

  /// Get role label
  static String getRoleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case ROLE_ADMIN:
        return 'Admin';
      case ROLE_MANAGER:
        return 'Manager';
      case ROLE_TECHNICIAN:
        return 'Technician';
      case ROLE_STAFF:
        return 'Staff';
      case ROLE_VIEWER:
        return 'Viewer';
      default:
        return 'User';
    }
  }

  /// Get role indicator (for non-admin users)
  static String? getRoleIndicator(String? role) {
    switch (role?.toLowerCase()) {
      case ROLE_MANAGER:
        return '👔 Manager Mode';
      case ROLE_TECHNICIAN:
        return '⚙️ Edit & Scan';
      case ROLE_STAFF:
        return '👁️ View-only mode';
      case ROLE_VIEWER:
        return '👁️ View-only mode';
      default:
        return null; // No indicator for admin
    }
  }

  /// Get role indicator color
  static int getRoleIndicatorColor(String? role) {
    switch (role?.toLowerCase()) {
      case ROLE_MANAGER:
        return 0xFF9C27B0; // Purple
      case ROLE_TECHNICIAN:
        return 0xFFFFA726; // Amber
      case ROLE_STAFF:
        return 0xFF42A5F5; // Blue
      case ROLE_VIEWER:
        return 0xFF42A5F5; // Blue
      default:
        return 0xFF4CAF50; // Green for admin
    }
  }
}
