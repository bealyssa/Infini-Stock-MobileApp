# Flutter Mobile App - RBAC Implementation Guide

## Overview
The role-based access control (RBAC) system has been successfully applied to the Flutter mobile app, matching the web application's permission structure. This ensures consistent access control across all platforms.

## Architecture

### Core Components

#### 1. **Permissions Utility** (`lib/utils/permissions.dart`)
Defines the permission matrix and role hierarchy:
- **PERMISSIONS**: Maps permission strings to allowed roles
- **ROLE_HIERARCHY**: Defines role inheritance (e.g., manager inherits from technician)
- **Helper functions**: `hasPermission()`, `hasAnyPermission()`, `hasAllPermissions()`, `isAdmin()`, `isManager()`, etc.

#### 2. **PermissionProvider** (`lib/providers/permission_provider.dart`)
State management for user permissions:
- Stores current user and provides computed role
- Exposes permission checking methods via Provider pattern
- Syncs automatically with AuthProvider when user logs in

#### 3. **RoleGuard Widget** (`lib/widgets/role_guard.dart`)
Conditional rendering component:
- Wraps UI elements to show/hide based on permissions
- Supports permission-based checks and role-based checks
- Provides fallback widget for unauthorized users

### Application Flow

```
User Login → AuthProvider → PermissionProvider
    ↓
User Role Synced
    ↓
RoleGuard & Navigation Updated
    ↓
Screens/Features Show/Hide Based on Permissions
```

## Usage Examples

### Basic Permission Check
```dart
RoleGuard(
  permission: 'user:create',
  child: ElevatedButton(
    onPressed: () => _openUserDialog(),
    child: Text('Add User'),
  ),
)
```

### Multiple Permissions (Any)
```dart
RoleGuard(
  permissions: ['asset:create', 'asset:update'],
  child: ElevatedButton(child: Text('Edit Asset')),
)
```

### Multiple Permissions (All Required)
```dart
RoleGuard(
  permissions: ['asset:create', 'asset:delete'],
  requireAll: true,
  child: ElevatedButton(child: Text('Manage Assets')),
)
```

### Role-Based Check
```dart
RoleGuard(
  roles: ['admin', 'manager'],
  child: ListTile(title: Text('Manage Users')),
)
```

### Programmatic Permission Check
```dart
final permProvider = context.read<PermissionProvider>();
if (permProvider.hasPermission('user:delete')) {
  // Show delete button
}
```

## Permission Matrix

### User Management
- `user:create` - ['admin', 'manager']
- `user:read` - ['admin', 'manager']
- `user:update` - ['admin', 'manager']
- `user:delete` - ['admin']
- `user:assign_role` - ['admin']

### Asset Management
- `asset:create` - ['admin', 'manager']
- `asset:read` - ['admin', 'manager', 'technician', 'staff', 'viewer']
- `asset:update` - ['admin', 'manager', 'technician']
- `asset:delete` - ['admin']
- `asset:scan` - ['admin', 'manager', 'technician', 'staff', 'viewer']
- `asset:move` - ['admin', 'manager', 'technician']
- `asset:swap` - ['admin', 'manager', 'technician']

### System Units
- `unit:create` - ['admin', 'manager']
- `unit:read` - ['admin', 'manager', 'technician', 'staff', 'viewer']
- `unit:update` - ['admin', 'manager']
- `unit:delete` - ['admin']

### Monitors
- `monitor:create` - ['admin', 'manager']
- `monitor:read` - ['admin', 'manager', 'technician', 'staff', 'viewer']
- `monitor:update` - ['admin', 'manager']
- `monitor:delete` - ['admin']

### QR Codes
- `qr:generate` - ['admin', 'manager', 'technician']
- `qr:view` - ['admin', 'manager', 'technician', 'staff', 'viewer']

### Dashboard & Activity
- `dashboard:view` - ['admin', 'manager', 'technician', 'staff', 'viewer']
- `dashboard:edit` - ['admin', 'manager']
- `activity:view` - ['admin', 'manager', 'technician', 'staff', 'viewer']
- `activity:export` - ['admin', 'manager']

### Reports & Settings
- `report:view` - ['admin', 'manager']
- `report:generate` - ['admin', 'manager']
- `report:export` - ['admin', 'manager']
- `settings:view` - ['admin']
- `settings:update` - ['admin']

## Currently Implemented RBAC

### Home Screen
- **Drawer Navigation**: "Manage Users" menu item hidden for non-admin/manager users
- **Bottom Navigation**: "Users" tab only shown to admin/manager roles

### Users Screen
- **Add User Button**: Requires `user:create` permission
- **Edit Button**: Requires `user:update` permission
- **Delete Button**: Requires `user:delete` permission
- Both mobile (card) and desktop (table) layouts protected

## Future Enhancements

### Recommended Additional Permission Checks

#### Dashboard Tab
- Add permission checks for edit/configuration options
- Use `dashboard:view` and `dashboard:edit` permissions

#### Monitors Tab
- Implement `monitor:create`, `monitor:update`, `monitor:delete` checks on action buttons
- Show/hide create button based on `monitor:create` permission

#### Units Tab
- Implement `unit:create`, `unit:update`, `unit:delete` checks
- Show/hide create button based on `unit:create` permission

#### Activity Logs Tab
- Add export functionality with `activity:export` permission check

### QR Scanner
- Implement QR code scanning access control based on `asset:scan` permission
- Show scanner FAB only to authorized users

### Asset Operations
- Add permission checks for asset move/swap operations
- Implement `asset:move` and `asset:swap` permission checks

## Testing RBAC

### Test Accounts
Use these roles to test RBAC:
- **admin**: Full system access
- **manager**: User management and asset operations
- **technician**: Asset scanning and updates
- **staff**: Read-only asset access
- **viewer**: Limited dashboard access

### Manual Testing Steps
1. Log in with different role accounts
2. Verify navigation items are shown/hidden appropriately
3. Verify buttons are shown/hidden on action screens
4. Verify programmatic permission checks work correctly
5. Test role hierarchy (e.g., manager inherits technician permissions)

## Important Notes

1. **Server-Side Enforcement**: Client-side RBAC is for UX only. Always enforce permissions on the backend API.
2. **Permission Sync**: PermissionProvider syncs with AuthProvider on login. Keep them in sync for reliable UX.
3. **Fallback UI**: RoleGuard shows nothing by default for unauthorized users. Use `fallback` parameter to show alternative UI.
4. **Role Hierarchy**: Use role hierarchy for inheritance. Manager inherits technician permissions, etc.

## File Locations

```
lib/
├── utils/
│   └── permissions.dart          (Permission matrix & utilities)
├── providers/
│   ├── permission_provider.dart  (Permission state management)
│   └── auth_provider.dart        (Modified for sync)
├── widgets/
│   └── role_guard.dart           (RBAC widget component)
├── screens/
│   ├── home_screen.dart          (Modified with RoleGuard)
│   ├── users_screen.dart         (Modified with RoleGuard)
│   └── ...other screens
└── main.dart                       (Modified with PermissionProvider)
```
