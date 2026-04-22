import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_log_model.dart';
import '../models/monitor_model.dart';
import '../models/unit_model.dart';
import '../theme/app_theme.dart';

class DashboardPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const DashboardPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.sidebarBg.withOpacity(0.48),
            AppTheme.darkBg.withOpacity(0.90),
          ],
        ),
        border: Border.all(color: AppTheme.borderDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.lavender600.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: AppTheme.lavender400),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary.withOpacity(0.80),
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderDark),
          SizedBox(
            height: 250,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityLineChart extends StatelessWidget {
  final List<ActivityLog> logs;

  const ActivityLineChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final series = _buildLast14DaysSeries(logs);
    if (series.isEmpty) {
      return Center(
        child: Text(
          'No activity',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
        ),
      );
    }

    final maxY = math.max(1, series.map((e) => e.count).fold<int>(0, math.max));
    final spots = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      spots.add(FlSpot(i.toDouble(), series[i].count.toDouble()));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: 0,
        maxY: maxY.toDouble() * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.borderLight,
            strokeWidth: 1,
            dashArray: [3, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppTheme.borderLight),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: _niceInterval(maxY),
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 2,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= series.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    series[idx].label,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: AppTheme.lavender500,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.lavender500.withOpacity(0.30),
                  AppTheme.lavender500.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPieChart extends StatelessWidget {
  final List<Monitor> monitors;
  final List<Unit> units;

  const StatusPieChart({
    super.key,
    required this.monitors,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final counts = _statusCounts(monitors: monitors, units: units);
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      return Center(
        child: Text(
          'No data',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (final status in _statusOrder) {
      final value = counts[status] ?? 0;
      if (value <= 0) continue;
      sections.add(
        PieChartSectionData(
          value: value.toDouble(),
          color: _statusColor(status),
          radius: 70,
          showTitle: false,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 42,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _statusOrder
                .where((s) => (counts[s] ?? 0) > 0)
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LegendRow(
                        color: _statusColor(s),
                        label: _statusLabel(s),
                        value: counts[s] ?? 0,
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class LocationStackedBarChart extends StatelessWidget {
  final List<Monitor> monitors;
  final List<Unit> units;

  const LocationStackedBarChart({
    super.key,
    required this.monitors,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final unitById = {for (final u in units) u.id: u};

    final buckets = <String, _LocationBucket>{};
    void addUnit(Unit u) {
      final location = (u.location ?? '').trim().isEmpty ? 'Unknown' : u.location!.trim();
      buckets.putIfAbsent(location, () => _LocationBucket(location)).units++;
    }

    void addMonitor(Monitor m) {
      String location = 'Unknown';
      if (m.linkedUnit != null && unitById[m.linkedUnit] != null) {
        final unitLoc = (unitById[m.linkedUnit]!.location ?? '').trim();
        if (unitLoc.isNotEmpty) location = unitLoc;
      }
      buckets.putIfAbsent(location, () => _LocationBucket(location)).monitors++;
    }

    for (final u in units) {
      addUnit(u);
    }
    for (final m in monitors) {
      addMonitor(m);
    }

    final data = buckets.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (data.isEmpty) {
      return Center(
        child: Text(
          'No locations',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
        ),
      );
    }

    final maxY = math.max(1, data.map((e) => e.total).fold<int>(0, math.max));

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final stacks = <BarChartRodStackItem>[];
      var running = 0.0;

      if (item.units > 0) {
        stacks.add(
          BarChartRodStackItem(
            running,
            running + item.units.toDouble(),
            AppTheme.lavender500,
          ),
        );
        running += item.units.toDouble();
      }
      if (item.monitors > 0) {
        stacks.add(
          BarChartRodStackItem(
            running,
            running + item.monitors.toDouble(),
            AppTheme.lavender700,
          ),
        );
        running += item.monitors.toDouble();
      }
      if (item.other > 0) {
        stacks.add(
          BarChartRodStackItem(
            running,
            running + item.other.toDouble(),
            AppTheme.lavender300,
          ),
        );
        running += item.other.toDouble();
      }

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: running,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              rodStackItems: stacks,
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY.toDouble() * 1.2,
        barGroups: groups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.borderLight,
            strokeWidth: 1,
            dashArray: [3, 4],
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppTheme.borderLight),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: _niceInterval(maxY),
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final label = data[idx].location;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Transform.rotate(
                    angle: -0.45,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label ($value)',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayCount {
  final DateTime day;
  final String label;
  final int count;

  const _DayCount(this.day, this.label, this.count);
}

List<_DayCount> _buildLast14DaysSeries(List<ActivityLog> logs) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));

  final counts = <String, int>{};
  for (final log in logs) {
    final d = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
    if (d.isBefore(start)) continue;
    final key = DateFormat('yyyy-MM-dd').format(d);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final out = <_DayCount>[];
  for (var i = 0; i < 14; i++) {
    final day = start.add(Duration(days: i));
    final key = DateFormat('yyyy-MM-dd').format(day);
    out.add(
      _DayCount(
        day,
        DateFormat('MMM dd').format(day),
        counts[key] ?? 0,
      ),
    );
  }
  return out;
}

const _statusOrder = [
  'active',
  'broken',
  'inactive',
  'maintenance',
  'repair',
  'other',
];

Map<String, int> _statusCounts({
  required List<Monitor> monitors,
  required List<Unit> units,
}) {
  final counts = <String, int>{
    'active': 0,
    'broken': 0,
    'inactive': 0,
    'maintenance': 0,
    'repair': 0,
    'other': 0,
  };

  String normalize(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'active') return 'active';
    if (v == 'inactive') return 'inactive';
    if (v == 'broken') return 'broken';
    if (v == 'repair') return 'repair';
    if (v == 'maintenance') return 'maintenance';
    return 'other';
  }

  for (final m in monitors) {
    counts[normalize(m.status)] = (counts[normalize(m.status)] ?? 0) + 1;
  }
  for (final u in units) {
    counts[normalize(u.status)] = (counts[normalize(u.status)] ?? 0) + 1;
  }

  return counts;
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'broken':
      return 'Broken';
    case 'inactive':
      return 'Inactive';
    case 'maintenance':
      return 'Maintenance';
    case 'repair':
      return 'Repair';
    default:
      return 'Other';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
      return AppTheme.statusSuccess;
    case 'broken':
      return AppTheme.statusError;
    case 'inactive':
      return AppTheme.textHint;
    case 'maintenance':
      return AppTheme.lavender500;
    case 'repair':
      return AppTheme.statusWarning;
    default:
      return AppTheme.lavender300;
  }
}

double _niceInterval(int maxY) {
  if (maxY <= 4) return 1;
  if (maxY <= 10) return 2;
  if (maxY <= 20) return 5;
  if (maxY <= 50) return 10;
  return 20;
}

class _LocationBucket {
  final String location;
  int units = 0;
  int monitors = 0;
  int other = 0;

  _LocationBucket(this.location);

  int get total => units + monitors + other;
}
