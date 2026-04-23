import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/activity_log_provider.dart';
import '../services/api_client.dart';
import '../models/user_model.dart';
import '../models/activity_log_model.dart';
import '../models/monitor_model.dart';
import '../models/unit_model.dart';
import 'users_screen.dart' show UsersScreen;
import '../widgets/dashboard_charts.dart';
import '../services/qr_scanner_helper.dart';
import '../utils/rbac.dart';
import '../utils/responsive.dart';
import 'package:qr_flutter/qr_flutter.dart';

bool _isValidSerialNumber(String value) {
  return RegExp(r'^\d{5}$').hasMatch(value.trim());
}

String _infocomDeviceIdFromUuid(String uuid) {
  final trimmed = uuid.trim();
  if (trimmed.isEmpty) return '—';

  final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  final last4 = digitsOnly.length >= 4
      ? digitsOnly.substring(digitsOnly.length - 4)
      : digitsOnly.padLeft(4, '0');

  final compact = trimmed.replaceAll('-', '');
  final short = compact.length > 8 ? compact.substring(0, 8) : compact;

  return 'Infocom-$last4($short)';
}

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

  String? _extractQrCodeFromPayload(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // If QR contains JSON (device info), extract the qrCode field.
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          dynamic candidate = map['qrCode'] ?? map['qrcode'] ?? map['code'];
          candidate ??= (map['asset'] is Map)
              ? (Map<String, dynamic>.from(map['asset'] as Map)['qrCode'])
              : null;
          final extracted = candidate?.toString().trim();
          if (extracted != null && extracted.isNotEmpty) return extracted;
        }
      } catch (_) {
        // Not valid JSON; fall through.
      }
    }

    // If QR contains a URL, accept `?qrCode=` or last path segment.
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.hasScheme || uri.host.isNotEmpty)) {
      final qp = uri.queryParameters['qrCode'] ??
          uri.queryParameters['qrcode'] ??
          uri.queryParameters['code'];
      final qpTrim = qp?.trim();
      if (qpTrim != null && qpTrim.isNotEmpty) return qpTrim;

      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = segments.last.trim();
        if (last.isNotEmpty) return last;
      }
    }

    // Handle simple prefixes like "qrCode: XYZ".
    final prefix =
        RegExp(r'^(qrCode|qrcode|qr)\s*[:=]\s*(.+)$', caseSensitive: false)
            .firstMatch(text);
    if (prefix != null) {
      final extracted = prefix.group(2)?.trim();
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }

    return text;
  }

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
    final qrCode = await QRScannerHelperV2.scanQRCode(context);
    if (!mounted || qrCode == null || qrCode.trim().isEmpty) {
      return;
    }

    final normalizedCode = _extractQrCodeFromPayload(qrCode);
    if (normalizedCode == null || normalizedCode.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code payload')),
      );
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
        data: {'qrCode': normalizedCode.trim()},
      );

      final baseAsset = Map<String, dynamic>.from(
        scanResponse.data as Map<String, dynamic>,
      );

      final type = (baseAsset['type'] as String? ?? '').toLowerCase();
      final scannedCode =
          (baseAsset['qrCode'] as String? ?? '').trim().isNotEmpty
              ? (baseAsset['qrCode'] as String? ?? '').trim()
              : normalizedCode.trim();
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
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        final r = Responsive.of(context);

        // Build accessible pages based on user role
        final allPages = <int, Widget>{
          0: const DashboardTab(),
          1: const MonitorsTab(),
          2: const UnitsTab(),
          3: const ActivityLogsTab(),
          4: const UsersScreen(embedded: true),
        };

        final accessiblePageIndices = <int>[];
        if (RBACManager.canAccessDashboard(user)) accessiblePageIndices.add(0);
        if (RBACManager.canAccessMonitors(user)) accessiblePageIndices.add(1);
        if (RBACManager.canAccessUnits(user)) accessiblePageIndices.add(2);
        if (RBACManager.canAccessActivityLogs(user)) {
          accessiblePageIndices.add(3);
        }
        if (RBACManager.canAccessUsers(user)) {
          accessiblePageIndices.add(4);
        }

        final pages = accessiblePageIndices
            .map((index) => allPages[index])
            .whereType<Widget>()
            .toList();

        final navItems = <BottomNavigationBarItem>[];
        for (final pageIndex in accessiblePageIndices) {
          switch (pageIndex) {
            case 0:
              navItems.add(const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Home',
              ));
              break;
            case 1:
              navItems.add(const BottomNavigationBarItem(
                icon: Icon(Icons.devices),
                label: 'Monitors',
              ));
              break;
            case 2:
              navItems.add(const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2),
                label: 'Units',
              ));
              break;
            case 3:
              navItems.add(const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Logs',
              ));
              break;
            case 4:
              navItems.add(const BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Users',
              ));
              break;
          }
        }

        var navIndex = _selectedIndex;
        if (navIndex < 0 || navIndex >= pages.length) navIndex = 0;
        final selectedIndex = navIndex;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: AppTheme.sidebarBg,
            elevation: 0,
            titleSpacing: r.dp(12),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'InfoTrack',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: r.dp(2)),
                if (RBACManager.getRoleIndicator(user?.role) != null)
                  Container(
                    padding: r.insetsSymmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          Color(RBACManager.getRoleIndicatorColor(user?.role))
                              .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Color(
                            RBACManager.getRoleIndicatorColor(user?.role)),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      RBACManager.getRoleIndicator(user?.role) ?? '',
                      style: TextStyle(
                        color: Color(
                            RBACManager.getRoleIndicatorColor(user?.role)),
                        fontSize: r.sp(9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    RBACManager.getRoleLabel(user?.role),
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: r.sp(11),
                    ),
                  ),
              ],
            ),
            centerTitle: false,
            actions: [
              Padding(
                padding: EdgeInsets.only(right: r.dp(12)),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _time,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: r.sp(12),
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: r.dp(4)),
                        Text(
                          _date,
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: r.sp(10),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: r.dp(12)),
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
                        'InfoTrack',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                if (RBACManager.canAccessDashboard(user))
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Home'),
                    selected:
                        _selectedIndex == accessiblePageIndices.indexOf(0),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() =>
                          _selectedIndex = accessiblePageIndices.indexOf(0));
                    },
                  ),
                if (RBACManager.canAccessMonitors(user))
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: const Text('Monitors'),
                    selected:
                        _selectedIndex == accessiblePageIndices.indexOf(1),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() =>
                          _selectedIndex = accessiblePageIndices.indexOf(1));
                    },
                  ),
                if (RBACManager.canAccessUnits(user))
                  ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: const Text('System Units'),
                    selected:
                        _selectedIndex == accessiblePageIndices.indexOf(2),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() =>
                          _selectedIndex = accessiblePageIndices.indexOf(2));
                    },
                  ),
                if (RBACManager.canAccessActivityLogs(user))
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Activity Logs'),
                    selected:
                        _selectedIndex == accessiblePageIndices.indexOf(3),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() =>
                          _selectedIndex = accessiblePageIndices.indexOf(3));
                    },
                  ),
                if (RBACManager.canAccessUsers(user))
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Manage Users'),
                    selected:
                        _selectedIndex == accessiblePageIndices.indexOf(4),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() =>
                          _selectedIndex = accessiblePageIndices.indexOf(4));
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
          body: pages.isNotEmpty
              ? IndexedStack(
                  index: selectedIndex,
                  children: pages,
                )
              : Center(
                  child: Text(
                    'Access Denied',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
          bottomNavigationBar: navItems.length < 2
              ? null
              : BottomNavigationBar(
                  currentIndex: navIndex,
                  onTap: (index) => setState(() => _selectedIndex = index),
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: AppTheme.sidebarBg,
                  selectedItemColor: AppTheme.lavender600,
                  unselectedItemColor: AppTheme.textTertiary,
                  selectedFontSize: r.sp(11),
                  unselectedFontSize: r.sp(11),
                  items: navItems,
                ),
          floatingActionButton: RBACManager.canScanQR(user)
              ? FloatingActionButton(
                  onPressed: _openQrScanner,
                  backgroundColor: AppTheme.lavender600,
                  tooltip: 'Scan QR Code',
                  child: const Icon(Icons.qr_code_scanner),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
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
            final r = Responsive.of(ctx);
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
                final res =
                    await api.updateMe(fullName: fullName, email: email);
                final updatedUser = res['user'] != null
                    ? User.fromJson(res['user'] as Map<String, dynamic>)
                    : null;
                final token = res['token'] as String?;
                if (updatedUser != null) {
                  await auth.applyAccountUpdate(
                      user: updatedUser, token: token);
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
                        padding: r.insetsAll(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.statusError.withOpacity(0.40),
                          ),
                          color: AppTheme.statusError.withOpacity(0.10),
                        ),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: AppTheme.statusError,
                            fontSize: r.sp(12),
                          ),
                        ),
                      ),
                    if (success != null)
                      Padding(
                        padding: EdgeInsets.only(top: r.dp(10)),
                        child: Container(
                          width: double.infinity,
                          padding: r.insetsAll(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.statusSuccess.withOpacity(0.40),
                            ),
                            color: AppTheme.statusSuccess.withOpacity(0.10),
                          ),
                          child: Text(
                            success!,
                            style: TextStyle(
                              color: AppTheme.statusSuccess,
                              fontSize: r.sp(12),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: r.dp(14)),

                    // Information
                    Container(
                      width: double.infinity,
                      padding: r.insetsAll(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderDark),
                        color: AppTheme.overlayBg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Information',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: r.sp(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
                          TextField(
                            controller: fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
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

                    SizedBox(height: r.dp(12)),

                    // Password
                    Container(
                      width: double.infinity,
                      padding: r.insetsAll(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderDark),
                        color: AppTheme.overlayBg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: r.sp(13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
                          TextField(
                            controller: currentPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Current Password',
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
                          TextField(
                            controller: newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New Password',
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm New Password',
                            ),
                          ),
                          SizedBox(height: r.dp(12)),
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
          title: const Text('About InfoTrack'),
          content: const Text(
            'InfoTrack v1.0.0\n\n'
            'An IoT-based inventory management system for tracking and managing assets, monitors, and system units.\n\n'
            '© 2026 InfoTrack. All rights reserved.',
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
    final r = Responsive.of(context);
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
              final bottomRight = box.localToGlobal(
                  box.size.bottomRight(Offset.zero),
                  ancestor: overlay);
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
            height: r.dp(44),
            width: r.dp(44),
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
                    style: TextStyle(
                      color: AppTheme.lavender300,
                      fontWeight: FontWeight.w800,
                      fontSize: r.sp(13),
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
  BuildContext? context,
  bool requiredField = false,
}) {
  final effectiveContext = context;
  final labelWidget = (effectiveContext != null && requiredField)
      ? RichText(
          text: TextSpan(
            style:
                (Theme.of(effectiveContext).inputDecorationTheme.labelStyle) ??
                    Theme.of(effectiveContext).textTheme.bodyMedium,
            children: [
              TextSpan(text: label),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Theme.of(effectiveContext).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        )
      : null;
  return InputDecoration(
    label: labelWidget,
    labelText: labelWidget == null ? label : null,
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
  debugPrint('🔍 [DEBUG] _showPrintQrDialog START - title: $title');
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        debugPrint('🔍 [DEBUG] Building PrintQR Dialog');
        final r = Responsive.of(ctx);
        return AlertDialog(
          backgroundColor: const Color(0xFF211339),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.dp(14))),
          titlePadding: EdgeInsets.zero,
          contentPadding: r.insetsAll(24),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.dp(340)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Print QR: $title',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.sp(18),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.dp(24)),
                  Container(
                    padding: r.insetsAll(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: r.dp(160),
                        height: r.dp(160),
                        child: QrImageView(
                          data: qrCode,
                          size: r.dp(160),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: r.dp(20)),
                  Text(
                    qrCode,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: r.sp(13),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.dp(28)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          debugPrint('🔍 [DEBUG] PrintQR Close button tapped');
                          Navigator.pop(ctx);
                        },
                        child: const Text('Close'),
                      ),
                      SizedBox(width: r.dp(12)),
                      ElevatedButton.icon(
                        icon: Icon(Icons.share, size: r.icon(16)),
                        onPressed: () async {
                          debugPrint('🔍 [DEBUG] PrintQR Share button tapped');
                          await Share.share(
                            'Asset: $title\nQR: $qrCode',
                            subject: 'Print QR',
                          );
                        },
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    debugPrint('🔍 [DEBUG] _showPrintQrDialog END - Dialog closed');
  } catch (e) {
    debugPrint('🔍 [ERROR] _showPrintQrDialog Exception: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
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
    return v != null &&
        v.isNotEmpty &&
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
      final r = Responsive.of(ctx);
      final width = MediaQuery.of(ctx).size.width;
      final compact = width < 760;
      return AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        titlePadding: EdgeInsets.fromLTRB(
          r.dp(20),
          r.dp(18),
          r.dp(14),
          r.dp(10),
        ),
        contentPadding: EdgeInsets.fromLTRB(r.dp(20), 0, r.dp(20), r.dp(12)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Activity History'),
            SizedBox(height: r.dp(6)),
            Text(
              '$title${assetQrCode.isEmpty ? '' : ' ($assetQrCode)'}',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: r.sp(14),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: r.dp(10)),
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
                      separatorBuilder: (_, __) => SizedBox(height: r.dp(10)),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Container(
                          padding: r.insetsAll(12),
                          decoration: _balancedInsetDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat('M/d/yyyy, h:mm:ss a').format(log.timestamp)} • ${log.displayAction}',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.sp(12),
                                ),
                              ),
                              SizedBox(height: r.dp(6)),
                              Text(
                                'User: ${log.updaterDisplayName}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: r.sp(12),
                                ),
                              ),
                              SizedBox(height: r.dp(6)),
                              Text(
                                log.displayDetails,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: r.sp(12),
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
                        dataRowMinHeight: r.dp(44),
                        dataRowMaxHeight: r.dp(58),
                        horizontalMargin: r.dp(14),
                        columnSpacing: r.dp(18),
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
                                  width: r.dp(160),
                                  child: Text(
                                    DateFormat('M/d/yyyy, h:mm:ss a')
                                        .format(log.timestamp),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: r.insetsSymmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.lavender700.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(log.action.toLowerCase()),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: r.dp(140),
                                  child: Text(log.updaterDisplayName),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: r.dp(360),
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
  final rootContext = context;
  final currentUser = rootContext.read<AuthProvider>().currentUser;
  final assetState = Map<String, dynamic>.from(asset);

  String assetValue(dynamic value) {
    if (value == null) return '—';
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  bool isUnitAsset(Map<String, dynamic> a) {
    return (a['type']?.toString().toLowerCase() ?? '') == 'unit';
  }

  bool canEditAsset(Map<String, dynamic> a) {
    return isUnitAsset(a)
        ? RBACManager.canEditUnit(currentUser)
        : RBACManager.canEditMonitor(currentUser);
  }

  String assetId(Map<String, dynamic> a) {
    return (a['id']?.toString().trim() ?? '');
  }

  Future<void> editAssetFromDetails(
    BuildContext dialogContext,
    void Function(VoidCallback fn) setDialogState,
  ) async {
    if (!canEditAsset(assetState)) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('You do not have permission to edit')),
      );
      return;
    }

    final id = assetId(assetState);
    if (id.isEmpty) {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Cannot edit: missing asset id')),
      );
      return;
    }

    final isUnit = isUnitAsset(assetState);
    final deviceNameController = TextEditingController(
      text: assetValue(assetState['deviceName']) == '—'
          ? ''
          : assetState['deviceName'].toString(),
    );
    final qrCodeController = TextEditingController(
      text: assetValue(assetState['qrCode']) == '—'
          ? ''
          : assetState['qrCode'].toString(),
    );
    final modelTypeController = TextEditingController(
      text: assetValue(assetState['modelType']) == '—'
          ? ''
          : (assetState['modelType']?.toString() ?? ''),
    );
    final serialNumberController = TextEditingController(
      text: assetValue(assetState['serialNumber']) == '—'
          ? ''
          : (assetState['serialNumber']?.toString() ?? ''),
    );
    final locationController = TextEditingController(
      text: assetValue(assetState['location']) == '—'
          ? ''
          : (assetState['location']?.toString() ?? ''),
    );
    final descriptionController = TextEditingController(
      text: assetValue(assetState['description']) == '—'
          ? ''
          : (assetState['description']?.toString() ?? ''),
    );
    final notesController = TextEditingController(
      text: assetValue(assetState['notes']) == '—'
          ? ''
          : (assetState['notes']?.toString() ?? ''),
    );

    final linkedKeyPrimary = isUnit ? 'linkedMonitorId' : 'linkedUnitId';
    final linkedKeyFallback = isUnit ? 'linkedMonitor' : 'linkedUnit';
    final linkedController = TextEditingController(
      text:
          (assetState[linkedKeyPrimary]?.toString().trim().isNotEmpty ?? false)
              ? assetState[linkedKeyPrimary].toString()
              : (assetState[linkedKeyFallback]?.toString() ?? ''),
    );

    String selectedStatus =
        (assetState['status']?.toString().trim().isNotEmpty ?? false)
            ? assetState['status'].toString()
            : 'active';

    String selectedCondition =
        (assetState['condition']?.toString().trim().isNotEmpty ?? false)
            ? assetState['condition'].toString()
            : 'good';

    Uint8List? selectedImageBytes;
    String? selectedImageBase64;
    String? selectedImageName;

    try {
      final saved = await showDialog<bool>(
        context: dialogContext,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setEditState) {
              Future<void> pickImage() async {
                try {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked == null) return;

                  final bytes = await picked.readAsBytes();
                  if (bytes.isEmpty) return;

                  setEditState(() {
                    selectedImageBytes = bytes;
                    selectedImageBase64 = base64Encode(bytes);
                    selectedImageName = picked.name;
                  });
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to pick image: $e')),
                  );
                }
              }

              Widget imagePickerSection() {
                Widget preview() {
                  if (selectedImageBytes != null) {
                    return Image.memory(
                      selectedImageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Preview unavailable',
                          style: TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                    );
                  }

                  final raw = assetState['imageData'];
                  final s = (raw == null) ? '' : raw.toString().trim();
                  if (s.isEmpty || s == '—') {
                    return const Center(
                      child: Text(
                        'No image',
                        style: TextStyle(color: AppTheme.textTertiary),
                      ),
                    );
                  }

                  final lower = s.toLowerCase();
                  final isUrl = lower.startsWith('http://') ||
                      lower.startsWith('https://');
                  if (isUrl) {
                    return Image.network(
                      s,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'No image',
                          style: TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                    );
                  }

                  var payload = s;
                  if (payload.startsWith('data:')) {
                    final comma = payload.indexOf(',');
                    if (comma >= 0 && comma < payload.length - 1) {
                      payload = payload.substring(comma + 1);
                    }
                  }
                  try {
                    final bytes = base64Decode(payload);
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'No image',
                          style: TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                    );
                  } catch (_) {
                    return const Center(
                      child: Text(
                        'No image',
                        style: TextStyle(color: AppTheme.textTertiary),
                      ),
                    );
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose File'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (selectedImageName == null ||
                                    selectedImageName!.trim().isEmpty)
                                ? 'No file selected'
                                : selectedImageName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: preview(),
                      ),
                    ),
                  ],
                );
              }

              return AlertDialog(
                backgroundColor: AppTheme.primaryBg,
                title: Text(isUnit ? 'Edit Unit' : 'Edit Monitor'),
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Builder(
                      builder: (context) {
                        final twoCol = MediaQuery.sizeOf(context).width >= 520;

                        final nameField = TextField(
                          controller: deviceNameController,
                          decoration:
                              _compactInputDecoration(label: 'Device Name'),
                        );
                        final qrField = TextField(
                          controller: qrCodeController,
                          readOnly: true,
                          decoration: _compactInputDecoration(label: 'QR Code'),
                        );
                        final statusField = DropdownButtonFormField<String>(
                          value: selectedStatus,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                            DropdownMenuItem(
                                value: 'broken', child: Text('Broken')),
                            DropdownMenuItem(
                                value: 'repair', child: Text('Repair')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setEditState(() => selectedStatus = value);
                            }
                          },
                          decoration: _compactInputDecoration(label: 'Status'),
                        );
                        final conditionField = DropdownButtonFormField<String>(
                          value: selectedCondition,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'new', child: Text('New')),
                            DropdownMenuItem(
                                value: 'good', child: Text('Good')),
                            DropdownMenuItem(
                                value: 'fair', child: Text('Fair')),
                            DropdownMenuItem(
                                value: 'poor', child: Text('Poor')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setEditState(() => selectedCondition = value);
                            }
                          },
                          decoration:
                              _compactInputDecoration(label: 'Condition'),
                        );
                        final modelTypeField = TextField(
                          controller: modelTypeController,
                          decoration: _compactInputDecoration(
                            label: 'Model Type',
                            hint: 'Optional',
                          ),
                        );
                        final serialNumberField = TextField(
                          controller: serialNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          maxLength: 5,
                          decoration: _compactInputDecoration(
                            label: 'Serial Number',
                            hint: 'Optional',
                          ).copyWith(counterText: ''),
                        );
                        final linkedField = TextField(
                          controller: linkedController,
                          decoration: _compactInputDecoration(
                            label:
                                isUnit ? 'Linked Monitor ID' : 'Linked Unit ID',
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
                        final notesField = TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: _compactInputDecoration(
                            label: 'Notes',
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
                              conditionField,
                              vGap(),
                              modelTypeField,
                              vGap(),
                              serialNumberField,
                              vGap(),
                              linkedField,
                              vGap(),
                              locationField,
                              vGap(),
                              descriptionField,
                              vGap(),
                              notesField,
                              vGap(),
                              imagePickerSection(),
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
                                Expanded(child: conditionField),
                              ],
                            ),
                            vGap(),
                            Row(
                              children: [
                                Expanded(child: modelTypeField),
                                const SizedBox(width: 12),
                                Expanded(child: serialNumberField),
                              ],
                            ),
                            vGap(),
                            Row(
                              children: [
                                Expanded(child: linkedField),
                                const SizedBox(width: 12),
                                Expanded(child: locationField),
                              ],
                            ),
                            vGap(),
                            descriptionField,
                            vGap(),
                            notesField,
                            vGap(),
                            imagePickerSection(),
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

      if (deviceNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(content: Text('Device Name is required')),
        );
        return;
      }

      final serial = serialNumberController.text.trim();
      if (serial.isNotEmpty && !_isValidSerialNumber(serial)) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(
              content: Text('Serial Number must be exactly 5 digits')),
        );
        return;
      }

      final payload = <String, dynamic>{
        'deviceName': deviceNameController.text.trim(),
        'status': selectedStatus,
        'condition': selectedCondition,
        'modelType': modelTypeController.text.trim(),
        'serialNumber': serialNumberController.text.trim(),
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
        'notes': notesController.text.trim(),
      };

      if (selectedImageBase64 != null) {
        payload['imageData'] = selectedImageBase64;
      }

      final linked = linkedController.text.trim();
      if (linked.isNotEmpty) {
        payload[isUnit ? 'linkedMonitorId' : 'linkedUnitId'] = linked;
      }

      if (isUnit) {
        await ApiClient().updateUnit(id, payload);
        if (rootContext.mounted) {
          await rootContext.read<UnitProvider>().fetchUnits();
        }
      } else {
        await ApiClient().updateMonitor(id, payload);
        if (rootContext.mounted) {
          await rootContext.read<MonitorProvider>().fetchMonitors();
        }
      }

      if (rootContext.mounted) {
        await rootContext
            .read<ActivityLogProvider>()
            .fetchActivityLogs(limit: 200);
      }

      if (!rootContext.mounted) return;

      setDialogState(() {
        assetState.addAll(payload);
      });

      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
            content: Text(isUnit
                ? 'Unit updated successfully'
                : 'Monitor updated successfully')),
      );
    } catch (e) {
      if (!rootContext.mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text('Failed to update: ${e.toString()}')),
      );
    } finally {
      deviceNameController.dispose();
      qrCodeController.dispose();
      modelTypeController.dispose();
      serialNumberController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      notesController.dispose();
      linkedController.dispose();
    }
  }

  final r = Responsive.of(context);

  Widget detailBox(String label, dynamic value) {
    return Container(
      padding: r.insetsAll(10),
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
            style: TextStyle(
              fontSize: r.sp(10),
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: r.dp(4)),
          Text(
            assetValue(value),
            style: TextStyle(
              fontSize: r.sp(13),
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
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canEdit = canEditAsset(assetState);
          final canPrint = RBACManager.canPrintQR(currentUser);
          final title = assetValue(assetState['deviceName']);
          final qrCode = assetValue(assetState['qrCode']);

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: compact ? r.dp(10) : r.dp(24),
              vertical: compact ? r.dp(10) : r.dp(24),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact ? media.size.width - r.dp(20) : r.dp(860),
                maxHeight: media.size.height * 0.92,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF211339),
                  borderRadius: BorderRadius.circular(r.dp(18)),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        r.dp(18),
                        r.dp(16),
                        r.dp(12),
                        r.dp(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                SizedBox(height: r.dp(4)),
                                Text(
                                  'QR: $qrCode',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: r.sp(13),
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        r.dp(16),
                        r.dp(12),
                        r.dp(16),
                        r.dp(12),
                      ),
                      child: Wrap(
                        spacing: r.dp(10),
                        runSpacing: r.dp(10),
                        alignment: WrapAlignment.start,
                        children: [
                          if (canEdit)
                            ElevatedButton.icon(
                              icon: Icon(Icons.edit, size: r.icon(18)),
                              onPressed: () => editAssetFromDetails(
                                ctx,
                                setDialogState,
                              ),
                              label: const Text('Edit'),
                            ),
                          if (canPrint)
                            OutlinedButton.icon(
                              icon: Icon(Icons.qr_code_2, size: r.icon(18)),
                              onPressed: () async {
                                if (!RBACManager.canPrintQR(currentUser)) {
                                  ScaffoldMessenger.of(rootContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You do not have permission to print QR codes',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                await _showPrintQrDialog(
                                  rootContext,
                                  title: title == '—' ? 'Asset' : title,
                                  qrCode: qrCode == '—' ? '' : qrCode,
                                );
                              },
                              label: const Text('Print QR'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderDark),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: r.insetsAll(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final narrow = constraints.maxWidth < 700;
                                final imageSection = Container(
                                  height: narrow ? r.dp(220) : r.dp(260),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBg,
                                    borderRadius:
                                        BorderRadius.circular(r.dp(14)),
                                    border:
                                        Border.all(color: AppTheme.borderDark),
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(r.dp(14)),
                                    child: Builder(
                                      builder: (context) {
                                        final raw = assetState['imageData'];
                                        final s = (raw == null)
                                            ? ''
                                            : raw.toString().trim();

                                        bool isUrl(String v) {
                                          final lower = v.toLowerCase();
                                          return lower.startsWith('http://') ||
                                              lower.startsWith('https://');
                                        }

                                        Uint8List? tryDecodeBase64(String v) {
                                          var payload = v.trim();
                                          if (payload.isEmpty) return null;
                                          if (payload.startsWith('data:')) {
                                            final comma = payload.indexOf(',');
                                            if (comma >= 0 &&
                                                comma < payload.length - 1) {
                                              payload =
                                                  payload.substring(comma + 1);
                                            }
                                          }
                                          try {
                                            return base64Decode(payload);
                                          } catch (_) {
                                            return null;
                                          }
                                        }

                                        if (s.isEmpty || s == '—') {
                                          return const Center(
                                            child: Text(
                                              'No image',
                                              style: TextStyle(
                                                color: AppTheme.textTertiary,
                                              ),
                                            ),
                                          );
                                        }

                                        if (isUrl(s)) {
                                          return Image.network(
                                            s,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Center(
                                              child: Text(
                                                'No image',
                                                style: TextStyle(
                                                  color: AppTheme.textTertiary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        final bytes = tryDecodeBase64(s);
                                        if (bytes == null || bytes.isEmpty) {
                                          return const Center(
                                            child: Text(
                                              'No image',
                                              style: TextStyle(
                                                color: AppTheme.textTertiary,
                                              ),
                                            ),
                                          );
                                        }

                                        return Image.memory(
                                          bytes,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Text(
                                              'No image',
                                              style: TextStyle(
                                                color: AppTheme.textTertiary,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );

                                final qrSection = Container(
                                  padding: r.insetsAll(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBg,
                                    borderRadius:
                                        BorderRadius.circular(r.dp(14)),
                                    border:
                                        Border.all(color: AppTheme.borderDark),
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: r.dp(160),
                                      maxWidth: r.dp(220),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: r.insetsAll(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: RepaintBoundary(
                                            child: SizedBox(
                                              width: r.dp(140),
                                              height: r.dp(140),
                                              child: QrImageView(
                                                data: assetValue(assetState[
                                                            'qrCode']) ==
                                                        '—'
                                                    ? 'N/A'
                                                    : assetState['qrCode']
                                                        .toString(),
                                                size: r.dp(140),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: r.dp(12)),
                                        Flexible(
                                          child: Text(
                                            assetValue(assetState['qrCode']),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: r.sp(12),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                if (assetValue(assetState['status']) != '—')
                                  _StatusBadge(
                                      status: assetValue(assetState['status'])),
                                if (assetValue(assetState['condition']) != '—')
                                  _StatusBadge(
                                      status:
                                          assetValue(assetState['condition'])),
                              ],
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount =
                                    constraints.maxWidth < 700 ? 1 : 2;
                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio:
                                      crossAxisCount == 1 ? 3.0 : 2.2,
                                  children: [
                                    detailBox('Device Name',
                                        assetState['deviceName']),
                                    detailBox('QR Code', assetState['qrCode']),
                                    detailBox('Type', assetState['type']),
                                    detailBox('Status', assetState['status']),
                                    detailBox(
                                        'Condition', assetState['condition']),
                                    detailBox(
                                        'Location', assetState['location']),
                                    detailBox(
                                        'Model Type', assetState['modelType']),
                                    detailBox('Serial Number',
                                        assetState['serialNumber']),
                                    detailBox(
                                        'Created By', assetState['createdBy']),
                                    detailBox(
                                        'Created At', assetState['createdAt']),
                                    detailBox(
                                        'Updated At', assetState['updatedAt']),
                                    detailBox(
                                      assetState['type'] == 'unit'
                                          ? 'Linked Monitor'
                                          : 'Linked Unit',
                                      _linkedAssetLabel(assetState),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            detailBox('Description', assetState['description']),
                            const SizedBox(height: 10),
                            detailBox('Notes', assetState['notes']),
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
    },
  );
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        final role = (user?.role ?? '').toLowerCase();
        final isStaffOrViewer =
            role == RBACManager.ROLE_STAFF || role == RBACManager.ROLE_VIEWER;
        final isTechnician = role == RBACManager.ROLE_TECHNICIAN;
        final isManager = role == RBACManager.ROLE_MANAGER;

        final showStats = RBACManager.hasFullDashboardAccess(user);
        final showLogsSection = !isStaffOrViewer;
        final filterLogsToCurrentUser = isTechnician || isManager;

        bool isMyLog(ActivityLog log) {
          final userId = user?.id.trim() ?? '';
          final email = user?.email.trim().toLowerCase() ?? '';
          final logUserId = log.userId?.trim() ?? '';
          final logEmail = log.userEmail?.trim().toLowerCase() ?? '';

          if (userId.isNotEmpty &&
              logUserId.isNotEmpty &&
              userId == logUserId) {
            return true;
          }
          if (email.isNotEmpty && logEmail.isNotEmpty && email == logEmail) {
            return true;
          }
          return false;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showStats) ...[
                // Stats Row (Admin/Manager only)
                Consumer2<MonitorProvider, UnitProvider>(
                  builder: (context, monitorProvider, unitProvider, _) {
                    final totalAssets = monitorProvider.monitors.length +
                        unitProvider.units.length;
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
              ],

              // Charts (all roles)
              Consumer3<ActivityLogProvider, MonitorProvider, UnitProvider>(
                builder:
                    (context, logsProvider, monitorProvider, unitProvider, _) {
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

              if (showLogsSection) ...[
                const SizedBox(height: 22),
                Text(
                  filterLogsToCurrentUser ? 'My Activity' : 'Recent Activity',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 12),
                Consumer<ActivityLogProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    var logs = provider.logs;
                    if (filterLogsToCurrentUser) {
                      logs = logs.where(isMyLog).toList();
                    }
                    logs = [...logs]
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                    final recentLogs = logs.take(5).toList();
                    if (recentLogs.isEmpty) {
                      return Center(
                        child: Text(
                          'No activity logs',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }

                    return Container(
                      decoration: _balancedSurfaceDecoration(elevated: true),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final r = Responsive.of(context);
                          if (constraints.maxWidth < 720) {
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: r.insetsAll(14),
                              itemCount: recentLogs.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: r.dp(10)),
                              itemBuilder: (context, index) {
                                final log = recentLogs[index];
                                return _ActivityLogCard(
                                  log: log,
                                  maxDetailLines: 6,
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
                              dataRowMinHeight: r.dp(42),
                              dataRowMaxHeight: r.dp(54),
                              columnSpacing: r.dp(18),
                              horizontalMargin: r.dp(14),
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
                                        style: TextStyle(fontSize: r.sp(11)),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        log.displayAction,
                                        style: TextStyle(fontSize: r.sp(11)),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        log.assetQrCode,
                                        style: TextStyle(fontSize: r.sp(11)),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: r.dp(200),
                                        child: Text(
                                          log.displayDetails,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: r.sp(11)),
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
            ],
          ),
        );
      },
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
    final r = Responsive.of(context);

    return Container(
      padding: r.insetsAll(14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppTheme.darkBg.withOpacity(0.88) : null,
        border: Border.all(color: AppTheme.borderDark),
        borderRadius: BorderRadius.circular(r.dp(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: r.sp(10),
                      ),
                ),
              ),
              Container(
                width: r.dp(30),
                height: r.dp(30),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(r.dp(10)),
                ),
                child: Icon(
                  icon,
                  size: r.icon(16),
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: r.dp(8)),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: r.sp(18),
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
    final deviceNameController =
        TextEditingController(text: monitor.deviceName);
    final qrCodeController = TextEditingController(text: monitor.qrCode);
    final modelTypeController =
        TextEditingController(text: monitor.modelType ?? '');
    final serialNumberController =
        TextEditingController(text: monitor.serialNumber ?? '');
    final linkedUnitIdController =
        TextEditingController(text: monitor.linkedUnit ?? '');
    final locationController =
        TextEditingController(text: monitor.location ?? '');
    final descriptionController =
        TextEditingController(text: monitor.description ?? '');
    final notesController = TextEditingController(text: monitor.notes ?? '');
    String selectedStatus = monitor.status;
    String selectedCondition = (monitor.condition?.trim().isNotEmpty ?? false)
        ? monitor.condition!.trim().toLowerCase()
        : 'good';

    Uint8List? selectedImageBytes;
    String? selectedImageBase64;
    String? selectedImageName;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> pickImage() async {
              try {
                final picked =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked == null) return;

                final bytes = await picked.readAsBytes();
                if (bytes.isEmpty) return;

                setDialogState(() {
                  selectedImageBytes = bytes;
                  selectedImageBase64 = base64Encode(bytes);
                  selectedImageName = picked.name;
                });
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to pick image: $e')),
                );
              }
            }

            Widget imagePickerSection() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: pickImage,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose File'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (selectedImageName == null ||
                                  selectedImageName!.trim().isEmpty)
                              ? 'No file selected'
                              : selectedImageName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.darkBg.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: selectedImageBytes == null
                          ? const Center(
                              child: Text(
                                'No new image selected',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            )
                          : Image.memory(
                              selectedImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text(
                                  'Preview unavailable',
                                  style:
                                      TextStyle(color: AppTheme.textTertiary),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: AppTheme.primaryBg,
              title: const Text('Edit Monitor'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Builder(
                    builder: (context) {
                      final twoCol = MediaQuery.sizeOf(context).width >= 520;

                      final nameField = TextField(
                        controller: deviceNameController,
                        decoration:
                            _compactInputDecoration(label: 'Device Name'),
                      );
                      final qrField = TextField(
                        controller: qrCodeController,
                        readOnly: true,
                        decoration: _compactInputDecoration(label: 'QR Code'),
                      );
                      final statusField = DropdownButtonFormField<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'inactive', child: Text('Inactive')),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(
                              value: 'broken', child: Text('Broken')),
                          DropdownMenuItem(
                              value: 'repair', child: Text('Repair')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedStatus = value);
                          }
                        },
                        decoration: _compactInputDecoration(label: 'Status'),
                      );
                      final conditionField = DropdownButtonFormField<String>(
                        value: selectedCondition,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('New')),
                          DropdownMenuItem(value: 'good', child: Text('Good')),
                          DropdownMenuItem(value: 'fair', child: Text('Fair')),
                          DropdownMenuItem(value: 'poor', child: Text('Poor')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedCondition = value);
                          }
                        },
                        decoration: _compactInputDecoration(label: 'Condition'),
                      );
                      final modelTypeField = TextField(
                        controller: modelTypeController,
                        decoration: _compactInputDecoration(
                          label: 'Model Type',
                          hint: 'Optional',
                        ),
                      );
                      final serialNumberField = TextField(
                        controller: serialNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        maxLength: 5,
                        decoration: _compactInputDecoration(
                          label: 'Serial Number',
                          hint: 'Optional',
                        ).copyWith(counterText: ''),
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
                      final notesField = TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: _compactInputDecoration(
                          label: 'Notes',
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
                            conditionField,
                            vGap(),
                            modelTypeField,
                            vGap(),
                            serialNumberField,
                            vGap(),
                            linkedField,
                            vGap(),
                            locationField,
                            vGap(),
                            descriptionField,
                            vGap(),
                            notesField,
                            vGap(),
                            imagePickerSection(),
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
                              Expanded(child: conditionField),
                            ],
                          ),
                          vGap(),
                          Row(
                            children: [
                              Expanded(child: modelTypeField),
                              const SizedBox(width: 12),
                              Expanded(child: serialNumberField),
                            ],
                          ),
                          vGap(),
                          Row(
                            children: [
                              Expanded(child: linkedField),
                              const SizedBox(width: 12),
                              Expanded(child: locationField),
                            ],
                          ),
                          vGap(),
                          descriptionField,
                          vGap(),
                          notesField,
                          vGap(),
                          imagePickerSection(),
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

    if (deviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device Name is required')),
      );
      return;
    }

    final serial = serialNumberController.text.trim();
    if (serial.isNotEmpty && !_isValidSerialNumber(serial)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serial Number must be exactly 5 digits')),
      );
      return;
    }

    try {
      debugPrint('🔍 [DEBUG] Building update payload for monitor');
      final payload = <String, dynamic>{
        'deviceName': deviceNameController.text.trim(),
        'status': selectedStatus,
        'condition': selectedCondition,
        'modelType': modelTypeController.text.trim(),
        'serialNumber': serialNumberController.text.trim(),
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
        'notes': notesController.text.trim(),
      };

      if (selectedImageBase64 != null) {
        payload['imageData'] = selectedImageBase64;
      }

      final linked = linkedUnitIdController.text.trim();
      payload['linkedUnitId'] = linked.isEmpty ? null : linked;

      debugPrint('🔍 [DEBUG] Sending update request: $payload');
      await ApiClient().updateMonitor(monitor.id, payload);
      if (!context.mounted) {
        debugPrint('🔍 [DEBUG] Context not mounted after update');
        return;
      }

      debugPrint('🔍 [DEBUG] Fetching monitors after update');
      await context.read<MonitorProvider>().fetchMonitors();
      await context.read<ActivityLogProvider>().fetchActivityLogs(limit: 200);
      if (!context.mounted) {
        debugPrint('🔍 [DEBUG] Context not mounted after fetch');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monitor updated successfully')),
      );
      debugPrint('🔍 [DEBUG] Monitor update completed successfully');
    } catch (e) {
      debugPrint('🔍 [ERROR] Monitor update failed: $e');
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
        content:
            Text('Delete ${monitor.deviceName}? This action cannot be undone.'),
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

    // Get current user from AuthProvider
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (action == 'edit') {
      if (!RBACManager.canEditMonitor(currentUser)) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to edit monitors'),
            ),
          );
        }
        return;
      }
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
      if (!RBACManager.canPrintQR(currentUser)) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to print QR codes'),
            ),
          );
        }
        return;
      }
      await _showPrintQrDialog(
        rootContext,
        title: monitor.deviceName,
        qrCode: monitor.qrCode,
      );
      return;
    }

    if (action == 'delete') {
      if (!RBACManager.canDeleteMonitor(currentUser)) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to delete monitors'),
            ),
          );
        }
        return;
      }
      await _deleteMonitor(rootContext, monitor);
    }
  }

  Future<void> _showAddMonitorDialog(BuildContext context) async {
    final deviceNameController = TextEditingController();
    final qrCodeController = TextEditingController();
    final modelTypeController = TextEditingController();
    final serialNumberController = TextEditingController();
    final linkedUnitIdController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final notesController = TextEditingController();
    String selectedStatus = 'active';
    String selectedCondition = 'good';

    Uint8List? selectedImageBytes;
    String? selectedImageBase64;
    String? selectedImageName;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final maxDialogHeight = MediaQuery.sizeOf(ctx).height * 0.85;

              Future<void> pickImage() async {
                try {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked == null) return;

                  final bytes = await picked.readAsBytes();
                  if (bytes.isEmpty) return;

                  setDialogState(() {
                    selectedImageBytes = bytes;
                    selectedImageBase64 = base64Encode(bytes);
                    selectedImageName = picked.name;
                  });
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to pick image: $e')),
                  );
                }
              }

              Widget imagePickerSection() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose File'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (selectedImageName == null ||
                                    selectedImageName!.trim().isEmpty)
                                ? 'No file selected'
                                : selectedImageName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: selectedImageBytes == null
                            ? const Center(
                                child: Text(
                                  'No image selected',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              )
                            : Image.memory(
                                selectedImageBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                    'Preview unavailable',
                                    style:
                                        TextStyle(color: AppTheme.textTertiary),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }

              final serial = serialNumberController.text.trim();
              final serialOk = serial.isEmpty || _isValidSerialNumber(serial);
              final canSubmit = deviceNameController.text.trim().isNotEmpty &&
                  qrCodeController.text.trim().isNotEmpty &&
                  serialOk;

              return Dialog(
                backgroundColor: AppTheme.primaryBg,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: maxDialogHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add New Monitor',
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter the details for the new monitor',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth =
                                    constraints.maxWidth.isFinite &&
                                            constraints.maxWidth > 0
                                        ? constraints.maxWidth
                                        : 560.0;
                                final twoCol = availableWidth >= 460;

                                final nameField = TextField(
                                  controller: deviceNameController,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: _compactInputDecoration(
                                    label: 'Device Name',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final qrField = TextField(
                                  controller: qrCodeController,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: _compactInputDecoration(
                                    label: 'QR Code',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final statusField =
                                    DropdownButtonFormField<String>(
                                  value: selectedStatus,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'active',
                                      child: Text('Active'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactive',
                                      child: Text('Inactive'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'maintenance',
                                      child: Text('Maintenance'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'broken',
                                      child: Text('Broken'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'repair',
                                      child: Text('Repair'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(
                                          () => selectedStatus = value);
                                    }
                                  },
                                  decoration: _compactInputDecoration(
                                    label: 'Status',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final conditionField =
                                    DropdownButtonFormField<String>(
                                  value: selectedCondition,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'new', child: Text('New')),
                                    DropdownMenuItem(
                                        value: 'good', child: Text('Good')),
                                    DropdownMenuItem(
                                        value: 'fair', child: Text('Fair')),
                                    DropdownMenuItem(
                                        value: 'poor', child: Text('Poor')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(
                                          () => selectedCondition = value);
                                    }
                                  },
                                  decoration: _compactInputDecoration(
                                    label: 'Condition',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final modelTypeField = TextField(
                                  controller: modelTypeController,
                                  decoration: _compactInputDecoration(
                                    label: 'Model Type',
                                    hint: 'Optional',
                                  ),
                                );
                                final serialNumberField = TextField(
                                  controller: serialNumberController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  maxLength: 5,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: _compactInputDecoration(
                                    label: 'Serial Number',
                                    hint: 'Optional',
                                  ).copyWith(counterText: ''),
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
                                final notesField = TextField(
                                  controller: notesController,
                                  maxLines: 2,
                                  decoration: _compactInputDecoration(
                                    label: 'Notes',
                                    hint: 'Optional',
                                  ),
                                );

                                Widget vGap([double h = 10]) => SizedBox(
                                      height: h,
                                    );

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
                                      conditionField,
                                      vGap(),
                                      modelTypeField,
                                      vGap(),
                                      serialNumberField,
                                      vGap(),
                                      linkedField,
                                      vGap(),
                                      locationField,
                                      vGap(),
                                      notesField,
                                      vGap(),
                                      descriptionField,
                                      vGap(),
                                      imagePickerSection(),
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
                                        Expanded(child: conditionField),
                                      ],
                                    ),
                                    vGap(),
                                    Row(
                                      children: [
                                        Expanded(child: modelTypeField),
                                        const SizedBox(width: 12),
                                        Expanded(child: serialNumberField),
                                      ],
                                    ),
                                    vGap(),
                                    Row(
                                      children: [
                                        Expanded(child: linkedField),
                                        const SizedBox(width: 12),
                                        Expanded(child: locationField),
                                      ],
                                    ),
                                    vGap(),
                                    notesField,
                                    vGap(),
                                    descriptionField,
                                    vGap(),
                                    imagePickerSection(),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: canSubmit
                                  ? () => Navigator.pop(ctx, true)
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Monitor'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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

      final serial = serialNumberController.text.trim();
      if (serial.isNotEmpty && !_isValidSerialNumber(serial)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Serial Number must be exactly 5 digits')),
        );
        return;
      }

      final provider = context.read<MonitorProvider>();
      final ok = await provider.createMonitor(
        deviceNameController.text.trim(),
        qrCodeController.text.trim(),
        selectedStatus,
        condition: selectedCondition,
        modelType: modelTypeController.text.trim(),
        serialNumber: serialNumberController.text.trim(),
        linkedUnitId: linkedUnitIdController.text.trim(),
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        notes: notesController.text.trim(),
        imageData: selectedImageBase64,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Monitor added successfully'
              : (provider.error ?? 'Failed to add monitor')),
        ),
      );
    } finally {
      deviceNameController.dispose();
      qrCodeController.dispose();
      modelTypeController.dispose();
      serialNumberController.dispose();
      linkedUnitIdController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, _) {
        final r = Responsive.of(context);
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
              padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(12), r.dp(16), 0),
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
                      SizedBox(width: r.dp(8)),
                      OutlinedButton.icon(
                        onPressed: () => _exportMonitorsCsv(context, filtered),
                        icon: Icon(Icons.download, size: r.icon(14)),
                        label: Text('Export CSV',
                            style: TextStyle(fontSize: r.sp(11))),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, r.dp(32)),
                          padding:
                              r.insetsSymmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      SizedBox(width: r.dp(8)),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final canAddMonitor =
                              RBACManager.canAddMonitor(auth.currentUser);
                          return ElevatedButton.icon(
                            onPressed: canAddMonitor
                                ? () => _showAddMonitorDialog(context)
                                : null,
                            icon: Icon(Icons.add, size: r.icon(13)),
                            label: Text('Add Monitor',
                                style: TextStyle(fontSize: r.sp(11))),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, r.dp(32)),
                              padding: r.insetsSymmetric(
                                  horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(10), r.dp(16), 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCol = constraints.maxWidth >= 700;
                  final fieldWidth = twoCol
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: r.dp(12),
                    runSpacing: r.dp(10),
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
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                            DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance')),
                            DropdownMenuItem(
                                value: 'broken', child: Text('Broken')),
                            DropdownMenuItem(
                                value: 'repair', child: Text('Repair')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _statusFilter = value);
                            }
                          },
                          decoration: _compactInputDecoration(
                            label: 'Filter by status',
                            prefixIcon: const Icon(Icons.filter_alt_outlined),
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
                                                      style: TextStyle(
                                                        color: AppTheme
                                                            .textTertiary,
                                                        fontSize: r.sp(11),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _StatusBadge(
                                                  status: monitor.status),
                                              Consumer<AuthProvider>(
                                                builder: (context, auth, _) {
                                                  return PopupMenuButton<
                                                      String>(
                                                    tooltip: 'Actions',
                                                    onOpened: () {
                                                      if (!mounted) return;
                                                      setState(() =>
                                                          _suppressCardTap =
                                                              true);
                                                    },
                                                    onCanceled: () {
                                                      if (!mounted) return;
                                                      setState(() =>
                                                          _suppressCardTap =
                                                              false);
                                                    },
                                                    onSelected: (value) {
                                                      if (mounted) {
                                                        setState(() =>
                                                            _suppressCardTap =
                                                                false);
                                                      }
                                                      _afterMenuClose(
                                                        () =>
                                                            _handleMonitorAction(
                                                          context,
                                                          value,
                                                          monitor,
                                                        ),
                                                      );
                                                    },
                                                    itemBuilder: (context) {
                                                      final items =
                                                          <PopupMenuEntry<
                                                              String>>[
                                                        if (RBACManager
                                                            .canEditMonitor(auth
                                                                .currentUser))
                                                          const PopupMenuItem(
                                                            value: 'edit',
                                                            child: ListTile(
                                                              dense: true,
                                                              leading: Icon(Icons
                                                                  .edit_outlined),
                                                              title:
                                                                  Text('Edit'),
                                                            ),
                                                          ),
                                                        const PopupMenuItem(
                                                          value: 'history',
                                                          child: ListTile(
                                                            dense: true,
                                                            leading: Icon(
                                                                Icons.history),
                                                            title: Text(
                                                                'View History'),
                                                          ),
                                                        ),
                                                        if (RBACManager
                                                            .canPrintQR(auth
                                                                .currentUser))
                                                          const PopupMenuItem(
                                                            value: 'print',
                                                            child: ListTile(
                                                              dense: true,
                                                              leading: Icon(Icons
                                                                  .qr_code_2),
                                                              title: Text(
                                                                  'Print QR'),
                                                            ),
                                                          ),
                                                        if (RBACManager
                                                            .canDeleteMonitor(
                                                                auth.currentUser))
                                                          const PopupMenuItem(
                                                            value: 'delete',
                                                            child: ListTile(
                                                              dense: true,
                                                              leading: Icon(Icons
                                                                  .delete_outline),
                                                              title: Text(
                                                                  'Delete'),
                                                            ),
                                                          ),
                                                      ];
                                                      return items;
                                                    },
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Icon(
                                                          Icons.more_horiz),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _ChipPill(
                                                label:
                                                    'Linked: ${monitor.linkedUnit ?? 'N/A'}',
                                              ),
                                              _ChipPill(
                                                label:
                                                    'Desc: ${monitor.description ?? 'No description'}',
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
                                    DataColumn(label: Text('Device ID')),
                                    DataColumn(label: Text('Device Name')),
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
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Tooltip(
                                              message: monitor.id,
                                              child: Text(
                                                _infocomDeviceIdFromUuid(
                                                    monitor.id),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(monitor.deviceName)),
                                        DataCell(_StatusBadge(
                                            status: monitor.status)),
                                        DataCell(
                                            Text(monitor.linkedUnit ?? 'N/A')),
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
                                          Consumer<AuthProvider>(
                                            builder: (context, auth, _) {
                                              return PopupMenuButton<String>(
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
                                                itemBuilder: (context) {
                                                  final items =
                                                      <PopupMenuEntry<String>>[
                                                    if (RBACManager
                                                        .canEditMonitor(
                                                            auth.currentUser))
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text('Edit'),
                                                      ),
                                                    const PopupMenuItem(
                                                      value: 'history',
                                                      child:
                                                          Text('View History'),
                                                    ),
                                                    if (RBACManager.canPrintQR(
                                                        auth.currentUser))
                                                      const PopupMenuItem(
                                                        value: 'print',
                                                        child: Text('Print QR'),
                                                      ),
                                                    if (RBACManager
                                                        .canDeleteMonitor(
                                                            auth.currentUser))
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Delete'),
                                                      ),
                                                  ];
                                                  return items;
                                                },
                                                child: const SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: Center(
                                                    child:
                                                        Icon(Icons.more_horiz),
                                                  ),
                                                ),
                                              );
                                            },
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
    final r = Responsive.of(context);
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
      padding: r.insetsSymmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(r.dp(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: textColor,
              fontSize: r.sp(10),
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
    final r = Responsive.of(context);
    return Container(
      padding: r.insetsSymmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBg.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: r.sp(11),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActivityLogCard extends StatelessWidget {
  final ActivityLog log;
  final int maxDetailLines;

  const _ActivityLogCard({
    required this.log,
    required this.maxDetailLines,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final details = (log.description?.trim().isNotEmpty ?? false)
        ? log.description!.trim()
        : log.displayDetails;

    return Container(
      padding: r.insetsAll(12),
      decoration: _balancedInsetDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.dp(36),
                height: r.dp(36),
                decoration: BoxDecoration(
                  color: AppTheme.lavender600.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(r.dp(10)),
                ),
                child: Icon(
                  Icons.history,
                  size: r.icon(18),
                  color: AppTheme.lavender300,
                ),
              ),
              SizedBox(width: r.dp(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.timestamp.toString().split('.').first,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    SizedBox(height: r.dp(2)),
                    Text(
                      log.displayAction,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.dp(10)),
          Wrap(
            spacing: r.dp(8),
            runSpacing: r.dp(8),
            children: [
              _ChipPill(label: 'QR: ${log.assetQrCode}'),
              _ChipPill(label: 'User: ${log.updaterDisplayName}'),
            ],
          ),
          SizedBox(height: r.dp(10)),
          Container(
            width: double.infinity,
            padding: r.insetsAll(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBg.withOpacity(0.28),
              borderRadius: BorderRadius.circular(r.dp(10)),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Text(
              details,
              maxLines: maxDetailLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: r.sp(12),
                height: 1.3,
              ),
            ),
          ),
        ],
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
    debugPrint(
        '🔍 [DEBUG] _showEditUnitDialog START - unit: ${unit.deviceName}');
    final deviceNameController = TextEditingController(text: unit.deviceName);
    final qrCodeController = TextEditingController(text: unit.qrCode);
    final modelTypeController =
        TextEditingController(text: unit.modelType ?? '');
    final serialNumberController =
        TextEditingController(text: unit.serialNumber ?? '');
    final locationController = TextEditingController(text: unit.location ?? '');
    final descriptionController =
        TextEditingController(text: unit.description ?? '');
    String selectedStatus = unit.status;
    String selectedCondition = (unit.condition?.trim().isNotEmpty ?? false)
        ? unit.condition!.trim().toLowerCase()
        : 'good';
    final notesController = TextEditingController(text: unit.notes ?? '');

    Uint8List? selectedImageBytes;
    String? selectedImageBase64;
    String? selectedImageName;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          debugPrint('🔍 [DEBUG] Building EditUnit Dialog');
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              Future<void> pickImage() async {
                try {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked == null) return;

                  final bytes = await picked.readAsBytes();
                  if (bytes.isEmpty) return;

                  setDialogState(() {
                    selectedImageBytes = bytes;
                    selectedImageBase64 = base64Encode(bytes);
                    selectedImageName = picked.name;
                  });
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to pick image: $e')),
                  );
                }
              }

              Widget imagePickerSection() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose File'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (selectedImageName == null ||
                                    selectedImageName!.trim().isEmpty)
                                ? 'No file selected'
                                : selectedImageName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: selectedImageBytes == null
                            ? const Center(
                                child: Text(
                                  'No new image selected',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              )
                            : Image.memory(
                                selectedImageBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                    'Preview unavailable',
                                    style:
                                        TextStyle(color: AppTheme.textTertiary),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }

              return AlertDialog(
                backgroundColor: AppTheme.primaryBg,
                title: const Text('Edit Unit'),
                contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Builder(
                      builder: (context) {
                        final twoCol = MediaQuery.sizeOf(context).width >= 520;

                        final nameField = TextField(
                          controller: deviceNameController,
                          decoration:
                              _compactInputDecoration(label: 'Device Name'),
                        );
                        final qrField = TextField(
                          controller: qrCodeController,
                          readOnly: true,
                          decoration: _compactInputDecoration(label: 'QR Code'),
                        );
                        final statusField = DropdownButtonFormField<String>(
                          value: selectedStatus,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Maintenance'),
                            ),
                            DropdownMenuItem(
                                value: 'broken', child: Text('Broken')),
                            DropdownMenuItem(
                                value: 'repair', child: Text('Repair')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedStatus = value);
                            }
                          },
                          decoration: _compactInputDecoration(label: 'Status'),
                        );
                        final conditionField = DropdownButtonFormField<String>(
                          value: selectedCondition,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'new', child: Text('New')),
                            DropdownMenuItem(
                                value: 'good', child: Text('Good')),
                            DropdownMenuItem(
                                value: 'fair', child: Text('Fair')),
                            DropdownMenuItem(
                                value: 'poor', child: Text('Poor')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedCondition = value);
                            }
                          },
                          decoration:
                              _compactInputDecoration(label: 'Condition'),
                        );
                        final modelTypeField = TextField(
                          controller: modelTypeController,
                          decoration: _compactInputDecoration(
                            label: 'Model Type',
                            hint: 'Optional',
                          ),
                        );
                        final serialNumberField = TextField(
                          controller: serialNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          maxLength: 5,
                          decoration: _compactInputDecoration(
                            label: 'Serial Number',
                            hint: 'Optional',
                          ).copyWith(counterText: ''),
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
                        final notesField = TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: _compactInputDecoration(
                            label: 'Notes',
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
                              conditionField,
                              vGap(),
                              modelTypeField,
                              vGap(),
                              serialNumberField,
                              vGap(),
                              locationField,
                              vGap(),
                              descriptionField,
                              vGap(),
                              notesField,
                              vGap(),
                              imagePickerSection(),
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
                                Expanded(child: conditionField),
                              ],
                            ),
                            vGap(),
                            Row(
                              children: [
                                Expanded(child: modelTypeField),
                                const SizedBox(width: 12),
                                Expanded(child: serialNumberField),
                              ],
                            ),
                            vGap(),
                            locationField,
                            vGap(),
                            descriptionField,
                            vGap(),
                            notesField,
                            vGap(),
                            imagePickerSection(),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      debugPrint('🔍 [DEBUG] EditUnit Cancel button tapped');
                      Navigator.pop(ctx, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      debugPrint('🔍 [DEBUG] EditUnit Save button tapped');
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Save Changes'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved != true) {
        debugPrint('🔍 [DEBUG] EditUnit Dialog cancelled');
        return;
      }

      if (deviceNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device Name is required')),
        );
        return;
      }

      final serial = serialNumberController.text.trim();
      if (serial.isNotEmpty && !_isValidSerialNumber(serial)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Serial Number must be exactly 5 digits')),
        );
        return;
      }

      debugPrint('🔍 [DEBUG] Updating unit...');
      try {
        await ApiClient().updateUnit(
          unit.id,
          {
            'deviceName': deviceNameController.text.trim(),
            'status': selectedStatus,
            'condition': selectedCondition,
            'modelType': modelTypeController.text.trim(),
            'serialNumber': serialNumberController.text.trim(),
            'location': locationController.text.trim(),
            'description': descriptionController.text.trim(),
            'notes': notesController.text.trim(),
            if (selectedImageBase64 != null) 'imageData': selectedImageBase64,
          },
        );

        if (!context.mounted) {
          debugPrint('🔍 [DEBUG] Context not mounted after unit update');
          return;
        }
        debugPrint('🔍 [DEBUG] Fetching units after update');
        await context.read<UnitProvider>().fetchUnits();
        await context.read<ActivityLogProvider>().fetchActivityLogs(limit: 200);
        if (!context.mounted) {
          debugPrint('🔍 [DEBUG] Context not mounted after unit fetch');
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit updated successfully')),
        );
        debugPrint('🔍 [DEBUG] Unit update completed successfully');
      } catch (e) {
        debugPrint('🔍 [ERROR] Unit update failed: $e');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update unit: $e')),
        );
      }
    } catch (e) {
      debugPrint('🔍 [ERROR] _showEditUnitDialog Exception: $e');
    } finally {
      deviceNameController.dispose();
      qrCodeController.dispose();
      modelTypeController.dispose();
      serialNumberController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      notesController.dispose();
      debugPrint('🔍 [DEBUG] _showEditUnitDialog END');
    }
  }

  Future<void> _deleteUnit(BuildContext context, Unit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryBg,
        title: const Text('Delete Unit'),
        content:
            Text('Delete ${unit.deviceName}? This action cannot be undone.'),
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

    // Get current user from AuthProvider
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (action == 'edit') {
      if (!RBACManager.canEditUnit(currentUser)) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to edit units'),
            ),
          );
        }
        return;
      }
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
      if (!RBACManager.canPrintQR(currentUser)) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to print QR codes'),
            ),
          );
        }
        return;
      }
      await _showPrintQrDialog(
        rootContext,
        title: unit.deviceName,
        qrCode: unit.qrCode,
      );
      return;
    }

    if (action == 'delete') {
      if (!RBACManager.canDeleteUnit(currentUser)) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to delete units'),
            ),
          );
        }
        return;
      }
      await _deleteUnit(rootContext, unit);
    }
  }

  Future<void> _showAddUnitDialog(BuildContext context) async {
    final deviceNameController = TextEditingController();
    final qrCodeController = TextEditingController();
    final modelTypeController = TextEditingController();
    final serialNumberController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final notesController = TextEditingController();
    String selectedStatus = 'active';
    String selectedCondition = 'good';

    Uint8List? selectedImageBytes;
    String? selectedImageBase64;
    String? selectedImageName;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final maxDialogHeight = MediaQuery.sizeOf(ctx).height * 0.85;

              Future<void> pickImage() async {
                try {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked == null) return;

                  final bytes = await picked.readAsBytes();
                  if (bytes.isEmpty) return;

                  setDialogState(() {
                    selectedImageBytes = bytes;
                    selectedImageBase64 = base64Encode(bytes);
                    selectedImageName = picked.name;
                  });
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to pick image: $e')),
                  );
                }
              }

              Widget imagePickerSection() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose File'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (selectedImageName == null ||
                                    selectedImageName!.trim().isEmpty)
                                ? 'No file selected'
                                : selectedImageName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: selectedImageBytes == null
                            ? const Center(
                                child: Text(
                                  'No image selected',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              )
                            : Image.memory(
                                selectedImageBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text(
                                    'Preview unavailable',
                                    style:
                                        TextStyle(color: AppTheme.textTertiary),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }

              final serial = serialNumberController.text.trim();
              final serialOk = serial.isEmpty || _isValidSerialNumber(serial);
              final canSubmit = deviceNameController.text.trim().isNotEmpty &&
                  qrCodeController.text.trim().isNotEmpty &&
                  serialOk;

              return Dialog(
                backgroundColor: AppTheme.primaryBg,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: maxDialogHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add New System Unit',
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter the details for the new system unit',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth =
                                    constraints.maxWidth.isFinite &&
                                            constraints.maxWidth > 0
                                        ? constraints.maxWidth
                                        : 560.0;
                                final twoCol = availableWidth >= 460;

                                final nameField = TextField(
                                  controller: deviceNameController,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: _compactInputDecoration(
                                    label: 'Device Name',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final qrField = TextField(
                                  controller: qrCodeController,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: _compactInputDecoration(
                                    label: 'QR Code',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final statusField =
                                    DropdownButtonFormField<String>(
                                  value: selectedStatus,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'active',
                                      child: Text('Active'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'inactive',
                                      child: Text('Inactive'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'maintenance',
                                      child: Text('Maintenance'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'broken',
                                      child: Text('Broken'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'repair',
                                      child: Text('Repair'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(
                                          () => selectedStatus = value);
                                    }
                                  },
                                  decoration: _compactInputDecoration(
                                    label: 'Status',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final conditionField =
                                    DropdownButtonFormField<String>(
                                  value: selectedCondition,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'new', child: Text('New')),
                                    DropdownMenuItem(
                                        value: 'good', child: Text('Good')),
                                    DropdownMenuItem(
                                        value: 'fair', child: Text('Fair')),
                                    DropdownMenuItem(
                                        value: 'poor', child: Text('Poor')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                          setDialogState(
                                          () => selectedCondition = value);
                                    }
                                  },
                                  decoration: _compactInputDecoration(
                                    label: 'Condition',
                                    context: ctx,
                                    requiredField: true,
                                  ),
                                );
                                final modelTypeField = TextField(
                                  controller: modelTypeController,
                                  decoration: _compactInputDecoration(
                                    label: 'Model Type',
                                    hint: 'Optional',
                                  ),
                                );
                                final serialNumberField = TextField(
                                  controller: serialNumberController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  maxLength: 5,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: _compactInputDecoration(
                                    label: 'Serial Number',
                                    hint: 'Optional',
                                  ).copyWith(counterText: ''),
                                );
                                final locationField = TextField(
                                  controller: locationController,
                                  decoration: _compactInputDecoration(
                                    label: 'Location',
                                    hint: 'Optional',
                                  ),
                                );
                                final notesField = TextField(
                                  controller: notesController,
                                  maxLines: 2,
                                  decoration: _compactInputDecoration(
                                    label: 'Notes',
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

                                Widget vGap([double h = 10]) => SizedBox(
                                      height: h,
                                    );

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
                                      conditionField,
                                      vGap(),
                                      modelTypeField,
                                      vGap(),
                                      serialNumberField,
                                      vGap(),
                                      locationField,
                                      vGap(),
                                      notesField,
                                      vGap(),
                                      descriptionField,
                                      vGap(),
                                      imagePickerSection(),
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
                                        Expanded(child: serialNumberField),
                                      ],
                                    ),
                                    vGap(),
                                    Row(
                                      children: [
                                        Expanded(child: qrField),
                                        const SizedBox(width: 12),
                                        Expanded(child: conditionField),
                                      ],
                                    ),
                                    vGap(),
                                    Row(
                                      children: [
                                        Expanded(child: modelTypeField),
                                        const SizedBox(width: 12),
                                        Expanded(child: statusField),
                                      ],
                                    ),
                                    vGap(),
                                    Row(
                                      children: [
                                        Expanded(child: locationField),
                                        const SizedBox(width: 12),
                                        Expanded(child: notesField),
                                      ],
                                    ),
                                    vGap(),
                                    descriptionField,
                                    vGap(),
                                    imagePickerSection(),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: canSubmit
                                  ? () => Navigator.pop(ctx, true)
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Unit'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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

      final serial = serialNumberController.text.trim();
      if (serial.isNotEmpty && !_isValidSerialNumber(serial)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Serial Number must be exactly 5 digits')),
        );
        return;
      }

      final provider = context.read<UnitProvider>();
      final ok = await provider.createUnit(
        deviceNameController.text.trim(),
        qrCodeController.text.trim(),
        selectedStatus,
        condition: selectedCondition,
        modelType: modelTypeController.text.trim(),
        serialNumber: serialNumberController.text.trim(),
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        notes: notesController.text.trim(),
        imageData: selectedImageBase64,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ok ? 'Unit added successfully' : (provider.error ?? 'Failed')),
        ),
      );
    } finally {
      deviceNameController.dispose();
      qrCodeController.dispose();
      modelTypeController.dispose();
      serialNumberController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UnitProvider>(
      builder: (context, provider, _) {
        final r = Responsive.of(context);
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
              padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(12), r.dp(16), 0),
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
                      SizedBox(width: r.dp(8)),
                      OutlinedButton.icon(
                        onPressed: () => _exportUnitsCsv(context, filtered),
                        icon: Icon(Icons.download, size: r.icon(14)),
                        label: Text('Export CSV',
                            style: TextStyle(fontSize: r.sp(11))),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, r.dp(32)),
                          padding:
                              r.insetsSymmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      SizedBox(width: r.dp(8)),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final canAddUnit =
                              RBACManager.canAddUnit(auth.currentUser);
                          return ElevatedButton.icon(
                            onPressed: canAddUnit
                                ? () => _showAddUnitDialog(context)
                                : null,
                            icon: Icon(Icons.add, size: r.icon(13)),
                            label: Text('Add Unit',
                                style: TextStyle(fontSize: r.sp(11))),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, r.dp(32)),
                              padding: r.insetsSymmetric(
                                  horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(10), r.dp(16), 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCol = constraints.maxWidth >= 700;
                  final fieldWidth = twoCol
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: r.dp(12),
                    runSpacing: r.dp(10),
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
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                            DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance')),
                            DropdownMenuItem(
                                value: 'broken', child: Text('Broken')),
                            DropdownMenuItem(
                                value: 'repair', child: Text('Repair')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _statusFilter = value);
                            }
                          },
                          decoration: _compactInputDecoration(
                            label: 'Filter by status',
                            prefixIcon: const Icon(Icons.filter_alt_outlined),
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
                                                      style: TextStyle(
                                                        color: AppTheme
                                                            .textTertiary,
                                                        fontSize: r.sp(11),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _StatusBadge(status: unit.status),
                                              Consumer<AuthProvider>(
                                                builder: (context, auth, _) {
                                                  return PopupMenuButton<
                                                      String>(
                                                    tooltip: 'Actions',
                                                    onOpened: () {
                                                      if (!mounted) return;
                                                      setState(() =>
                                                          _suppressCardTap =
                                                              true);
                                                    },
                                                    onCanceled: () {
                                                      if (!mounted) return;
                                                      setState(() =>
                                                          _suppressCardTap =
                                                              false);
                                                    },
                                                    onSelected: (value) {
                                                      if (mounted) {
                                                        setState(() =>
                                                            _suppressCardTap =
                                                                false);
                                                      }
                                                      _afterMenuClose(
                                                        () => _handleUnitAction(
                                                          context,
                                                          value,
                                                          unit,
                                                        ),
                                                      );
                                                    },
                                                    itemBuilder: (context) {
                                                      final items =
                                                          <PopupMenuEntry<
                                                              String>>[
                                                        if (RBACManager
                                                            .canEditUnit(auth
                                                                .currentUser))
                                                          const PopupMenuItem(
                                                            value: 'edit',
                                                            child: ListTile(
                                                              dense: true,
                                                              leading: Icon(Icons
                                                                  .edit_outlined),
                                                              title:
                                                                  Text('Edit'),
                                                            ),
                                                          ),
                                                        const PopupMenuItem(
                                                          value: 'history',
                                                          child: ListTile(
                                                            dense: true,
                                                            leading: Icon(
                                                                Icons.history),
                                                            title: Text(
                                                                'View History'),
                                                          ),
                                                        ),
                                                        if (RBACManager
                                                            .canPrintQR(auth
                                                                .currentUser))
                                                          const PopupMenuItem(
                                                            value: 'print',
                                                            child: ListTile(
                                                              dense: true,
                                                              leading: Icon(Icons
                                                                  .qr_code_2),
                                                              title: Text(
                                                                  'Print QR'),
                                                            ),
                                                          ),
                                                        if (RBACManager
                                                            .canDeleteUnit(auth
                                                                .currentUser))
                                                          const PopupMenuItem(
                                                            value: 'delete',
                                                            child: ListTile(
                                                              dense: true,
                                                              leading: Icon(Icons
                                                                  .delete_outline),
                                                              title: Text(
                                                                  'Delete'),
                                                            ),
                                                          ),
                                                      ];
                                                      return items;
                                                    },
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Icon(
                                                          Icons.more_horiz),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _ChipPill(
                                                label:
                                                    'Location: ${unit.location ?? 'N/A'}',
                                              ),
                                              _ChipPill(
                                                label:
                                                    'Desc: ${unit.description ?? 'No description'}',
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
                                    DataColumn(label: Text('Device ID')),
                                    DataColumn(label: Text('Device Name')),
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
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: Tooltip(
                                              message: unit.id,
                                              child: Text(
                                                _infocomDeviceIdFromUuid(
                                                    unit.id),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(unit.deviceName)),
                                        DataCell(
                                            _StatusBadge(status: unit.status)),
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
                                          Consumer<AuthProvider>(
                                            builder: (context, auth, _) {
                                              return PopupMenuButton<String>(
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
                                                itemBuilder: (context) {
                                                  final items =
                                                      <PopupMenuEntry<String>>[
                                                    if (RBACManager.canEditUnit(
                                                        auth.currentUser))
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text('Edit'),
                                                      ),
                                                    const PopupMenuItem(
                                                      value: 'history',
                                                      child:
                                                          Text('View History'),
                                                    ),
                                                    if (RBACManager.canPrintQR(
                                                        auth.currentUser))
                                                      const PopupMenuItem(
                                                        value: 'print',
                                                        child: Text('Print QR'),
                                                      ),
                                                    if (RBACManager
                                                        .canDeleteUnit(
                                                            auth.currentUser))
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Delete'),
                                                      ),
                                                  ];
                                                  return items;
                                                },
                                                child: const SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: Center(
                                                    child:
                                                        Icon(Icons.more_horiz),
                                                  ),
                                                ),
                                              );
                                            },
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

class ActivityLogsTab extends StatefulWidget {
  const ActivityLogsTab({Key? key}) : super(key: key);

  @override
  State<ActivityLogsTab> createState() => _ActivityLogsTabState();
}

class _ActivityLogsTabState extends State<ActivityLogsTab> {
  String _query = '';
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

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

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Consumer<ActivityLogProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final q = _query.trim().toLowerCase();
        final filteredLogs = provider.logs.where((log) {
          final matchesQuery = q.isEmpty ||
              log.displayAction.toLowerCase().contains(q) ||
              log.assetQrCode.toLowerCase().contains(q) ||
              log.displayDetails.toLowerCase().contains(q) ||
              log.updaterDisplayName.toLowerCase().contains(q);

          final ts = log.timestamp;
          final matchesRange =
              (_startDateTime == null || !ts.isBefore(_startDateTime!)) &&
                  (_endDateTime == null || !ts.isAfter(_endDateTime!));

          return matchesQuery && matchesRange;
        }).toList();

        return Padding(
          padding: r.insetsAll(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: Container(
                  decoration: _balancedSurfaceDecoration(elevated: true),
                  child: provider.logs.isEmpty
                      ? Center(
                          child: Text(
                            'No activity logs',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : filteredLogs.isEmpty
                          ? Center(
                              child: Text(
                                'No logs found',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 720) {
                                  return ListView.separated(
                                    padding: r.insetsAll(14),
                                    itemCount: filteredLogs.length,
                                    separatorBuilder: (_, __) =>
                                        SizedBox(height: r.dp(10)),
                                    itemBuilder: (context, index) {
                                      final log = filteredLogs[index];
                                      return _ActivityLogCard(
                                        log: log,
                                        maxDetailLines: 10,
                                      );
                                    },
                                  );
                                }

                                return SingleChildScrollView(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        AppTheme.primaryBg.withOpacity(0.55),
                                      ),
                                      dataRowMinHeight: r.dp(42),
                                      dataRowMaxHeight: r.dp(56),
                                      columnSpacing: r.dp(18),
                                      horizontalMargin: r.dp(14),
                                      columns: const [
                                        DataColumn(label: Text('Timestamp')),
                                        DataColumn(label: Text('Action')),
                                        DataColumn(label: Text('QR Code')),
                                        DataColumn(label: Text('Details')),
                                      ],
                                      rows: filteredLogs.map((log) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                log.timestamp
                                                    .toString()
                                                    .split('.')
                                                    .first,
                                                style: TextStyle(
                                                    fontSize: r.sp(11)),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                log.displayAction,
                                                style: TextStyle(
                                                    fontSize: r.sp(11)),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                log.assetQrCode,
                                                style: TextStyle(
                                                    fontSize: r.sp(11)),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: r.dp(220),
                                                child: Text(
                                                  log.displayDetails,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: r.sp(11)),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
