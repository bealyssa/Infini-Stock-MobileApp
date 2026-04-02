import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/unit_model.dart';

class UnitProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<Unit> _units = [];
  bool _isLoading = false;
  String? _error;

  List<Unit> get units => _units;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUnits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.listUnits();
      if (response is List) {
        _units = response
            .map((u) => Unit.fromJson(u as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to fetch units: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUnit(
    String deviceName,
    String qrCode,
    String status, {
    String? location,
    String? description,
  }) async {
    try {
      final data = {
        'deviceName': deviceName,
        'qrCode': qrCode,
        'status': status,
        if (location != null && location.isNotEmpty) 'location': location,
        if (description != null && description.isNotEmpty)
          'description': description,
      };
      await _apiClient.createUnit(data);
      await fetchUnits();
      return true;
    } catch (e) {
      _error = 'Failed to create unit: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUnitStatus(String id, String status) async {
    try {
      await _apiClient.updateUnit(id, {'status': status});
      await fetchUnits();
      return true;
    } catch (e) {
      _error = 'Failed to update unit: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  List<Unit> get activeUnits => _units.where((u) => u.isActive).toList();

  List<Unit> get brokenUnits => _units.where((u) => u.isBroken).toList();

  List<Unit> get maintenanceUnits =>
      _units.where((u) => u.isInMaintenance).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
