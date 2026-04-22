import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

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
    'viewer',
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
    } catch (_) {
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

  String _getErrorMessage(Object err, String fallback) {
    final text = err.toString();

    final marker = 'message:';
    final idx = text.toLowerCase().indexOf(marker);
    if (idx >= 0) {
      var value = text.substring(idx + marker.length).trim();
      value = value.replaceAll('{', '').replaceAll('}', '').trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    final first = parts.first[0];
    final second = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';
    return '${value.month}/${value.day}/${value.year}';
  }

  bool _isSelf(User user) {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return false;
    if (me.id == user.id) return true;
    final myEmail = (me.email).trim().toLowerCase();
    final userEmail = (user.email).trim().toLowerCase();
    return myEmail.isNotEmpty && userEmail.isNotEmpty && myEmail == userEmail;
  }

  Future<void> _toggleUserStatus(User user) async {
    if (_isSelf(user)) {
      setState(() {
        error = "You can't deactivate your own account.";
        success = null;
      });
      return;
    }
    final targetActive = !user.isActive;
    try {
      await _apiClient.updateUser(user.id, {'is_active': targetActive});

      await _fetchUsers();
      if (!mounted) return;

      setState(() {
        success = targetActive
            ? 'User activated successfully'
            : 'User deactivated successfully';
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _getErrorMessage(e, 'Failed to update user');
        success = null;
      });
    }
  }

  Future<void> _deleteUser(User user) async {
    if (_isSelf(user)) {
      setState(() {
        error = "You can't delete your own account.";
        success = null;
      });
      return;
    }
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
      if (!mounted) return;
      setState(() {
        users.removeWhere((u) => u.id == user.id);
        success = 'User deleted successfully';
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = _getErrorMessage(e, 'Failed to delete user');
        success = null;
      });
    }
  }

  Future<void> _openUserDialog({User? user}) async {
    final fullNameController = TextEditingController(text: user?.fullName ?? '');
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
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                    if (!isEdit) const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      items: _roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
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
          error = null;
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
          error = null;
        });
      }
    } catch (e) {
      setState(() {
        error = _getErrorMessage(e, 'Failed to save user');
        success = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = context.watch<AuthProvider>().currentUser?.id;
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              child: Text(
                error!,
                style: const TextStyle(color: AppTheme.statusError),
              ),
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
              child: Text(
                success!,
                style: const TextStyle(color: AppTheme.statusSuccess),
              ),
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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 760) {
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: users.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = users[index];
                                final isSelf = myUserId != null && user.id == myUserId;
                                final roleColor = _getRoleColor(user.role);
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.sidebarBg.withOpacity(0.42),
                                        AppTheme.darkBg.withOpacity(0.80),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.borderDark),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                AppTheme.lavender600.withOpacity(0.22),
                                            child: Text(
                                              _initials(user.fullName),
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.fullName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  user.email,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Switch.adaptive(
                                            value: user.isActive,
                                            activeColor: AppTheme.statusSuccess,
                                            onChanged:
                                                isSelf ? null : (_) => _toggleUserStatus(user),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: roleColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(
                                                color: roleColor.withOpacity(0.45),
                                              ),
                                            ),
                                            child: Text(
                                              user.role.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: user.isActive
                                                  ? AppTheme.statusSuccess.withOpacity(0.18)
                                                  : AppTheme.textHint.withOpacity(0.14),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(
                                                color: user.isActive
                                                    ? AppTheme.statusSuccess.withOpacity(0.45)
                                                    : AppTheme.textHint.withOpacity(0.40),
                                              ),
                                            ),
                                            child: Text(
                                              user.isActive ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: user.isActive
                                                    ? AppTheme.statusSuccess
                                                    : AppTheme.textTertiary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBg.withOpacity(0.45),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Created: ${_formatDate(user.createdAt)}',
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                'Updated: ${_formatDate(user.updatedAt)}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _openUserDialog(user: user),
                                              child: const Text('Edit'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _deleteUser(user),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.statusError,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed:
                                                  isSelf ? null : () => _toggleUserStatus(user),
                                              child: Text(
                                                user.isActive ? 'Deactivate' : 'Activate',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF2D1F4A),
                              ),
                              dataRowMinHeight: 42,
                              dataRowMaxHeight: 50,
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
                                final isSelf = myUserId != null && user.id == myUserId;
                                final roleColor = _getRoleColor(user.role);
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
                                      child: Text(
                                        user.role,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        Text(
                                          user.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: user.isActive
                                                ? AppTheme.statusSuccess
                                                : AppTheme.textTertiary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Switch.adaptive(
                                          value: user.isActive,
                                          onChanged:
                                              isSelf ? null : (_) => _toggleUserStatus(user),
                                          activeColor: AppTheme.statusSuccess,
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => _openUserDialog(user: user),
                                          child: const Text('Edit'),
                                        ),
                                        TextButton(
                                          onPressed: isSelf ? null : () => _deleteUser(user),
                                          child: const Text('Delete'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              isSelf ? null : () => _toggleUserStatus(user),
                                          child: Text(
                                            user.isActive ? 'Deactivate' : 'Activate',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 24),
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
                  ('Viewer', 'Limited view-only dashboard access'),
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
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                role.$2,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Manage Users'),
        centerTitle: false,
      ),
      body: content,
    );
  }
}
