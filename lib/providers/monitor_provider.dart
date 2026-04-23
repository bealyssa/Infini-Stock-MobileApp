import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/monitor_model.dart';

class MonitorProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<Monitor> _monitors = [];
  bool _isLoading = false;
  String? _error;

  List<Monitor> get monitors => _monitors;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMonitors() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.listMonitors();
      _monitors = response
          .map((m) => Monitor.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch monitors: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createMonitor(
    String deviceName,
    String qrCode,
    String status, {
    String? condition,
    String? modelType,
    String? serialNumber,
    String? linkedUnitId,
    String? location,
    String? description,
    String? notes,
    String? imageData,
  }) async {
    try {
      final data = {
        'deviceName': deviceName,
        'qrCode': qrCode,
        'status': status,
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        if (modelType != null && modelType.isNotEmpty) 'modelType': modelType,
        if (serialNumber != null && serialNumber.isNotEmpty)
          'serialNumber': serialNumber,
        if (linkedUnitId != null && linkedUnitId.isNotEmpty)
          'linkedUnitId': linkedUnitId,
        if (location != null && location.isNotEmpty) 'location': location,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (imageData != null && imageData.isNotEmpty) 'imageData': imageData,
      };
      await _apiClient.createMonitor(data);
      await fetchMonitors();
      return true;
    } catch (e) {
      _error = 'Failed to create monitor: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMonitorStatus(String id, String status) async {
    try {
      await _apiClient.updateMonitor(id, {'status': status});
      await fetchMonitors();
      return true;
    } catch (e) {
      _error = 'Failed to update monitor: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  List<Monitor> get activeMonitors =>
      _monitors.where((m) => m.isActive).toList();

  List<Monitor> get brokenMonitors =>
      _monitors.where((m) => m.isBroken).toList();

  List<Monitor> get maintenanceMonitors =>
      _monitors.where((m) => m.isInMaintenance).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
