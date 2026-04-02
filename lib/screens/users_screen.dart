import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';

class UsersScreen extends StatefulWidget {
  final bool embedded;

  const UsersScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<String> _roles = [
    'admin',
    'manager',
    'technician',
    'staff',
    'viewer'
  ];

  List<User> users = [];
  bool isLoading = false;
  String? error;
  String? success;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await _apiClient.listUsers();
      setState(() {
        users = response
            .map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() {
        error = 'Failed to fetch users';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppTheme.statusError;
      case 'manager':
        return AppTheme.statusWarning;
      case 'technician':
        return AppTheme.statusInfo;
      default:
        return AppTheme.textTertiary;
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    try {
      final updated = await _apiClient.updateUser(user.id, {
        'is_active': !user.isActive,
      });

      final updatedUser = User.fromJson(updated);
      setState(() {
        users = users.map((u) => u.id == user.id ? updatedUser : u).toList();
        success = updatedUser.isActive
            ? 'User activated successfully'
            : 'User deactivated successfully';
      });
    } catch (e) {
      setState(() {
        error = 'Failed to update user';
      });
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        title: const Text('Delete User'),
        content: Text('Delete ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiClient.deleteUser(user.id);
      setState(() {
        users.removeWhere((u) => u.id == user.id);
        success = 'User deleted successfully';
      });
    } catch (e) {
      setState(() {
        error = 'Failed to delete user';
      });
    }
  }

  Future<void> _openUserDialog({User? user}) async {
    final fullNameController =
        TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'staff';

    final isEdit = user != null;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryBg,
              title: Text(isEdit ? 'Edit User' : 'Add User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      enabled: !isEdit,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    if (!isEdit)
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                      ),
                    if (!isEdit) const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      items: _roles
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(isEdit ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    try {
      if (isEdit) {
        final updated = await _apiClient.updateUser(user.id, {
          'full_name': fullNameController.text.trim(),
          'role': selectedRole,
        });
        final updatedUser = User.fromJson(updated);
        setState(() {
          users = users.map((u) => u.id == user.id ? updatedUser : u).toList();
          success = 'User updated successfully';
        });
      } else {
        final created = await _apiClient.createUser({
          'full_name': fullNameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text,
          'role': selectedRole,
        });
        setState(() {
          users.insert(0, User.fromJson(created));
          success = 'User created successfully';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to save user';
      });
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.security;
      case 'manager':
        return Icons.manage_accounts;
      case 'technician':
        return Icons.build;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Users',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openUserDialog(),
                icon: const Icon(Icons.add, size: 13),
                label: const Text('Add User', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${users.length} total users',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusError.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(error!,
                  style: const TextStyle(color: AppTheme.statusError)),
            ),
          if (success != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusSuccess.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(success!,
                  style: const TextStyle(color: AppTheme.statusSuccess)),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : users.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No users found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFF2D1F4A),
                          ),
                          dataRowMinHeight: 42,
                          dataRowMaxHeight: 46,
                          headingRowHeight: 38,
                          columnSpacing: 14,
                          horizontalMargin: 10,
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: users.map((user) {
                            final roleColor = _getRoleColor(user.role);
                            final roleIcon = _getRoleIcon(user.role);
                            return DataRow(cells: [
                              DataCell(
                                Text(
                                  user.fullName,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 170,
                                  child: Text(
                                    user.email,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(roleIcon,
                                          size: 11, color: roleColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.role,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                InkWell(
                                  onTap: () => _toggleUserStatus(user),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user.isActive
                                            ? Icons.toggle_on
                                            : Icons.toggle_off,
                                        color: user.isActive
                                            ? AppTheme.statusSuccess
                                            : AppTheme.textTertiary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.isActive ? 'Active' : 'Inactive',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _openUserDialog(user: user),
                                      icon: const Icon(Icons.edit, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 28, minHeight: 28),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteUser(user),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 28, minHeight: 28),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
          ),
          const SizedBox(height: 24),
          // Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderDark),
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.darkBg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Roles',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...[
                  ('Admin', 'Full system access and user management'),
                  ('Manager', 'Asset management and reporting'),
                  ('Technician', 'Asset scanning and status updates'),
                  ('Staff', 'Read-only access to assets'),
                ].map((role) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle_outlined,
                          size: 8,
                          color: AppTheme.lavender500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role.$1,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                role.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textTertiary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBg,
      appBar: AppBar(
        title: const Text('Manage Users'),
        centerTitle: false,
      ),
      body: content,
    );
  }
}
