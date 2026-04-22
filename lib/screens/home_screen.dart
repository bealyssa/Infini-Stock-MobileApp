import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/activity_log_provider.dart';
import '../services/api_client.dart';
import '../models/user_model.dart';
import '../models/monitor_model.dart';
import '../models/unit_model.dart';
import 'users_screen.dart';
import '../widgets/dashboard_charts.dart';
import '../services/qr_scanner_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  Timer? _dataRefreshTimer;

  @override
  void initState() {
    super.initState();

    _timeFmt = DateFormat('h:mm:ss a');
    _dateFmt = DateFormat('EEE, MMM d');

    _syncTimeDate();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncTimeDate();
    });

    Future.microtask(_refreshDashboardData);

    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshDashboardData();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _dataRefreshTimer?.cancel();
    super.dispose();
  }

  void _refreshDashboardData() {
    context.read<MonitorProvider>().fetchMonitors();
    context.read<UnitProvider>().fetchUnits();
    context.read<ActivityLogProvider>().fetchActivityLogs();
    context.read<AuthProvider>().refreshMe();
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

  Future<void> _openQrScanner() async {
    final qrCode = await QRScannerHelper.scanQRCode(context);
    if (!mounted || qrCode == null || qrCode.trim().isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Scanning QR code...')),
    );

    final api = ApiClient();

    try {
      final scanResponse = await api.post(
        '/assets/scan',
        data: {'qrCode': qrCode.trim()},
      );

      final baseAsset = Map<String, dynamic>.from(
        scanResponse.data as Map<String, dynamic>,
      );

      final type = (baseAsset['type'] as String? ?? '').toLowerCase();
      final scannedCode = (baseAsset['qrCode'] as String? ?? '').trim();
      Map<String, dynamic> details = {};

      if (type == 'monitor') {
        final monitors = await api.listMonitors();
        final monitorMaps = monitors
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        details = monitorMaps.firstWhere(
          (m) => (m['qrCode'] as String? ?? '').trim() == scannedCode,
          orElse: () => <String, dynamic>{},
        );
      } else if (type == 'unit') {
        final units = await api.listUnits();
        final unitMaps = units
            .whereType<Map>()
            .map((u) => Map<String, dynamic>.from(u))
            .toList();
        details = unitMaps.firstWhere(
          (u) => (u['qrCode'] as String? ?? '').trim() == scannedCode,
          orElse: () => <String, dynamic>{},
        );
      }

      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      await showAssetDetailsModal(context, {
        ...baseAsset,
        ...details,
      });
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Scan failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardTab(),
      const MonitorsTab(),
      const UnitsTab(),
      const ActivityLogsTab(),
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
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              selected: _selectedIndex == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 4);
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
            icon: Icon(Icons.people),
            label: 'Users',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQrScanner,
        backgroundColor: AppTheme.lavender600,
        foregroundColor: AppTheme.textPrimary,
        tooltip: 'Scan QR',
        child: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

InputDecoration _compactInputDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

BoxDecoration _balancedSurfaceDecoration({bool elevated = false}) {
  return BoxDecoration(
    gradient: elevated
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.sidebarBg.withOpacity(0.48),
              AppTheme.darkBg.withOpacity(0.90),
            ],
          )
        : null,
    color: elevated ? null : AppTheme.darkBg.withOpacity(0.88),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppTheme.borderDark),
  );
}

BoxDecoration _balancedInsetDecoration() {
  return BoxDecoration(
    color: AppTheme.primaryBg.withOpacity(0.45),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppTheme.borderDark),
  );
}

String _csvCell(dynamic value) {
  final raw = (value ?? '').toString().replaceAll('"', '""');
  return '"$raw"';
}

String _buildCsv(List<String> headers, List<List<dynamic>> rows) {
  final lines = <String>[];
  lines.add(headers.map(_csvCell).join(','));
  for (final row in rows) {
    lines.add(row.map(_csvCell).join(','));
  }
  return lines.join('\n');
}

Future<void> _exportCsv(
  BuildContext context, {
  required String fileName,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No data to export')),
    );
    return;
  }

  final csv = _buildCsv(headers, rows);
  try {
    await Share.share(csv, subject: fileName);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard')),
    );
  }
}

