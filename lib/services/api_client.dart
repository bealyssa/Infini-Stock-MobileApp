import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infini_stock/models/models.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:5000/api';
  static late Dio _dio;
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('authToken');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // Auth - Static methods
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return response.data ?? {};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('user');
  }

  // Monitors - Static methods
  static Future<List<Monitor>> getMonitors() async {
    try {
      final response = await _dio.get('/monitors');
      final data = response.data as List;
      return data.map((item) => Monitor.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Monitor> createMonitor(Map<String, dynamic> data) async {
    final response = await _dio.post('/monitors', data: data);
    return Monitor.fromJson(response.data);
  }

  static Future<Monitor> updateMonitor(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/monitors/$id', data: data);
    return Monitor.fromJson(response.data);
  }

  static Future<void> deleteMonitor(String id) async {
    await _dio.delete('/monitors/$id');
  }

  // System Units - Static methods
  static Future<List<SystemUnit>> getSystemUnits() async {
    try {
      final response = await _dio.get('/units');
      final data = response.data as List;
      return data.map((item) => SystemUnit.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<SystemUnit> createUnit(Map<String, dynamic> data) async {
    final response = await _dio.post('/units', data: data);
    return SystemUnit.fromJson(response.data);
  }

  static Future<SystemUnit> updateUnit(String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/units/$id', data: data);
    return SystemUnit.fromJson(response.data);
  }

  static Future<void> deleteUnit(String id) async {
    await _dio.delete('/units/$id');
  }

  // Activity Logs - Static methods
  static Future<List<ActivityLog>> getActivityLogs(int limit) async {
    try {
      final response = await _dio.get('/logs', queryParameters: {'limit': limit});
      final data = response.data as List;
      return data.map((item) => ActivityLog.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Dashboard - Static methods
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('/dashboard/stats');
      return response.data ?? {};
    } catch (e) {
      return {};
    }
  }

  // Users - Static methods
  static Future<List<User>> getUsers() async {
    try {
      final response = await _dio.get('/admin/users');
      final data = response.data as List;
      return data.map((item) => User.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<User> createUser(Map<String, dynamic> data) async {
    final response = await _dio.post('/admin/users', data: data);
    return User.fromJson(response.data);
  }

  static Future<void> deleteUser(String id) async {
    await _dio.delete('/admin/users/$id');
  }

  static Future<User> toggleUserStatus(String id, bool isActive) async {
    final response = await _dio.patch(
      '/admin/users/$id',
      data: {'is_active': isActive},
    );
    return User.fromJson(response.data);
  }
}
