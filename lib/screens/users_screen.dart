import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class UsersScreen extends StatefulWidget {
  final bool embedded;

  const UsersScreen({super.key, this.embedded = false});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiClient _apiClient = ApiClient();
  final List<String> _roles = const [
    'admin',
    'manager',
    'technician',
    'staff',
    'viewer',
  ];

  List<User> _users = const [];
  bool _isLoading = false;
  String? _error;
  String? _success;

  String _query = '';
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final raw = await _apiClient.listUsers();
      final parsed = raw
          .whereType<Map>()
          .map((u) => Map<String, dynamic>.from(u))
          .map(User.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _users = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load users: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    setState(() {
      _error = null;
      _success = null;
    });

    try {
      await _apiClient.updateUser(user.id, {
        'is_active': !user.isActive,
      });

      if (!mounted) return;
      setState(() {
        _success = user.isActive ? 'User deactivated' : 'User activated';
      });
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to update user: ${e.toString()}';
      });
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final r = Responsive.of(context);
        return AlertDialog(
          backgroundColor: AppTheme.overlayBg,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Delete user?',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontSize: r.sp(16)),
          ),
          content: Text(
            'This will permanently delete ${user.fullName}.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: r.sp(12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.statusError),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _error = null;
      _success = null;
    });

    try {
      await _apiClient.deleteUser(user.id);
      if (!mounted) return;
      setState(() {
        _success = 'User deleted';
      });
      await _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to delete user: ${e.toString()}';
      });
    }
  }

  Future<void> _openUserDialog({User? user}) async {
    final isEdit = user != null;

    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();

    String selectedRole = user?.role ?? 'viewer';
    bool isActive = user?.isActive ?? true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final r = Responsive.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (isSaving) return;

              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text;

              if (name.isEmpty || email.isEmpty) {
                setState(() {
                  _error = 'Name and email are required.';
                });
                return;
              }

              setDialogState(() => isSaving = true);
              setState(() {
                _error = null;
                _success = null;
              });

              final payload = <String, dynamic>{
                'full_name': name,
                'email': email,
                'role': selectedRole,
                'is_active': isActive,
              };

              if (!isEdit || password.trim().isNotEmpty) {
                payload['password'] = password;
              }

              try {
                if (isEdit) {
                  final userId = user.id;
                  if (userId.isEmpty) {
                    throw StateError('Missing user id');
                  }
                  await _apiClient.updateUser(userId, payload);
                } else {
                  await _apiClient.createUser(payload);
                }

                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                setState(() {
                  _success = isEdit ? 'User updated' : 'User created';
                });
                await _fetchUsers();
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _error = 'Save failed: ${e.toString()}';
                });
              } finally {
                if (mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              insetPadding: r.insetsAll(16),
              backgroundColor: AppTheme.overlayBg,
              surfaceTintColor: Colors.transparent,
              title: Text(
                isEdit ? 'Edit User' : 'Add User',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: r.sp(16)),
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.dp(520)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: r.dp(10)),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: r.dp(10)),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Password (optional)' : 'Password',
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                    ),
                    SizedBox(height: r.dp(10)),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() => selectedRole = v);
                      },
                    ),
                    SizedBox(height: r.dp(10)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Active',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: r.sp(12)),
                          ),
                        ),
                        Switch.adaptive(
                          value: isActive,
                          activeColor: AppTheme.statusSuccess,
                          onChanged: (v) => setDialogState(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Saving…' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppTheme.lavender500;
      case 'manager':
        return AppTheme.statusInfo;
      case 'technician':
        return AppTheme.statusWarning;
      case 'staff':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textHint;
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\\s+')).where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '?';
    String firstChar(String s) {
      if (s.isEmpty) return '';
      return s.substring(0, 1);
    }

    if (parts.length == 1) return firstChar(parts.first).toUpperCase();
    return (firstChar(parts[0]) + firstChar(parts[1])).toUpperCase();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return _dateTimeFmt.format(dt);
  }

  Future<DateTime?> _pickDateTime(
      BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    final initialDate = initial ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  List<User> _filteredUsers() {
    final q = _query.trim().toLowerCase();

    bool matchesQuery(User u) {
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q) ||
          u.id.toLowerCase().contains(q);
    }

    bool matchesRange(User u) {
      if (_startDateTime == null && _endDateTime == null) return true;
      final created = u.createdAt;
      if (created == null) return false;
      if (_startDateTime != null && created.isBefore(_startDateTime!)) {
        return false;
      }
      if (_endDateTime != null && created.isAfter(_endDateTime!)) {
        return false;
      }
      return true;
    }

    return _users.where((u) => matchesQuery(u) && matchesRange(u)).toList();
  }

  Widget _dateTimeFilterField(
    BuildContext context, {
    required Responsive r,
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null ? 'Select' : _formatDateTime(value),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value == null
                    ? AppTheme.textTertiary
                    : AppTheme.textPrimary,
                fontSize: r.sp(12),
              ),
        ),
      ),
    );
  }

  Widget _banner(
    BuildContext context, {
    required String text,
    required Color color,
  }) {
    final r = Responsive.of(context);
    return Container(
      width: double.infinity,
      padding: r.insetsSymmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: r.sp(12),
            ),
      ),
    );
  }

  Widget _buildUsersTable(
    BuildContext context, {
    required Responsive r,
    required String? myUserId,
    required List<User> users,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.sidebarBg),
        dataRowMinHeight: r.dp(42),
        dataRowMaxHeight: r.dp(52),
        headingRowHeight: r.dp(40),
        columnSpacing: r.dp(14),
        horizontalMargin: r.dp(10),
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: users.map((u) {
          final isSelf = myUserId != null && u.id == myUserId;
          final roleColor = _getRoleColor(u.role);

          return DataRow(
            cells: [
              DataCell(
                Text(
                  u.fullName,
                  style: TextStyle(fontSize: r.sp(11)),
                ),
              ),
              DataCell(
                SizedBox(
                  width: r.dp(190),
                  child: Text(
                    u.email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: r.sp(11)),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: r.insetsSymmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: roleColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    u.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: r.sp(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Text(
                      u.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: r.sp(11),
                        color: u.isActive
                            ? AppTheme.statusSuccess
                            : AppTheme.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: r.dp(8)),
                    Switch.adaptive(
                      value: u.isActive,
                      onChanged: isSelf ? null : (_) => _toggleUserStatus(u),
                      activeColor: AppTheme.statusSuccess,
                    ),
                  ],
                ),
              ),
              DataCell(
                Wrap(
                  spacing: r.dp(6),
                  children: [
                    TextButton(
                      onPressed: () => _openUserDialog(user: u),
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: isSelf ? null : () => _deleteUser(u),
                      child: const Text('Delete'),
                    ),
                    TextButton(
                      onPressed: isSelf ? null : () => _toggleUserStatus(u),
                      child: Text(u.isActive ? 'Deactivate' : 'Activate'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUsersCards(
    BuildContext context, {
    required Responsive r,
    required String? myUserId,
    required List<User> users,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: r.insetsAll(12),
      itemCount: users.length,
      separatorBuilder: (_, __) => SizedBox(height: r.dp(10)),
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelf = myUserId != null && user.id == myUserId;
        final roleColor = _getRoleColor(user.role);

        return Container(
          padding: r.insetsAll(14),
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
                    radius: r.dp(18),
                    backgroundColor: AppTheme.lavender600.withOpacity(0.22),
                    child: Text(
                      _initials(user.fullName),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: r.sp(12),
                      ),
                    ),
                  ),
                  SizedBox(width: r.dp(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.sp(13),
                                  ),
                        ),
                        SizedBox(height: r.dp(2)),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: r.sp(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: user.isActive,
                    activeColor: AppTheme.statusSuccess,
                    onChanged: isSelf ? null : (_) => _toggleUserStatus(user),
                  ),
                ],
              ),
              SizedBox(height: r.dp(10)),
              Wrap(
                spacing: r.dp(8),
                runSpacing: r.dp(8),
                children: [
                  Container(
                    padding: r.insetsSymmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: roleColor.withOpacity(0.45)),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: r.insetsSymmetric(horizontal: 10, vertical: 5),
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
                        fontSize: r.sp(10),
                        fontWeight: FontWeight.w700,
                        color: user.isActive
                            ? AppTheme.statusSuccess
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.dp(10)),
              Container(
                padding: r.insetsSymmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBg.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Created: ${_formatDate(user.createdAt)}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: r.sp(11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Updated: ${_formatDate(user.updatedAt)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: r.sp(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.dp(10)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openUserDialog(user: user),
                      child: const Text('Edit'),
                    ),
                  ),
                  SizedBox(width: r.dp(8)),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSelf ? null : () => _deleteUser(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.statusError,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  SizedBox(width: r.dp(8)),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSelf ? null : () => _toggleUserStatus(user),
                      child: Text(user.isActive ? 'Deactivate' : 'Activate'),
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

  Widget _buildRolesInfo(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: r.insetsAll(16),
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
                  fontSize: r.sp(13),
                ),
          ),
          SizedBox(height: r.dp(12)),
          ...const [
            ('Admin', 'Full system access and user management'),
            ('Manager', 'Manage assets and view reports'),
            ('Technician', 'Scan and update asset status'),
            ('Staff', 'View assigned assets and basic actions'),
            ('Viewer', 'Read-only access'),
          ].map(
            (e) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '${e.$1}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: e.$2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final r = Responsive.of(context);
    final myUserId = context.watch<AuthProvider>().currentUser?.id;
    final filteredUsers = _filteredUsers();

    return SingleChildScrollView(
      padding: r.insetsAll(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Users',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: r.sp(18),
                      ),
                ),
              ),
              SizedBox(width: r.dp(10)),
              ElevatedButton.icon(
                onPressed: _openUserDialog,
                icon: Icon(Icons.add, size: r.icon(18)),
                label: Text(
                  'Add User',
                  style: TextStyle(fontSize: r.sp(12)),
                ),
                style: ElevatedButton.styleFrom(
                  padding: r.insetsSymmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          SizedBox(height: r.dp(12)),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              return Wrap(
                spacing: r.dp(12),
                runSpacing: r.dp(10),
                children: [
                  SizedBox(
                    width: isWide ? r.dp(320) : double.infinity,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isWide ? r.dp(220) : double.infinity,
                    child: _dateTimeFilterField(
                      context,
                      r: r,
                      label: 'Start',
                      value: _startDateTime,
                      onPick: () async {
                        final picked =
                            await _pickDateTime(context, _startDateTime);
                        if (picked == null) return;
                        if (!mounted) return;
                        setState(() => _startDateTime = picked);
                      },
                      onClear: () => setState(() => _startDateTime = null),
                    ),
                  ),
                  SizedBox(
                    width: isWide ? r.dp(220) : double.infinity,
                    child: _dateTimeFilterField(
                      context,
                      r: r,
                      label: 'End',
                      value: _endDateTime,
                      onPick: () async {
                        final picked =
                            await _pickDateTime(context, _endDateTime);
                        if (picked == null) return;
                        if (!mounted) return;
                        setState(() => _endDateTime = picked);
                      },
                      onClear: () => setState(() => _endDateTime = null),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: r.dp(12)),
          if (_error != null) ...[
            _banner(context, text: _error!, color: AppTheme.statusError),
            SizedBox(height: r.dp(10)),
          ],
          if (_success != null) ...[
            _banner(context, text: _success!, color: AppTheme.statusSuccess),
            SizedBox(height: r.dp(10)),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: _isLoading
                ? Padding(
                    padding: r.insetsAll(32),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : filteredUsers.isEmpty
                    ? Padding(
                        padding: r.insetsAll(32),
                        child: Center(
                          child: Text(
                            'No users found',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: r.sp(12)),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 760) {
                            return _buildUsersCards(
                              context,
                              r: r,
                              myUserId: myUserId,
                              users: filteredUsers,
                            );
                          }

                          return _buildUsersTable(
                            context,
                            r: r,
                            myUserId: myUserId,
                            users: filteredUsers,
                          );
                        },
                      ),
          ),
          SizedBox(height: r.dp(24)),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildRolesInfo(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            onPressed: _fetchUsers,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }
}
