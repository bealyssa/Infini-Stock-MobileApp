import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio _dio;
  String? _token;
  String? _baseUrl;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _initializeDio();
  }

  void _initializeDio() {
    // Default base URL - hardcoded for local WiFi
    _baseUrl = 'http://192.168.1.2:5000/api';

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl!,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        contentType: 'application/json',
      ),
    );

    // Add interceptor to include token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Handle token expiration
            _clearAuth();
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Get current token
  String? getToken() => _token;

  /// Set the base URL for API calls
  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  /// Get available IP for connection setup
  static String getConnectionSetupInfo() {
    final platform = kIsWeb
        ? 'Web'
        : Platform.isAndroid
            ? 'Android'
            : 'iOS';
    return '''
For mobile to connect to backend:

1. Get your PC IP address:
   Windows: Open cmd and run: ipconfig
   Look for IPv4 Address (typically 192.168.x.x)

2. Update the API URL in the app:
   Go to Settings and enter: http://YOUR_IP:5000/api
   
3. Make sure your phone is on the same WiFi network

Current Platform: $platform
''';
  }

  /// Set authentication token
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Load token from storage
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  /// Clear authentication
  Future<void> _clearAuth() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ==================== AUTH ENDPOINTS ====================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    return response.data;
  }

  Future<void> logout() async {
    await _clearAuth();
  }

  // ==================== MONITORS ENDPOINTS ====================

  Future<List<dynamic>> listMonitors() async {
    final response = await _dio.get('/monitors');
    return response.data is List ? response.data : [];
  }

  Future<Map<String, dynamic>> createMonitor(Map<String, dynamic> data) async {
    final response = await _dio.post('/monitors', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateMonitor(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch('/monitors/$id', data: data);
    return response.data;
  }

  Future<void> deleteMonitor(String id) async {
    await _dio.delete('/monitors/$id');
  }

  // ==================== UNITS ENDPOINTS ====================

  Future<List<dynamic>> listUnits() async {
    final response = await _dio.get('/units');
    return response.data is List ? response.data : [];
  }

  Future<Map<String, dynamic>> createUnit(Map<String, dynamic> data) async {
    final response = await _dio.post('/units', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateUnit(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch('/units/$id', data: data);
    return response.data;
  }

  Future<void> deleteUnit(String id) async {
    await _dio.delete('/units/$id');
  }

  // ==================== ACTIVITY LOGS ENDPOINTS ====================

  Future<List<dynamic>> listActivityLogs({int limit = 50}) async {
    final response = await _dio.get(
      '/activity-logs',
      queryParameters: {'limit': limit},
    );
    return response.data is List ? response.data : [];
  }

  Future<Map<String, dynamic>> createActivityLog(
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post('/activity-logs', data: data);
    return response.data;
  }

  // ==================== QR CODE ENDPOINTS ====================

  Future<Map<String, dynamic>> generateQRCode(String assetId) async {
    final response = await _dio.post(
      '/qr/generate',
      data: {'assetId': assetId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> scanQRCode(String qrCode) async {
    final response = await _dio.post(
      '/qr/scan',
      data: {'qrCode': qrCode},
    );
    return response.data;
  }

  // ==================== ADMIN ENDPOINTS ====================

  Future<List<dynamic>> listUsers() async {
    final response = await _dio.get('/admin/users');
    return response.data is List ? response.data : [];
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final response = await _dio.post('/admin/users', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.patch('/admin/users/$userId', data: data);
    return response.data;
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete('/admin/users/$userId');
  }

  // ==================== GENERIC METHODS ====================

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {required Map<String, dynamic> data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {required Map<String, dynamic> data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
