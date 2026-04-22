import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  User? _currentUser;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get currentUser => _currentUser;
  String? get token => _token;

  Future<void> refreshMe() async {
    try {
      final data = await _apiClient.getMe();
      if (data['user'] != null) {
        _currentUser = User.fromJson(data['user']);
        notifyListeners();
      }
    } catch (_) {
      // Ignore: keep existing cached user.
    }
  }

  Future<void> applyAccountUpdate({
    required User user,
    String? token,
  }) async {
    _currentUser = user;
    if (token != null && token.isNotEmpty) {
      _token = token;
      await _apiClient.setToken(token);
    }
    notifyListeners();
  }

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if token exists in storage
      await _apiClient.loadToken();
      if (_apiClient.getToken() != null) {
        _token = _apiClient.getToken();
        _isAuthenticated = true;
        // Here you could fetch current user info
      }
    } catch (e) {
      _error = 'Failed to initialize authentication';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password, String apiUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Set custom API URL
      _apiClient.setBaseUrl(apiUrl);

      // Call login endpoint
      final response = await _apiClient.login(email, password);

      if (response['token'] != null) {
        _token = response['token'];
        await _apiClient.setToken(_token!);

        // Parse user info if available
        if (response['user'] != null) {
          _currentUser = User.fromJson(response['user']);
        }

        _isAuthenticated = true;
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login error: ${e.toString()}';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiClient.logout();
      _isAuthenticated = false;
      _token = null;
      _currentUser = null;
      _error = null;
    } catch (e) {
      _error = 'Logout error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
