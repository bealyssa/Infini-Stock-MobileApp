import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:infini_stock/theme/app_theme.dart';

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final _qrDataController = TextEditingController();
  String? _generatedQRData;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void dispose() {
    _qrDataController.dispose();
    super.dispose();
  }

  void _generateQR() {
    if (_qrDataController.text.isNotEmpty) {
      setState(() {
        _generatedQRData = _qrDataController.text;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter data for QR code'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareQR() async {
    if (_generatedQRData != null) {
      await Share.share(
        'Check this QR Code: $_generatedQRData',
        subject: 'QR Code for $_generatedQRData',
      );
    }
  }

  void _clearQR() {
    setState(() {
      _qrDataController.clear();
      _generatedQRData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'QR Code Generator',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate QR codes for tracking assets and inventory',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGraySecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Input Section
          Text(
            'Data to Encode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qrDataController,
            decoration: InputDecoration(
              hintText: 'Enter text or URL for QR code',
              filled: true,
              fillColor: AppTheme.bgDarker,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderLavender),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderLavender),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppTheme.lavender600,
                  width: 2,
                ),
              ),
              hintStyle: TextStyle(color: AppTheme.textGraySecondary),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _generateQR,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lavender600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.qr_code_2, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Generate QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _clearQR,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: AppTheme.borderLavender),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Icon(Icons.clear),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // QR Display Section
          if (_generatedQRData != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgDarker,
                border: Border.all(color: AppTheme.borderLavender),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // QR Code Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      key: _qrKey,
                      data: _generatedQRData!,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // QR Data Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Encoded Data',
                          style: TextStyle(
                            color: AppTheme.textGraySecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _generatedQRData!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Courier',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Share Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _shareQR,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lavender600.withOpacity(0.7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.share, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Share QR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Quick Reference
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.borderLavender.withOpacity(0.1),
                border: Border.all(color: AppTheme.borderLavender),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.lavender600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Tips for QR Codes',
                        style: TextStyle(
                          color: AppTheme.lavender300,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TipItem(
                    icon: Icons.tag,
                    title: 'Asset IDs',
                    description: 'Use unique asset identifiers like MON-001 or UNIT-002',
                  ),
                  const SizedBox(height: 8),
                  _TipItem(
                    icon: Icons.link,
                    title: 'URLs',
                    description: 'Or encode full URLs for web-based tracking',
                  ),
                  const SizedBox(height: 8),
                  _TipItem(
                    icon: Icons.print,
                    title: 'Print',
                    description: 'Print generated QR codes on labels or stickers',
                  ),
                ],
              ),
            ),
          ] else ...[
            // Empty State
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.lavender600.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.qr_code_2,
                        size: 48,
                        color: AppTheme.lavender600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No QR Code Generated',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter data above and click Generate to create a QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textGraySecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TipItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.lavender600, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.textGraySecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