Future<void> _showPrintQrDialog(
  BuildContext context, {
  required String title,
  required String qrCode,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        title: Text('Print QR: $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 170,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              qrCode,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Share.share('Asset: $title\nQR: $qrCode', subject: 'Print QR');
            },
            child: const Text('Print/Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showAssetHistoryDialog(
  BuildContext context, {
  required String assetId,
  required String assetQrCode,
  required String title,
}) async {
  final provider = context.read<ActivityLogProvider>();
  await provider.fetchActivityLogs(limit: 500);

  String norm(String value) => value.trim().toLowerCase();
  final idKey = norm(assetId);
  final qrKey = norm(assetQrCode);
  final titleKey = norm(title);

  bool same(String? value, String key) {
    if (key.isEmpty) return false;
    final v = value?.trim().toLowerCase();
    return v != null && v.isNotEmpty && v == key;
  }

  bool titleMatches(String? value) {
    if (titleKey.isEmpty) return false;
    final v = value?.trim().toLowerCase();
    return v != null && v.isNotEmpty &&
        (v == titleKey || v.contains(titleKey) || titleKey.contains(v));
  }

  final logs = provider.logs.where((log) {
    return same(log.assetId, idKey) ||
        same(log.assetQrCode, qrKey) ||
        same(log.itemQr, qrKey) ||
        same(log.deletedItemQr, qrKey) ||
        titleMatches(log.itemName) ||
        titleMatches(log.deletedItemName);
  }).toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final width = MediaQuery.of(ctx).size.width;
      final compact = width < 760;
      return AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activity History'),
            const SizedBox(height: 6),
            Text(
              '$title${assetQrCode.isEmpty ? '' : ' ($assetQrCode)'}',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppTheme.borderDark, height: 1),
          ],
        ),
        content: SizedBox(
          width: compact ? width * 0.9 : 900,
          child: logs.isEmpty
              ? const Text('No update history found for this asset.')
              : compact
                  ? ListView.separated(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: _balancedInsetDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat('M/d/yyyy, h:mm:ss a').format(log.timestamp)} • ${log.displayAction}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'User: ${log.updaterDisplayName}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                log.displayDetails,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppTheme.primaryBg.withOpacity(0.55),
                        ),
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 58,
                        horizontalMargin: 14,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('DATE/TIME')),
                          DataColumn(label: Text('ACTION')),
                          DataColumn(label: Text('USER')),
                          DataColumn(label: Text('DETAILS')),
                        ],
                        rows: logs.map((log) {
                          return DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    DateFormat('M/d/yyyy, h:mm:ss a')
                                        .format(log.timestamp),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lavender700.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(log.action.toLowerCase()),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 140,
                                  child: Text(log.updaterDisplayName),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 360,
                                  child: Text(
                                    log.displayDetails,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Map<String, dynamic> _monitorToAssetMap(Monitor monitor) {
  return {
    'id': monitor.id,
    'deviceName': monitor.deviceName,
    'qrCode': monitor.qrCode,
    'type': 'monitor',
    'status': monitor.status,
    'condition': monitor.condition,
    'location': monitor.location,
    'modelType': monitor.modelType,
    'serialNumber': monitor.serialNumber,
    'imageData': monitor.imageData,
    'description': monitor.description,
    'notes': monitor.notes,
    'createdBy': monitor.createdBy,
    'createdAt': monitor.createdAt?.toIso8601String(),
    'updatedAt': monitor.updatedAt?.toIso8601String(),
    'linkedUnit': monitor.linkedUnit,
  };
}

Map<String, dynamic> _unitToAssetMap(Unit unit) {
  return {
    'id': unit.id,
    'deviceName': unit.deviceName,
    'qrCode': unit.qrCode,
    'type': 'unit',
    'status': unit.status,
    'condition': unit.condition,
    'location': unit.location,
    'modelType': unit.modelType,
    'serialNumber': unit.serialNumber,
    'imageData': unit.imageData,
    'description': unit.description,
    'notes': unit.notes,
    'createdBy': unit.createdBy,
    'createdAt': unit.createdAt?.toIso8601String(),
    'updatedAt': unit.updatedAt?.toIso8601String(),
    'linkedMonitor': unit.linkedMonitor,
  };
}

String _linkedAssetLabel(Map<String, dynamic> asset) {
  final isUnit = asset['type'] == 'unit';
  final linkedAsset = isUnit ? asset['linkedMonitor'] : asset['linkedUnit'];
  if (linkedAsset is Map) {
    final linkedMap = Map<String, dynamic>.from(linkedAsset);
    final name = linkedMap['deviceName']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final qrCode = linkedMap['qrCode']?.toString().trim();
    if (qrCode != null && qrCode.isNotEmpty) return qrCode;
  }

  final linkedId = isUnit ? asset['linkedMonitorId'] : asset['linkedUnitId'];
  final text = linkedId?.toString().trim();
  return (text == null || text.isEmpty) ? '—' : text;
}

Future<void> showAssetDetailsModal(
  BuildContext context,
  Map<String, dynamic> asset,
) async {
  String assetValue(dynamic value) {
    if (value == null) return '—';
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  Widget detailBox(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            assetValue(value),
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  final media = MediaQuery.of(context);
  final compact = media.size.width < 600;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 24,
          vertical: compact ? 10 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? media.size.width - 20 : 860,
            maxHeight: media.size.height * 0.92,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF211339),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assetValue(asset['deviceName']),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'QR: ${assetValue(asset['qrCode'])}',
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.borderDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow = constraints.maxWidth < 700;
                            final imageSection = Container(
                              height: narrow ? 220 : 260,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderDark),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: assetValue(asset['imageData']) == '—'
                                    ? const Center(
                                        child: Text(
                                          'No image',
                                          style: TextStyle(
                                            color: AppTheme.textTertiary,
                                          ),
                                        ),
                                      )
                                    : Image.network(
                                        asset['imageData'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Text(
                                            'No image',
                                            style: TextStyle(
                                              color: AppTheme.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            );

                            final qrSection = Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderDark),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: QrImageView(
                                      data: assetValue(asset['qrCode']) == '—'
                                          ? 'N/A'
                                          : asset['qrCode'].toString(),
                                      version: QrVersions.auto,
                                      size: 150,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    assetValue(asset['qrCode']),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (narrow) {
                              return Column(
                                children: [
                                  imageSection,
                                  const SizedBox(height: 12),
                                  qrSection,
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: imageSection),
                                const SizedBox(width: 12),
                                SizedBox(width: 220, child: qrSection),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (assetValue(asset['status']) != '—')
                              _StatusBadge(status: assetValue(asset['status'])),
                            if (assetValue(asset['condition']) != '—')
                              _StatusBadge(status: assetValue(asset['condition'])),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth < 700 ? 1 : 2;
                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: crossAxisCount == 1 ? 3.0 : 2.2,
                              children: [
                                detailBox('Device Name', asset['deviceName']),
                                detailBox('QR Code', asset['qrCode']),
                                detailBox('Type', asset['type']),
                                detailBox('Status', asset['status']),
                                detailBox('Condition', asset['condition']),
                                detailBox('Location', asset['location']),
                                detailBox('Model Type', asset['modelType']),
                                detailBox('Serial Number', asset['serialNumber']),
                                detailBox('Created By', asset['createdBy']),
                                detailBox('Created At', asset['createdAt']),
                                detailBox('Updated At', asset['updatedAt']),
                                detailBox(
                                  asset['type'] == 'unit' ? 'Linked Monitor' : 'Linked Unit',
                                  _linkedAssetLabel(asset),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        detailBox('Description', asset['description']),
                        const SizedBox(height: 10),
                        detailBox('Notes', asset['notes']),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
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
                decoration: _balancedSurfaceDecoration(elevated: true),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 720) {
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(14),
                        itemCount: recentLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final log = recentLogs[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: _balancedInsetDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_formatTime(log.timestamp)} • ${log.displayAction}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'QR: ${log.assetQrCode}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log.displayDetails,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
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
                          AppTheme.primaryBg.withOpacity(0.55),
                        ),
                        dataRowMinHeight: 42,
                        dataRowMaxHeight: 54,
                        columnSpacing: 18,
                        horizontalMargin: 14,
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
                                      width: 200,
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
                    );
                  },
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.darkBg.withOpacity(0.88) : null,
        border: Border.all(color: AppTheme.borderDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBg.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class MonitorsTab extends StatefulWidget {
  const MonitorsTab({Key? key}) : super(key: key);

  @override
  State<MonitorsTab> createState() => _MonitorsTabState();
}

class _MonitorsTabState extends State<MonitorsTab> {
  String _query = '';
  String _statusFilter = 'all';
  bool _suppressCardTap = false;

  Future<void> _afterMenuClose(Future<void> Function() action) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    await action();
  }

  Future<void> _exportMonitorsCsv(
    BuildContext context,
    List<Monitor> monitors,
  ) async {
    await _exportCsv(
      context,
      fileName: 'monitors_export.csv',
      headers: const [
        'Device Name',
        'QR Code',
        'Status',
        'Linked Unit',
        'Location',
        'Description',
        'Updated At',
      ],
      rows: monitors
          .map(
            (m) => [
              m.deviceName,
              m.qrCode,
              m.status,
              m.linkedUnit ?? '',
              m.location ?? '',
              m.description ?? '',
              m.updatedAt?.toIso8601String() ?? '',
            ],
          )
          .toList(),
    );
  }

  Future<void> _showEditMonitorDialog(
    BuildContext context,
    Monitor monitor,
  ) async {
    final deviceNameController = TextEditingController(text: monitor.deviceName);
    final qrCodeController = TextEditingController(text: monitor.qrCode);
    final linkedUnitIdController = TextEditingController(text: monitor.linkedUnit ?? '');
    final locationController = TextEditingController(text: monitor.location ?? '');
    final descriptionController = TextEditingController(text: monitor.description ?? '');
    String selectedStatus = monitor.status;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryBg,
              title: const Text('Edit Monitor'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 560.0;
                      final twoCol = availableWidth >= 460;

                      final nameField = TextField(
                        controller: deviceNameController,
                        decoration: _compactInputDecoration(label: 'Device Name'),
                      );
                      final qrField = TextField(
                        controller: qrCodeController,
                        decoration: _compactInputDecoration(label: 'QR Code'),
                      );
                      final statusField = DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(value: 'broken', child: Text('Broken')),
                          DropdownMenuItem(value: 'repair', child: Text('Repair')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedStatus = value);
                          }
                        },
                        decoration: _compactInputDecoration(label: 'Status'),
                      );
                      final linkedField = TextField(
                        controller: linkedUnitIdController,
                        decoration: _compactInputDecoration(
                          label: 'Linked Unit ID',
                          hint: 'Optional',
                        ),
                      );
                      final locationField = TextField(
                        controller: locationController,
                        decoration: _compactInputDecoration(
                          label: 'Location',
                          hint: 'Optional',
                        ),
                      );
                      final descriptionField = TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: _compactInputDecoration(
                          label: 'Description',
                          hint: 'Optional',
                        ),
                      );

                      Widget vGap([double h = 10]) => SizedBox(height: h);

                      if (!twoCol) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            nameField,
                            vGap(),
                            qrField,
                            vGap(),
                            statusField,
                            vGap(),
                            linkedField,
                            vGap(),
                            locationField,
                            vGap(),
                            descriptionField,
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: nameField),
                              const SizedBox(width: 12),
                              Expanded(child: qrField),
                            ],
                          ),
                          vGap(),
                          Row(
                            children: [
                              Expanded(child: statusField),
                              const SizedBox(width: 12),
                              Expanded(child: linkedField),
                            ],
                          ),
                          vGap(),
                          locationField,
                          vGap(),
                          descriptionField,
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (deviceNameController.text.trim().isEmpty ||
        qrCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device Name and QR Code are required')),
      );
      return;
    }

    try {
      final payload = <String, dynamic>{
        'deviceName': deviceNameController.text.trim(),
        'qrCode': qrCodeController.text.trim(),
        'status': selectedStatus,
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
      };

      final linked = linkedUnitIdController.text.trim();
      if (linked.isNotEmpty) {
        payload['linkedUnitId'] = linked;
      }

      await ApiClient().updateMonitor(monitor.id, payload);
      if (!context.mounted) return;

      await context.read<MonitorProvider>().fetchMonitors();
      await context.read<ActivityLogProvider>().fetchActivityLogs(limit: 200);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitor updated successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update monitor: $e')),
      );
    }
  }

  Future<void> _deleteMonitor(BuildContext context, Monitor monitor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        title: const Text('Delete Monitor'),
        content: Text('Delete ${monitor.deviceName}? This action cannot be undone.'),
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

    if (confirmed != true) return;

    try {
      await ApiClient().deleteMonitor(monitor.id);
      if (!context.mounted) return;
      await context.read<MonitorProvider>().fetchMonitors();
      await context.read<ActivityLogProvider>().fetchActivityLogs(limit: 200);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitor deleted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete monitor: $e')),
      );
    }
  }

  Future<void> _handleMonitorAction(
    BuildContext context,
    String action,
    Monitor monitor,
  ) async {
    final rootContext = mounted ? this.context : context;
    if (action == 'edit') {
      await _showEditMonitorDialog(rootContext, monitor);
      return;
    }

    if (action == 'history') {
      await _showAssetHistoryDialog(
        rootContext,
        assetId: monitor.id,
        assetQrCode: monitor.qrCode,
        title: monitor.deviceName,
      );
      return;
    }

    if (action == 'print') {
      await _showPrintQrDialog(
        rootContext,
        title: monitor.deviceName,
        qrCode: monitor.qrCode,
      );
      return;
    }

    if (action == 'delete') {
      await _deleteMonitor(rootContext, monitor);
    }
  }

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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 560.0;
                      final twoCol = availableWidth >= 460;

                      final nameField = TextField(
                        controller: deviceNameController,
                        decoration: _compactInputDecoration(label: 'Device Name'),
                      );
                      final qrField = TextField(
                        controller: qrCodeController,
                        decoration: _compactInputDecoration(label: 'QR Code'),
                      );
                      final statusField = DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedStatus = value);
                          }
                        },
                        decoration: _compactInputDecoration(label: 'Status'),
                      );
                      final linkedField = TextField(
                        controller: linkedUnitIdController,
                        decoration: _compactInputDecoration(
                          label: 'Linked Unit ID',
                          hint: 'Optional',
                        ),
                      );
                      final descriptionField = TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: _compactInputDecoration(
                          label: 'Description',
                          hint: 'Optional',
                        ),
                      );

                      Widget vGap([double h = 10]) => SizedBox(height: h);

                      if (!twoCol) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            nameField,
                            vGap(),
                            qrField,
                            vGap(),
                            statusField,
                            vGap(),
                            linkedField,
                            vGap(),
                            descriptionField,
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: nameField),
                              const SizedBox(width: 12),
                              Expanded(child: qrField),
                            ],
                          ),
                          vGap(),
                          Row(
                            children: [
                              Expanded(child: statusField),
                              const SizedBox(width: 12),
                              Expanded(child: linkedField),
                            ],
                          ),
                          vGap(),
                          descriptionField,
                        ],
                      );
                    },
                  ),
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

    if (saved != true) return;

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
        final filtered = provider.monitors.where((m) {
          final statusOk = _statusFilter == 'all' ||
              m.status.toLowerCase() == _statusFilter.toLowerCase();
          final q = _query.toLowerCase();
          final searchOk = q.isEmpty ||
              m.deviceName.toLowerCase().contains(q) ||
              m.qrCode.toLowerCase().contains(q) ||
              (m.linkedUnit ?? '').toLowerCase().contains(q) ||
              (m.description ?? '').toLowerCase().contains(q);
          return statusOk && searchOk;
        }).toList();

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
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: provider.fetchMonitors,
                        icon: const Icon(Icons.refresh),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _exportMonitorsCsv(context, filtered),
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Export CSV', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCol = constraints.maxWidth >= 700;
                  final fieldWidth = twoCol
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          decoration: _compactInputDecoration(
                            label: 'Search',
                            hint: 'Name, QR, linked unit, description',
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All statuses')),
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                            DropdownMenuItem(
                                value: 'maintenance', child: Text('Maintenance')),
                            DropdownMenuItem(value: 'broken', child: Text('Broken')),
                            DropdownMenuItem(value: 'repair', child: Text('Repair')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _statusFilter = value);
                            }
                          },
                          decoration: _compactInputDecoration(
                            label: 'Filter by status',
                            prefixIcon:
                                const Icon(Icons.filter_alt_outlined),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No monitors found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 760) {
                              return ListView.separated(
                                            padding: const EdgeInsets.all(14),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final monitor = filtered[index];
                                  return InkWell(
                                    onTap: _suppressCardTap
                                        ? null
                                        : () => showAssetDetailsModal(
                                              context,
                                              _monitorToAssetMap(monitor),
                                            ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: _balancedSurfaceDecoration(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.lavender600
                                                      .withOpacity(0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.devices,
                                                  size: 18,
                                                  color: AppTheme.lavender300,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      monitor.deviceName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      monitor.qrCode,
                                                      style: const TextStyle(
                                                        color: AppTheme.textTertiary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _StatusBadge(status: monitor.status),
                                              PopupMenuButton<String>(
                                                tooltip: 'Actions',
                                                onOpened: () {
                                                  if (!mounted) return;
                                                  setState(() => _suppressCardTap = true);
                                                },
                                                onCanceled: () {
                                                  if (!mounted) return;
                                                  setState(() => _suppressCardTap = false);
                                                },
                                                onSelected: (value) {
                                                  if (mounted) {
                                                    setState(() => _suppressCardTap = false);
                                                  }
                                                  _afterMenuClose(
                                                    () => _handleMonitorAction(
                                                      context,
                                                      value,
                                                      monitor,
                                                    ),
                                                  );
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.edit_outlined),
                                                      title: Text('Edit'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'history',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.history),
                                                      title: Text('View History'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'print',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.qr_code_2),
                                                      title: Text('Print QR'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.delete_outline),
                                                      title: Text('Delete'),
                                                    ),
                                                  ),
                                                ],
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4.0),
                                                  child: Icon(Icons.more_horiz),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _ChipPill(
                                                label: 'Linked: ${monitor.linkedUnit ?? 'N/A'}',
                                              ),
                                              _ChipPill(
                                                label: 'Desc: ${monitor.description ?? 'No description'}',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppTheme.primaryBg.withOpacity(0.55),
                                  ),
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 58,
                                  dividerThickness: 0.8,
                                  columns: const [
                                    DataColumn(label: Text('Device Name')),
                                    DataColumn(label: Text('QR Code')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Linked Unit')),
                                    DataColumn(label: Text('Description')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filtered.map((monitor) {
                                    return DataRow(
                                      onSelectChanged: (_) =>
                                          showAssetDetailsModal(
                                        context,
                                        _monitorToAssetMap(monitor),
                                      ),
                                      cells: [
                                        DataCell(Text(monitor.deviceName)),
                                        DataCell(Text(monitor.qrCode)),
                                        DataCell(
                                            _StatusBadge(status: monitor.status)),
                                        DataCell(Text(monitor.linkedUnit ?? 'N/A')),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              monitor.description ?? 'N/A',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          PopupMenuButton<String>(
                                            tooltip: 'Actions',
                                            onSelected: (value) {
                                              _afterMenuClose(
                                                () => _handleMonitorAction(
                                                  this.context,
                                                  value,
                                                  monitor,
                                                ),
                                              );
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem(
                                                value: 'history',
                                                child: Text('View History'),
                                              ),
                                              PopupMenuItem(
                                                value: 'print',
                                                child: Text('Print QR'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                            child: const SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: Center(
                                                child: Icon(Icons.more_horiz),
                                              ),
                                            ),
                                          ),
                                          onTap: () {},
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
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

    switch (status.toLowerCase()) {
      case 'active':
        bgColor = AppTheme.statusSuccess.withOpacity(0.2);
        textColor = AppTheme.statusSuccess;
        break;
      case 'maintenance':
        bgColor = AppTheme.statusWarning.withOpacity(0.2);
        textColor = AppTheme.statusWarning;
        break;
      case 'broken':
        bgColor = AppTheme.statusError.withOpacity(0.2);
        textColor = AppTheme.statusError;
        break;
      default:
        bgColor = AppTheme.textHint.withOpacity(0.1);
        textColor = AppTheme.textHint;
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

class _ChipPill extends StatelessWidget {
  final String label;

  const _ChipPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBg.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class UnitsTab extends StatefulWidget {
  const UnitsTab({Key? key}) : super(key: key);

  @override
  State<UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends State<UnitsTab> {
  String _query = '';
  String _statusFilter = 'all';
  bool _suppressCardTap = false;

  Future<void> _afterMenuClose(Future<void> Function() action) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;
    await action();
  }

  Future<void> _exportUnitsCsv(BuildContext context, List<Unit> units) async {
    await _exportCsv(
      context,
      fileName: 'units_export.csv',
      headers: const [
        'Device Name',
        'QR Code',
        'Status',
        'Location',
        'Description',
        'Updated At',
      ],
      rows: units
          .map(
            (u) => [
              u.deviceName,
              u.qrCode,
              u.status,
              u.location ?? '',
              u.description ?? '',
              u.updatedAt?.toIso8601String() ?? '',
            ],
          )
          .toList(),
    );
  }

  Future<void> _showEditUnitDialog(BuildContext context, Unit unit) async {
    final deviceNameController = TextEditingController(text: unit.deviceName);
    final qrCodeController = TextEditingController(text: unit.qrCode);
    final locationController = TextEditingController(text: unit.location ?? '');
    final descriptionController = TextEditingController(text: unit.description ?? '');
    String selectedStatus = unit.status;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryBg,
              title: const Text('Edit Unit'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 560.0;
                      final twoCol = availableWidth >= 460;

                      final nameField = TextField(
                        controller: deviceNameController,
                        decoration: _compactInputDecoration(label: 'Device Name'),
                      );
                      final qrField = TextField(
                        controller: qrCodeController,
                        decoration: _compactInputDecoration(label: 'QR Code'),
                      );
                      final statusField = DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(value: 'broken', child: Text('Broken')),
                          DropdownMenuItem(value: 'repair', child: Text('Repair')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedStatus = value);
                          }
                        },
                        decoration: _compactInputDecoration(label: 'Status'),
                      );
                      final locationField = TextField(
                        controller: locationController,
                        decoration: _compactInputDecoration(
                          label: 'Location',
                          hint: 'Optional',
                        ),
                      );
                      final descriptionField = TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: _compactInputDecoration(
                          label: 'Description',
                          hint: 'Optional',
                        ),
                      );

                      Widget vGap([double h = 10]) => SizedBox(height: h);

                      if (!twoCol) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            nameField,
                            vGap(),
                            qrField,
                            vGap(),
                            statusField,
                            vGap(),
                            locationField,
                            vGap(),
                            descriptionField,
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: nameField),
                              const SizedBox(width: 12),
                              Expanded(child: qrField),
                            ],
                          ),
                          vGap(),
                          Row(
                            children: [
                              Expanded(child: statusField),
                              const SizedBox(width: 12),
                              Expanded(child: locationField),
                            ],
                          ),
                          vGap(),
                          descriptionField,
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (deviceNameController.text.trim().isEmpty ||
        qrCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device Name and QR Code are required')),
      );
      return;
    }

    try {
      await ApiClient().updateUnit(
        unit.id,
        {
          'deviceName': deviceNameController.text.trim(),
          'qrCode': qrCodeController.text.trim(),
          'status': selectedStatus,
          'location': locationController.text.trim(),
          'description': descriptionController.text.trim(),
        },
      );

      if (!context.mounted) return;
      await context.read<UnitProvider>().fetchUnits();
      await context.read<ActivityLogProvider>().fetchActivityLogs(limit: 200);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit updated successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update unit: $e')),
      );
    }
  }

  Future<void> _deleteUnit(BuildContext context, Unit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        title: const Text('Delete Unit'),
        content: Text('Delete ${unit.deviceName}? This action cannot be undone.'),
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

    if (confirmed != true) return;

    try {
      await ApiClient().deleteUnit(unit.id);
      if (!context.mounted) return;
      await context.read<UnitProvider>().fetchUnits();
      await context.read<ActivityLogProvider>().fetchActivityLogs(limit: 200);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit deleted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete unit: $e')),
      );
    }
  }

  Future<void> _handleUnitAction(
    BuildContext context,
    String action,
    Unit unit,
  ) async {
    final rootContext = mounted ? this.context : context;
    if (action == 'edit') {
      await _showEditUnitDialog(rootContext, unit);
      return;
    }

    if (action == 'history') {
      await _showAssetHistoryDialog(
        rootContext,
        assetId: unit.id,
        assetQrCode: unit.qrCode,
        title: unit.deviceName,
      );
      return;
    }

    if (action == 'print') {
      await _showPrintQrDialog(
        rootContext,
        title: unit.deviceName,
        qrCode: unit.qrCode,
      );
      return;
    }

    if (action == 'delete') {
      await _deleteUnit(rootContext, unit);
    }
  }

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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth.isFinite &&
                              constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 560.0;
                      final twoCol = availableWidth >= 460;

                      final nameField = TextField(
                        controller: deviceNameController,
                        decoration: _compactInputDecoration(label: 'Device Name'),
                      );
                      final qrField = TextField(
                        controller: qrCodeController,
                        decoration: _compactInputDecoration(label: 'QR Code'),
                      );
                      final statusField = DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedStatus = value);
                          }
                        },
                        decoration: _compactInputDecoration(label: 'Status'),
                      );
                      final locationField = TextField(
                        controller: locationController,
                        decoration: _compactInputDecoration(
                          label: 'Location',
                          hint: 'Optional',
                        ),
                      );
                      final descriptionField = TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: _compactInputDecoration(
                          label: 'Description',
                          hint: 'Optional',
                        ),
                      );

                      Widget vGap([double h = 10]) => SizedBox(height: h);

                      if (!twoCol) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            nameField,
                            vGap(),
                            qrField,
                            vGap(),
                            statusField,
                            vGap(),
                            locationField,
                            vGap(),
                            descriptionField,
                          ],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: nameField),
                              const SizedBox(width: 12),
                              Expanded(child: qrField),
                            ],
                          ),
                          vGap(),
                          Row(
                            children: [
                              Expanded(child: statusField),
                              const SizedBox(width: 12),
                              Expanded(child: locationField),
                            ],
                          ),
                          vGap(),
                          descriptionField,
                        ],
                      );
                    },
                  ),
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

    if (saved != true) return;

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
        content:
            Text(ok ? 'Unit added successfully' : (provider.error ?? 'Failed')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UnitProvider>(
      builder: (context, provider, _) {
        final filtered = provider.units.where((u) {
          final statusOk = _statusFilter == 'all' ||
              u.status.toLowerCase() == _statusFilter.toLowerCase();
          final q = _query.toLowerCase();
          final searchOk = q.isEmpty ||
              u.deviceName.toLowerCase().contains(q) ||
              u.qrCode.toLowerCase().contains(q) ||
              (u.location ?? '').toLowerCase().contains(q) ||
              (u.description ?? '').toLowerCase().contains(q);
          return statusOk && searchOk;
        }).toList();

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
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: provider.fetchUnits,
                        icon: const Icon(Icons.refresh),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _exportUnitsCsv(context, filtered),
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Export CSV', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCol = constraints.maxWidth >= 700;
                  final fieldWidth = twoCol
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          decoration: _compactInputDecoration(
                            label: 'Search',
                            hint: 'Name, QR, location, description',
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All statuses')),
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                            DropdownMenuItem(
                                value: 'maintenance', child: Text('Maintenance')),
                            DropdownMenuItem(value: 'broken', child: Text('Broken')),
                            DropdownMenuItem(value: 'repair', child: Text('Repair')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _statusFilter = value);
                            }
                          },
                          decoration: _compactInputDecoration(
                            label: 'Filter by status',
                            prefixIcon:
                                const Icon(Icons.filter_alt_outlined),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No units found',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 760) {
                              return ListView.separated(
                                            padding: const EdgeInsets.all(14),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final unit = filtered[index];
                                  return InkWell(
                                    onTap: _suppressCardTap
                                        ? null
                                        : () => showAssetDetailsModal(
                                              context,
                                              _unitToAssetMap(unit),
                                            ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: _balancedSurfaceDecoration(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.lavender600
                                                      .withOpacity(0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.inventory_2,
                                                  size: 18,
                                                  color: AppTheme.lavender300,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      unit.deviceName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      unit.qrCode,
                                                      style: const TextStyle(
                                                        color: AppTheme.textTertiary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _StatusBadge(status: unit.status),
                                              PopupMenuButton<String>(
                                                tooltip: 'Actions',
                                                onOpened: () {
                                                  if (!mounted) return;
                                                  setState(() => _suppressCardTap = true);
                                                },
                                                onCanceled: () {
                                                  if (!mounted) return;
                                                  setState(() => _suppressCardTap = false);
                                                },
                                                onSelected: (value) {
                                                  if (mounted) {
                                                    setState(() => _suppressCardTap = false);
                                                  }
                                                  _afterMenuClose(
                                                    () => _handleUnitAction(
                                                      context,
                                                      value,
                                                      unit,
                                                    ),
                                                  );
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.edit_outlined),
                                                      title: Text('Edit'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'history',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.history),
                                                      title: Text('View History'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'print',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.qr_code_2),
                                                      title: Text('Print QR'),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: ListTile(
                                                      dense: true,
                                                      leading: Icon(Icons.delete_outline),
                                                      title: Text('Delete'),
                                                    ),
                                                  ),
                                                ],
                                                child: const Padding(
                                                  padding: EdgeInsets.all(4.0),
                                                  child: Icon(Icons.more_horiz),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _ChipPill(
                                                label: 'Location: ${unit.location ?? 'N/A'}',
                                              ),
                                              _ChipPill(
                                                label: 'Desc: ${unit.description ?? 'No description'}',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    AppTheme.primaryBg.withOpacity(0.55),
                                  ),
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 58,
                                  dividerThickness: 0.8,
                                  columns: const [
                                    DataColumn(label: Text('Device Name')),
                                    DataColumn(label: Text('QR Code')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Location')),
                                    DataColumn(label: Text('Description')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filtered.map((unit) {
                                    return DataRow(
                                      onSelectChanged: (_) =>
                                          showAssetDetailsModal(
                                        context,
                                        _unitToAssetMap(unit),
                                      ),
                                      cells: [
                                        DataCell(Text(unit.deviceName)),
                                        DataCell(Text(unit.qrCode)),
                                        DataCell(_StatusBadge(status: unit.status)),
                                        DataCell(Text(unit.location ?? 'N/A')),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Text(
                                              unit.description ?? 'N/A',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          PopupMenuButton<String>(
                                            tooltip: 'Actions',
                                            onSelected: (value) {
                                              _afterMenuClose(
                                                () => _handleUnitAction(
                                                  this.context,
                                                  value,
                                                  unit,
                                                ),
                                              );
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              PopupMenuItem(
                                                value: 'history',
                                                child: Text('View History'),
                                              ),
                                              PopupMenuItem(
                                                value: 'print',
                                                child: Text('Print QR'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                            child: const SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: Center(
                                                child: Icon(Icons.more_horiz),
                                              ),
                                            ),
                                          ),
                                          onTap: () {},
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
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
            decoration: _balancedSurfaceDecoration(elevated: true),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: provider.logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = provider.logs[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: _balancedInsetDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.lavender600.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.history,
                                    size: 18,
                                    color: AppTheme.lavender300,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.timestamp.toString().split('.').first,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        log.displayAction,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ChipPill(label: 'QR: ${log.assetQrCode}'),
                                _ChipPill(label: 'User: ${log.updaterDisplayName}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              log.displayDetails,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
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
                      AppTheme.primaryBg.withOpacity(0.55),
                    ),
                    dataRowMinHeight: 42,
                    dataRowMaxHeight: 56,
                    columnSpacing: 18,
                    horizontalMargin: 14,
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
                );
              },
            ),
          ),
        );
      },
    );
  }
}
