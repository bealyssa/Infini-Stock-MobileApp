// QR Scanner Integration Guide
// This file documents how to implement QR scanning in the app

/*
QUICK START: QR Scanning Implementation

1. Add to your screen where you want scanning:

```dart
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR Code')),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            debugPrint('Barcode found! ${barcode.rawValue}');
            // Process QR code
            _handleQRCode(barcode.rawValue ?? '');
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await cameraController.toggleTorch();
        },
        child: Icon(Icons.flash_on),
      ),
    );
  }

  void _handleQRCode(String qrCode) {
    // Push to home, add monitor, or perform action
    Navigator.pop(context, qrCode);
  }

  @override
  dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
```

2. Call the scanner from any screen:

```dart
void _openQRScanner() async {
  if (!mounted) return;
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => QRScannerScreen()),
  );
  
  if (result != null) {
    print('Scanned QR: $result');
    // Handle the scanned QR code
  }
}
```

3. Grant permissions in AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

FEATURES:
- Real-time barcode detection
- Torch/flashlight toggle
- Multiple format support (QR, Code128, etc.)
- High performance on modern devices

TROUBLESHOOTING:
- If camera doesn't open: Check permissions in app settings
- If scanning is slow: Check device camera quality
- If torch not working: Device may not support it

For more info: https://pub.dev/packages/mobile_scanner
*/

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class QRScannerHelper {
  /// Launch QR scanner and return scanned code
  static Future<String?> scanQRCode(BuildContext context) async {
    return await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerView()),
    );
  }
}

class QRScannerView extends StatefulWidget {
  const QRScannerView({Key? key}) : super(key: key);

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  late MobileScannerController _cameraController;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      autoStart: true,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        Navigator.pop(context, barcode.rawValue);
      }
    }
  }

  void _toggleTorch() async {
    await _cameraController.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBg,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: MobileScanner(
        controller: _cameraController,
        onDetect: _handleDetection,
        errorBuilder: (context, error, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.statusError),
                const SizedBox(height: 16),
                Text(
                  'Camera Error',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please grant camera permissions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.close),
      ),
    );
  }
}
