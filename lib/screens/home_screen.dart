import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/activity_log_provider.dart';
import '../services/api_client.dart';
import '../models/user_model.dart';
import 'qr_generator_screen.dart';
import 'users_screen.dart';
import '../widgets/dashboard_charts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _time = '';
  String _date = '';
  late final DateFormat _timeFmt;
  late final DateFormat _dateFmt;
  Timer? _clockTimer;

  static const List<String> _titles = [
    'Infini-Stock',
    'Monitors',
    'System Units',
    'Activity Logs',
    'QR Generator',
    'Manage Users',
  ];

  @override
  void initState() {
    super.initState();

    _timeFmt = DateFormat('h:mm:ss a');
    _dateFmt = DateFormat('EEE, MMM d');

    _syncTimeDate();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncTimeDate();
    });

    Future.microtask(() {
      context.read<MonitorProvider>().fetchMonitors();
      context.read<UnitProvider>().fetchUnits();
      context.read<ActivityLogProvider>().fetchActivityLogs();
      context.read<AuthProvider>().refreshMe();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _syncTimeDate() {
    final now = DateTime.now();
    final newTime = _timeFmt.format(now);
    final newDate = _dateFmt.format(now);
    if (!mounted) return;
    if (newTime == _time && newDate == _date) return;
    setState(() {
      _time = newTime;
      _date = newDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardTab(),
      const MonitorsTab(),
      const UnitsTab(),
      const ActivityLogsTab(),
      const QRGeneratorScreen(embedded: true),
      const UsersScreen(embedded: true),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBg,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.borderDark),
        ),
        title: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final user = auth.currentUser;
            final name = (user?.fullName ?? 'Account').trim();
            final role = (user?.role ?? 'User').trim();
            final capRole = role.isEmpty
                ? 'User'
                : '${role[0].toUpperCase()}${role.substring(1)}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Account' : name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  capRole,
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            );
          },
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _time,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date,
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                _AccountMenuButton(
                  onAccount: () => _showAccountDialog(context),
                  onLogout: () => showLogoutDialog(context),
                ),
              ],
            ),
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.sidebarBg,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppTheme.sidebarBg,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderDark),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Infini-Stock',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IoT Inventory System',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Monitors'),
              selected: _selectedIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('System Units'),
              selected: _selectedIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Activity Logs'),
              selected: _selectedIndex == 3,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('QR Generator'),
              selected: _selectedIndex == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              selected: _selectedIndex == 5,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 5);
              },
            ),
            const Divider(color: AppTheme.borderDark),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutAppDialog(context);
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.sidebarBg,
        selectedItemColor: AppTheme.lavender600,
        unselectedItemColor: AppTheme.textTertiary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Monitors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Units',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_2),
            label: 'QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountDialog(BuildContext context) async {
    final api = ApiClient();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    final fullNameController =
        TextEditingController(text: (user?.fullName ?? '').trim());
    final emailController =
        TextEditingController(text: (user?.email ?? '').trim());

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    String? error;
    String? success;
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> saveInfo() async {
              final fullName = fullNameController.text.trim();
              final email = emailController.text.trim();

              if (fullName.isEmpty) {
                setDialogState(() {
                  error = 'Full name is required';
                  success = null;
                });
                return;
              }
              if (email.isEmpty) {
                setDialogState(() {
                  error = 'Email is required';
                  success = null;
                });
                return;
              }

              setDialogState(() {
                busy = true;
                error = null;
                success = null;
              });

              try {
                final res = await api.updateMe(fullName: fullName, email: email);
                final updatedUser = res['user'] != null
                    ? User.fromJson(res['user'] as Map<String, dynamic>)
                    : null;
                final token = res['token'] as String?;
                if (updatedUser != null) {
                  await auth.applyAccountUpdate(user: updatedUser, token: token);
                }
                setDialogState(() {
                  success = 'Account updated';
                  error = null;
                });
              } catch (e) {
                setDialogState(() {
                  error = 'Failed to update account';
                  success = null;
                });
              } finally {
                setDialogState(() => busy = false);
              }
            }

            Future<void> savePassword() async {
              final currentPassword = currentPasswordController.text;
              final newPassword = newPasswordController.text;
              final confirm = confirmPasswordController.text;

              if (currentPassword.isEmpty || newPassword.isEmpty) {
                setDialogState(() {
                  error = 'Current password and new password are required';
                  success = null;
                });
                return;
              }
              if (newPassword.length < 8) {
                setDialogState(() {
                  error = 'New password must be at least 8 characters';
                  success = null;
                });
                return;
              }
              if (newPassword != confirm) {
                setDialogState(() {
                  error = 'New passwords do not match';
                  success = null;
                });
                return;
              }

              setDialogState(() {
                busy = true;
                error = null;
                success = null;
              });

              try {
                await api.changePassword(
                  currentPassword: currentPassword,
                  newPassword: newPassword,
                );
                currentPasswordController.clear();
                newPasswordController.clear();
                confirmPasswordController.clear();

                setDialogState(() {
                  success = 'Password updated';
                  error = null;
                });
              } catch (e) {
                setDialogState(() {
                  error = 'Failed to update password';
                  success = null;
                });
              } finally {
                setDialogState(() => busy = false);
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.overlayBg,
              title: const Text('Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.statusError.withOpacity(0.40),
                          ),
                          color: AppTheme.statusError.withOpacity(0.10),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: AppTheme.statusError,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (success != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.statusSuccess.withOpacity(0.40),
                            ),
                            color: AppTheme.statusSuccess.withOpacity(0.10),
                          ),
                          child: Text(
                            success!,
                            style: const TextStyle(
                              color: AppTheme.statusSuccess,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Information
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderDark),
                        color: AppTheme.overlayBg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Information',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: busy ? null : saveInfo,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Password
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderDark),
                        color: AppTheme.overlayBg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: currentPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Current Password',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New Password',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm New Password',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: busy ? null : savePassword,
                              child: const Text('Update'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );

    fullNameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.overlayBg,
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.statusError),
              ),
            ),
          ],
        );
      },
    );
  }

  void showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.overlayBg,
          title: const Text('About Infini-Stock'),
          content: const Text(
            'Infini-Stock v1.0.0\n\n'
            'An IoT-based inventory management system for tracking and managing assets, monitors, and system units.\n\n'
            '© 2026 Infini-Stock. All rights reserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _AccountMenuButton extends StatelessWidget {
  final VoidCallback onAccount;
  final VoidCallback onLogout;

  const _AccountMenuButton({
    required this.onAccount,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final fullName = (auth.currentUser?.fullName ?? '').trim();
        final initials = _getInitials(fullName);

        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () async {
            final box = context.findRenderObject() as RenderBox?;
            final overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox?;

            RelativeRect? position;
            if (box != null && overlay != null) {
              final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
              final bottomRight =
                  box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
              position = RelativeRect.fromRect(
                Rect.fromPoints(topLeft, bottomRight),
                Offset.zero & overlay.size,
              );
            }

            final selected = await showMenu<String>(
              context: context,
              color: AppTheme.overlayBg,
              position: position ?? const RelativeRect.fromLTRB(0, 0, 0, 0),
              items: [
                const PopupMenuItem<String>(
                  value: 'account',
                  child: Text(
                    'Account',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            );

            if (selected == 'account') onAccount();
            if (selected == 'logout') onLogout();
          },
          child: Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppTheme.lavender600.withOpacity(0.20),
              border: Border.all(
                color: AppTheme.lavender600.withOpacity(0.30),
              ),
            ),
            child: initials.isEmpty
                ? const Icon(Icons.person, color: AppTheme.lavender300)
                : Text(
                    initials,
                    style: const TextStyle(
                      color: AppTheme.lavender300,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

String _getInitials(String fullName) {
  final name = fullName.trim();
  if (name.isEmpty) return '';
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  final first = parts.isNotEmpty ? parts.first[0] : '';
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row
          Consumer2<MonitorProvider, UnitProvider>(
            builder: (context, monitorProvider, unitProvider, _) {
              final totalAssets =
                  monitorProvider.monitors.length + unitProvider.units.length;
              final activeAssets = monitorProvider.activeMonitors.length +
                  unitProvider.activeUnits.length;
              final brokenAssets = monitorProvider.brokenMonitors.length +
                  unitProvider.brokenUnits.length;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Assets',
                      value: totalAssets,
                      icon: Icons.inventory,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppTheme.lavender600.withOpacity(0.30),
                          AppTheme.lavender500.withOpacity(0.10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Active',
                      value: activeAssets,
                      icon: Icons.check_circle,
                      color: AppTheme.statusSuccess,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppTheme.lavender500.withOpacity(0.25),
                          AppTheme.lavender700.withOpacity(0.10),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Broken/Repair',
                      value: brokenAssets,
                      icon: Icons.warning,
                      color: AppTheme.statusError,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppTheme.lavender700.withOpacity(0.20),
                          AppTheme.lavender600.withOpacity(0.10),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Charts (match web dashboard)
          Consumer3<ActivityLogProvider, MonitorProvider, UnitProvider>(
            builder: (context, logsProvider, monitorProvider, unitProvider, _) {
              return Column(
                children: [
                  DashboardPanel(
                    title: 'Activity',
                    subtitle: 'Activity logs over the last 14 days',
                    icon: Icons.trending_up,
                    child: ActivityLineChart(logs: logsProvider.logs),
                  ),
                  const SizedBox(height: 14),
                  DashboardPanel(
                    title: 'Status',
                    subtitle: 'Asset status distribution',
                    icon: Icons.pie_chart_outline,
                    child: StatusPieChart(
                      monitors: monitorProvider.monitors,
                      units: unitProvider.units,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DashboardPanel(
                    title: 'Location',
                    subtitle: 'Assets grouped by location',
                    icon: Icons.bar_chart,
                    child: LocationStackedBarChart(
                      monitors: monitorProvider.monitors,
                      units: unitProvider.units,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 22),
          // Recent Activity
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          Consumer<ActivityLogProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.logs.isEmpty) {
                return Center(
                  child: Text(
                    'No activity logs',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              final recentLogs = provider.getRecentLogs(5);
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      AppTheme.sidebarBg.withOpacity(0.45),
                    ),
                    columnSpacing: 18,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('QR Code')),
                      DataColumn(label: Text('Details')),
                    ],
                    rows: recentLogs.map((log) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              _formatTime(log.timestamp),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              log.displayAction,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(
                              log.assetQrCode,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                log.displayDetails,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Gradient? gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.lavender600,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.darkBg.withOpacity(0.85) : null,
        border: Border.all(color: AppTheme.borderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withOpacity(0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
          ),
        ],
      ),
    );
  }
}

class MonitorsTab extends StatelessWidget {
  const MonitorsTab({Key? key}) : super(key: key);

  Future<void> _showAddMonitorDialog(BuildContext context) async {
    final deviceNameController = TextEditingController();
    final qrCodeController = TextEditingController();
    final linkedUnitIdController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedStatus = 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryBg,
              title: const Text('Add New Monitor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: deviceNameController,
                      decoration:
                          const InputDecoration(labelText: 'Device Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qrCodeController,
                      decoration: const InputDecoration(labelText: 'QR Code'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                        DropdownMenuItem(
                            value: 'maintenance', child: Text('Maintenance')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStatus = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkedUnitIdController,
                      decoration: const InputDecoration(
                        labelText: 'Linked Unit ID (Optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
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
                  child: const Text('Add Monitor'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    if (deviceNameController.text.trim().isEmpty ||
        qrCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device Name and QR Code are required')),
      );
      return;
    }

    final provider = context.read<MonitorProvider>();
    final ok = await provider.createMonitor(
      deviceNameController.text.trim(),
      qrCodeController.text.trim(),
      selectedStatus,
      linkedUnitId: linkedUnitIdController.text.trim(),
      description: descriptionController.text.trim(),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Monitor added successfully'
            : (provider.error ?? 'Failed to add monitor')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monitors',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMonitorDialog(context),
                    icon: const Icon(Icons.add, size: 13),
                    label: const Text('Add Monitor',
                        style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.monitors.isEmpty
                      ? Center(
                          child: Text(
                            'No monitors found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.monitors.length,
                          itemBuilder: (context, index) {
                            final monitor = provider.monitors[index];
                            return _MonitorCard(
                                monitor: monitor, monitor_provider: provider);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _MonitorCard extends StatelessWidget {
  final monitor;
  final monitor_provider;

  const _MonitorCard({
    required this.monitor,
    required this.monitor_provider,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monitor.deviceName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'QR: ${monitor.qrCode}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: monitor.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code, size: 14),
                    label:
                        const Text('View QR', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      backgroundColor: AppTheme.lavender600.withOpacity(0.2),
                      foregroundColor: AppTheme.lavender300,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      backgroundColor: AppTheme.lavender600.withOpacity(0.2),
                      foregroundColor: AppTheme.lavender300,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'active':
        bgColor = AppTheme.statusSuccess.withOpacity(0.2);
        textColor = AppTheme.statusSuccess;
        icon = Icons.check_circle;
        break;
      case 'maintenance':
        bgColor = AppTheme.statusWarning.withOpacity(0.2);
        textColor = AppTheme.statusWarning;
        icon = Icons.build;
        break;
      case 'broken':
        bgColor = AppTheme.statusError.withOpacity(0.2);
        textColor = AppTheme.statusError;
        icon = Icons.error;
        break;
      default:
        bgColor = AppTheme.textHint.withOpacity(0.1);
        textColor = AppTheme.textHint;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 3),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class UnitsTab extends StatelessWidget {
  const UnitsTab({Key? key}) : super(key: key);

  Future<void> _showAddUnitDialog(BuildContext context) async {
    final deviceNameController = TextEditingController();
    final qrCodeController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedStatus = 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryBg,
              title: const Text('Add New System Unit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: deviceNameController,
                      decoration:
                          const InputDecoration(labelText: 'Device Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: qrCodeController,
                      decoration: const InputDecoration(labelText: 'QR Code'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                        DropdownMenuItem(
                            value: 'maintenance', child: Text('Maintenance')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStatus = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                          labelText: 'Location (Optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Description (Optional)'),
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
                  child: const Text('Add Unit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    if (deviceNameController.text.trim().isEmpty ||
        qrCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device Name and QR Code are required')),
      );
      return;
    }

    final provider = context.read<UnitProvider>();
    final ok = await provider.createUnit(
      deviceNameController.text.trim(),
      qrCodeController.text.trim(),
      selectedStatus,
      location: locationController.text.trim(),
      description: descriptionController.text.trim(),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Unit added successfully'
            : (provider.error ?? 'Failed to add unit')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UnitProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'System Units',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUnitDialog(context),
                    icon: const Icon(Icons.add, size: 13),
                    label:
                        const Text('Add Unit', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.units.isEmpty
                      ? Center(
                          child: Text(
                            'No units found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.units.length,
                          itemBuilder: (context, index) {
                            final unit = provider.units[index];
                            return _UnitCard(unit: unit);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _UnitCard extends StatelessWidget {
  final unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.deviceName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'QR: ${unit.qrCode}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                      ),
                      if (unit.location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${unit.location}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.lavender300,
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status: unit.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code, size: 14),
                    label:
                        const Text('View QR', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      backgroundColor: AppTheme.lavender600.withOpacity(0.2),
                      foregroundColor: AppTheme.lavender300,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      backgroundColor: AppTheme.lavender600.withOpacity(0.2),
                      foregroundColor: AppTheme.lavender300,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityLogsTab extends StatelessWidget {
  const ActivityLogsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityLogProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.logs.isEmpty) {
          return Center(
            child: Text(
              'No activity logs',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  AppTheme.sidebarBg.withOpacity(0.45),
                ),
                columnSpacing: 18,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('QR Code')),
                  DataColumn(label: Text('Details')),
                ],
                rows: provider.logs.map((log) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          log.timestamp.toString().split('.').first,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          log.displayAction,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          log.assetQrCode,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(
                            log.displayDetails,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
