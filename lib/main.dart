import 'package:flutter/material.dart';
import 'package:infini_stock/theme/app_theme.dart';
import 'package:infini_stock/screens/splash_screen.dart';
import 'package:infini_stock/screens/login_screen.dart';
import 'package:infini_stock/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infini-Stock',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
