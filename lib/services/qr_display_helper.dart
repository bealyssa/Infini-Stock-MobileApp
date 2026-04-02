import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    border: Border.all(color: AppTheme.borderDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildQrImage(qrData, 300.0),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border.all(color: AppTheme.borderDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildQrImage(data, size),
    );
  }

  /// Build a card with QR code
  static Widget buildQRCard({
    required String data,
    required String title,
    String? subtitle,
    double size = 150,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildQrImage(data, size),
            const SizedBox(height: 12),
            SelectableText(
              data,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
