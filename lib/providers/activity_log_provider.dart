import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/activity_log_model.dart';

class ActivityLogProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<ActivityLog> _logs = [];
  bool _isLoading = false;
  String? _error;

  List<ActivityLog> get logs => _logs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchActivityLogs({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.listActivityLogs(limit: limit);
      _logs = response
          .map((log) => ActivityLog.fromJson(log as Map<String, dynamic>))
          .toList();
      // Sort by timestamp descending
      _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      _error = 'Failed to fetch activity logs: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createActivityLog(
    String assetId,
    String assetQrCode,
    String action, {
    String? newLocation,
    String? newStatus,
  }) async {
    try {
      final data = {
        'assetId': assetId,
        'assetQrCode': assetQrCode,
        'action': action,
        'newLocation': newLocation,
        'newStatus': newStatus,
      };
      await _apiClient.createActivityLog(data);
      await fetchActivityLogs();
      return true;
    } catch (e) {
      _error = 'Failed to create activity log: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  List<ActivityLog> getRecentLogs(int count) {
    return _logs.take(count).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
  