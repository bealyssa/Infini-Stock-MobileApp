import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/monitor_provider.dart';
import 'providers/unit_provider.dart';
import 'providers/activity_log_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_background.dart';
import 'utils/responsive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MonitorProvider()),
        ChangeNotifierProvider(create: (_) => UnitProvider()),
        ChangeNotifierProvider(create: (_) => ActivityLogProvider()),
      ],
      child: MaterialApp(
        title: 'Infini-Stock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final scale = Responsive.scaleForWidth(media.size.width);

          final baseTheme = Theme.of(context);
          final scaledTheme = baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontSizeFactor: scale),
          );

          return Theme(
            data: scaledTheme,
            child: AppBackground(child: child ?? const SizedBox.shrink()),
          );
        },
        home: const AuthCheck(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return Scaffold(
            backgroundColor: AppTheme.primaryBg,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return authProvider.isAuthenticated
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}
