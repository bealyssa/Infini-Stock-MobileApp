import 'package:flutter/material.dart';
import 'package:infini_stock/models/models.dart';
import 'package:infini_stock/services/api_client.dart';
import 'package:infini_stock/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SystemUnitsScreen extends StatefulWidget {
  const SystemUnitsScreen({Key? key}) : super(key: key);

  @override
  State<SystemUnitsScreen> createState() => _SystemUnitsScreenState();
}

class _SystemUnitsScreenState extends State<SystemUnitsScreen> {
  late Future<List<SystemUnit>> _unitsFuture;
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
    _unitsFuture = ApiClient.getSystemUnits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SystemUnit> _filterUnits(List<SystemUnit> units) {
    var filtered = units;

    // Filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered
          .where((u) => u.status.toLowerCase() == _selectedFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((u) =>
              u.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.qrCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.location.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                hintText: 'Search units...',
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

            // Units List
            FutureBuilder<List<SystemUnit>>(
              future: _unitsFuture,
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
                      'Error loading units: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final units = _filterUnits(snapshot.data ?? []);
                if (units.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No units found',
                        style: TextStyle(
                          color: AppTheme.textGraySecondary,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: units.map((unit) {
                    return _SystemUnitCard(unit: unit);
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

class _SystemUnitCard extends StatelessWidget {
  final SystemUnit unit;

  const _SystemUnitCard({required this.unit});

  Color _getStatusColor() {
    switch (unit.status.toLowerCase()) {
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
              unit.deviceName,
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
                    unit.status,
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '📍 ${unit.location}',
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
                  data: unit.qrCode,
                  version: QrVersions.auto,
                  size: 120,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                // Details Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _DetailBox(
                      label: 'QR Code',
                      value: unit.qrCode,
                    ),
                    _DetailBox(
                      label: 'Location',
                      value: unit.location,
                    ),
                    _DetailBox(
                      label: 'Status',
                      value: unit.status,
                    ),
                    _DetailBox(
                      label: 'Created By',
                      value: unit.createdBy,
                    ),
                  ],
                ),
                if (unit.linkedMonitor != null &&
                    unit.linkedMonitor!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: AppTheme.borderLavender),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.monitor, color: AppTheme.lavender600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Linked Monitor',
                              style: TextStyle(
                                color: AppTheme.textGraySecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unit.linkedMonitor!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (unit.description != null &&
                    unit.description!.isNotEmpty) ...[
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
                        unit.description!,
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

class _DetailBox extends StatelessWidget {
  final String label;
  final String value;

  const _DetailBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.bgDarker,
        border: Border.all(color: AppTheme.borderLavender),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textGraySecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
