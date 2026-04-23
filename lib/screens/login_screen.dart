import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(trimmed);
  }

  void _handleLogin(AuthProvider authProvider) async {
    setState(() => _submitted = true);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: r.insetsAll(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
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
                        SizedBox(height: r.dp(16)),
                        Text(
                          'InfoTrack',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppTheme.lavender600,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(height: r.dp(8)),
                        Text(
                          'Asset Tracking & Inventory',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      prefixIconColor: AppTheme.lavender500,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'Email is required';
                      if (!_looksLikeEmail(v)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: r.dp(16)),
                  // Password Input
                  TextFormField(
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
                    validator: (value) {
                      final v = value ?? '';
                      if (v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Password must be 6+ characters';
                      return null;
                    },
                  ),
                  SizedBox(height: r.dp(24)),
                  // Error Message
                  if (authProvider.error != null)
                    Container(
                      padding: r.insetsAll(12),
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
                          SizedBox(width: r.dp(12)),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: TextStyle(
                                color: AppTheme.statusError,
                                fontSize: r.sp(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: r.dp(24)),
                  // Login Button
                  ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _handleLogin(authProvider),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: r.dp(16)),
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
                  SizedBox(height: r.dp(24)),
                  // Footer
                  Center(
                    child: Text(
                      'Enterprise Asset Tracking Solution',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(height: r.dp(16)),
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
            ),
          );
        },
      ),
    );
  }
}
