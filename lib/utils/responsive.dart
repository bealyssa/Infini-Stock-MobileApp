import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class Responsive {
  static const double _baseWidth = 390.0;

  final double width;
  final double height;
  final double scale;

  const Responsive._({
    required this.width,
    required this.height,
    required this.scale,
  });

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Responsive._(
      width: size.width,
      height: size.height,
      scale: scaleForWidth(size.width),
    );
  }

  /// Scale factor used for sizing on small screens.
  ///
  /// - < 390dp wide: scales down.
  /// - >= 390dp wide: stays at 1.0 (no scaling up).
  static double scaleForWidth(double width) {
    if (width.isNaN || width.isInfinite || width <= 0) return 1.0;
    final raw = width / _baseWidth;
    return raw.clamp(0.80, 1.0);
  }

  double dp(double value) => (value * scale);
  double sp(double fontSize) => (fontSize * scale);

  double icon(double value) => math.max(10.0, dp(value));

  EdgeInsets insetsAll(double value) => EdgeInsets.all(dp(value));

  EdgeInsets insetsSymmetric({double horizontal = 0, double vertical = 0}) {
    return EdgeInsets.symmetric(
      horizontal: dp(horizontal),
      vertical: dp(vertical),
    );
  }

  BorderRadius radius(double value) => BorderRadius.circular(dp(value));
}
