import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF050814),
            Color(0xFF070A1C),
            Color(0xFF0A0F2A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            left: -80,
            child: _GlowBlob(
              color: AppTheme.lavender600.withOpacity(0.10),
            ),
          ),
          Positioned(
            bottom: -220,
            right: -220,
            child: _GlowBlob(
              color: AppTheme.lavender500.withOpacity(0.10),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;

  const _GlowBlob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      height: 520,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 120,
            spreadRadius: 40,
          ),
        ],
      ),
    );
  }
}
