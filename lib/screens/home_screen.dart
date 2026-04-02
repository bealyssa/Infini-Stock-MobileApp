import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/monitor_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/activity_log_provider.dart';
import 'qr_generator_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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

    Future.microtask(() {
      context.read<MonitorProvider>().fetchMonitors();
      context.read<UnitProvider>().fetchUnits();
      context.read<ActivityLogProvider>().fetchActivityLogs();
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
      backgroundColor: AppTheme.primaryBg,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                showLogoutDialog(context);
              },
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'Logout',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.darkBg,
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
                    '📦 Infini-Stock',
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

  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.primaryBg,
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
          backgroundColor: AppTheme.primaryBg,
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
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Active',
                      value: activeAssets,
                      icon: Icons.check_circle,
                      color: AppTheme.statusSuccess,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Broken/Repair',
                      value: brokenAssets,
                      icon: Icons.warning,
                      color: AppTheme.statusError,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
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
                      const Color(0xFF2D1F4A),
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.lavender600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border.all(color: AppTheme.borderDark),
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
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
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
                  const Color(0xFF2D1F4A),
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
