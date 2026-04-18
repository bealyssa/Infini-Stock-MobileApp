import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiClient.getDefaultBaseUrl();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _handleLogin(AuthProvider authProvider) async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
      _urlController.text.trim(),
    );

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
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
                  // API URL Input
                  ExpansionTile(
                    title: const Text(
                      'Connection Settings',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.all(12),
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'Backend URL',
                          helperText: 'Example: http://localhost:5000/api',
                          prefixIcon: const Icon(Icons.link),
                          prefixIconColor: AppTheme.lavender500,
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, top: 8),
                          child: Text(
                            '💡 Web/Desktop uses localhost.\n'
                            'Android emulator uses 10.0.2.2.\n'
                            'Physical devices need your PC IP address.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Error Message
                  if (authProvider.error != null)
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
                              authProvider.error!,
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
