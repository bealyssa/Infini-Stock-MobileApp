import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    // Simple pragmatic email check.
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  void _handleLogin(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _validationError = null);

    if (email.isEmpty) {
      setState(() => _validationError = 'Email is required');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _validationError = 'Enter a valid email address');
      return;
    }
    if (password.isEmpty) {
      setState(() => _validationError = 'Password is required');
      return;
    }
    if (password.length < 6) {
      setState(() => _validationError = 'Password must be at least 6 characters');
      return;
    }

    // Clear any previous API errors once user retries.
    authProvider.clearError();

    final success = await authProvider.login(email, password);

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
      return;
    }

    if (!mounted) return;
    // Keep error display area consistent even if provider error is null.
    if (authProvider.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  // Logo/Title
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '📦',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Infini-Stock',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppTheme.lavender600,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Asset Tracking & Inventory',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  // Email Input
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      prefixIconColor: AppTheme.lavender500,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  // Password Input
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      prefixIconColor: AppTheme.lavender500,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _showPassword = !_showPassword);
                        },
                      ),
                    ),
                    obscureText: !_showPassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                  // Error Message
                  if (_validationError != null || authProvider.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.statusError.withOpacity(0.1),
                        border: Border.all(color: AppTheme.statusError),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.statusError,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (_validationError ?? authProvider.error) ??
                                  'Login failed',
                              style: const TextStyle(
                                color: AppTheme.statusError,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Login Button
                  ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _handleLogin(authProvider),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.textPrimary,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 24),
                  // Footer
                  Center(
                    child: Text(
                      'Enterprise Asset Tracking Solution',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textHint,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
