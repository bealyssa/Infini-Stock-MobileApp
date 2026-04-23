import 'dart:math' as math;

import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class QRDisplayHelper {
  /// Show QR code in a dialog
  static void showQRDialog(
    BuildContext context, {
    required String qrData,
    required String title,
    String? subtitle,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final r = Responsive.of(context);
        final media = MediaQuery.of(context);
        final qrSize = math.min(300.0 * r.scale, media.size.width * 0.72);
        return AlertDialog(
          backgroundColor: AppTheme.primaryBg,
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: r.dp(16)),
                ],
                Container(
                  padding: r.insetsAll(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    border: Border.all(color: AppTheme.borderDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildQrImage(qrData, qrSize),
                ),
                SizedBox(height: r.dp(16)),
                Container(
                  padding: r.insetsAll(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    border: Border.all(color: AppTheme.borderDark),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    qrData,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Helper to build QR image
  static Widget _buildQrImage(String data, double size) {
    try {
      return QrImageView(
        data: data,
        size: size,
        backgroundColor: Colors.white,
      );
    } catch (e) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey,
        child: const Center(child: Text('QR Error')),
      );
    }
  }

  /// Create a QR code widget
  static Widget buildQRCode({
    required String data,
    double size = 200,
    BuildContext? context,
  }) {
    final scale = context == null ? 1.0 : Responsive.of(context).scale;
    final scaledSize = size * scale;
    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border.all(color: AppTheme.borderDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildQrImage(data, scaledSize),
    );
  }

  /// Build a card with QR code
  static Widget buildQRCard({
    required String data,
    required String title,
    String? subtitle,
    double size = 150,
    BuildContext? context,
  }) {
    final scale = context == null ? 1.0 : Responsive.of(context).scale;
    final scaledSize = size * scale;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * scale,
                ),
              ),
            if (subtitle != null) ...[
              SizedBox(height: 4 * scale),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
            SizedBox(height: 12 * scale),
            _buildQrImage(data, scaledSize),
            SizedBox(height: 12 * scale),
            SelectableText(
              data,
              style: TextStyle(
                fontSize: 10 * scale,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
