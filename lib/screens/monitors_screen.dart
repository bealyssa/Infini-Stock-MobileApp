import 'package:flutter/material.dart';
import 'package:infini_stock/models/models.dart';
import 'package:infini_stock/services/api_client.dart';
import 'package:infini_stock/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MonitorsScreen extends StatefulWidget {
  const MonitorsScreen({Key? key}) : super(key: key);

  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen> {
  late Future<List<Monitor>> _monitorsFuture;
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _filterOptions = [
    {'label': 'All', 'value': 'all'},
    {'label': 'Active', 'value': 'active'},
    {'label': 'Maintenance', 'value': 'maintenance'},
    {'label': 'Inactive', 'value': 'inactive'},
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _refresh() {
    _monitorsFuture = ApiClient.getMonitors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Monitor> _filterMonitors(List<Monitor> monitors) {
    var filtered = monitors;

    // Filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered
          .where((m) => m.status.toLowerCase() == _selectedFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((m) =>
              m.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              m.qrCode.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _refresh();
        });
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search monitors...',
                filled: true,
                fillColor: AppTheme.bgDarker,
                prefixIcon: Icon(Icons.search, color: AppTheme.textGraySecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.borderLavender),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.borderLavender),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.lavender600,
                    width: 2,
                  ),
                ),
                hintStyle: TextStyle(color: AppTheme.textGraySecondary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((option) {
                  final isActive = _selectedFilter == option['value'];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(option['label']!),
                      selected: isActive,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = option['value']!;
                        });
                      },
                      backgroundColor: AppTheme.bgDarker,
                      selectedColor: AppTheme.lavender600.withOpacity(0.3),
                      side: BorderSide(
                        color: isActive
                            ? AppTheme.lavender600
                            : AppTheme.borderLavender,
                      ),
                      labelStyle: TextStyle(
                        color: isActive
                            ? AppTheme.lavender300
                            : AppTheme.textGraySecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Monitors List
            FutureBuilder<List<Monitor>>(
              future: _monitorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error loading monitors: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final monitors = _filterMonitors(snapshot.data ?? []);
                if (monitors.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No monitors found',
                        style: TextStyle(
                          color: AppTheme.textGraySecondary,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: monitors.map((monitor) {
                    return _MonitorCard(monitor: monitor);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorCard extends StatelessWidget {
  final Monitor monitor;

  const _MonitorCard({required this.monitor});

  Color _getStatusColor() {
    switch (monitor.status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.amber;
      case 'inactive':
        return Colors.grey;
      default:
        return AppTheme.lavender600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgDarker,
        border: Border.all(color: AppTheme.borderLavender),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monitor.deviceName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    monitor.status,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'QR: ${monitor.qrCode}',
                  style: TextStyle(
                    color: AppTheme.textGraySecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // QR Code
                QrImageView(
                  data: monitor.qrCode,
                  version: QrVersions.auto,
                  size: 120,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                // Details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Unit',
                          style: TextStyle(
                            color: AppTheme.textGraySecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          monitor.linkedUnit ?? 'Not linked',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Created By',
                          style: TextStyle(
                            color: AppTheme.textGraySecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          monitor.createdBy,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (monitor.description != null &&
                    monitor.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: AppTheme.borderLavender),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: TextStyle(
                          color: AppTheme.textGraySecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monitor.description!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
