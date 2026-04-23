import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:zxing2/qrcode.dart';
import '../theme/app_theme.dart';

class QRScannerHelperV2 {
  /// Launch QR scanner with camera and image upload modes
  static Future<String?> scanQRCode(BuildContext context) async {
    return await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerViewV2()),
    );
  }
}

class QRScannerViewV2 extends StatefulWidget {
  const QRScannerViewV2({Key? key}) : super(key: key);

  @override
  State<QRScannerViewV2> createState() => _QRScannerViewV2State();
}

class _QRScannerViewV2State extends State<QRScannerViewV2> {
  late ms.MobileScannerController _cameraController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTorchOn = false;
  String _mode = 'camera'; // 'camera' or 'upload'
  bool _isProcessing = false;
  String? _error;

  bool get _supportsMlKitImageScan {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String? _decodeQrFromBytesWithZxing(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Scale down large images for speed.
    const maxDim = 1024;
    var scanImage = decoded;
    if (scanImage.width > maxDim || scanImage.height > maxDim) {
      final scale = maxDim /
          (scanImage.width > scanImage.height
              ? scanImage.width
              : scanImage.height);
      final targetW = (scanImage.width * scale).round().clamp(1, maxDim);
      final targetH = (scanImage.height * scale).round().clamp(1, maxDim);
      scanImage = img.copyResize(scanImage, width: targetW, height: targetH);
    }

    final width = scanImage.width;
    final height = scanImage.height;
    final rgb = scanImage.getBytes(order: img.ChannelOrder.rgb);

    final pixels = Int32List(width * height);
    for (var i = 0, j = 0; i < pixels.length; i++, j += 3) {
      final r = rgb[j];
      final g = rgb[j + 1];
      final b = rgb[j + 2];
      pixels[i] = (r << 16) | (g << 8) | b;
    }

    final source = RGBLuminanceSource(width, height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = QRCodeReader();

    try {
      final result = reader.decode(bitmap);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } on ReaderException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraController = ms.MobileScannerController(
      autoStart: true,
      formats: const [ms.BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _handleDetection(ms.BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<ms.Barcode> barcodes = capture.barcodes;
    for (final ms.Barcode barcode in barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _isProcessing = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  void _toggleTorch() async {
    await _cameraController.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  Future<void> _pickAndScanImage() async {
    if (_isProcessing) return;

    setState(() {
      _error = null;
      _isProcessing = true;
    });

    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Primary: pure-Dart decode (works on Web/Windows/Android/iOS).
      String? value;
      try {
        final bytes = await picked.readAsBytes();
        value = _decodeQrFromBytesWithZxing(bytes);
      } catch (_) {
        // Ignore and fall back to MLKit where available.
      }

      // Fallback: MLKit on Android/iOS (sometimes more tolerant for low-quality images).
      if ((value == null || value.isEmpty) && _supportsMlKitImageScan) {
        final scanner = mlkit.BarcodeScanner(
          formats: [mlkit.BarcodeFormat.qrCode],
        );
        try {
          final inputImage = mlkit.InputImage.fromFilePath(picked.path);
          final barcodes = await scanner.processImage(inputImage);
          if (!mounted) return;

          for (final code in barcodes) {
            final raw = code.rawValue?.trim();
            if (raw != null && raw.isNotEmpty) {
              value = raw;
              break;
            }
          }
        } finally {
          try {
            await scanner.close();
          } catch (_) {
            // ignore
          }
        }
      }

      if (value == null || value.trim().isEmpty) {
        setState(() {
          _error = 'No QR code found in that image.';
          _isProcessing = false;
        });
        return;
      }

      // Return the scanned QR value back to the caller.
      Navigator.pop(context, value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to scan image: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.primaryBg,
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          elevation: 0,
          backgroundColor: AppTheme.headerBg,
          actions: _mode == 'camera'
              ? [
                  IconButton(
                    icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
                    onPressed: _toggleTorch,
                  ),
                ]
              : null,
        ),
        body: Column(
          children: [
            // Mode Toggle Buttons
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: MaterialButton(
                      onPressed: () async {
                        if (_mode == 'camera') return;
                        setState(() {
                          _mode = 'camera';
                          _error = null;
                        });
                        try {
                          await _cameraController.start();
                        } catch (_) {
                          // ignore
                        }
                      },
                      color: _mode == 'camera'
                          ? AppTheme.lavender600
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _mode == 'camera'
                              ? AppTheme.lavender600
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt),
                            SizedBox(width: 8),
                            Text('Scan'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MaterialButton(
                      onPressed: () async {
                        if (_mode == 'upload') return;
                        setState(() {
                          _mode = 'upload';
                          _error = null;
                        });
                        try {
                          await _cameraController.stop();
                        } catch (_) {
                          // ignore
                        }
                      },
                      color: _mode == 'upload'
                          ? AppTheme.lavender600
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _mode == 'upload'
                              ? AppTheme.lavender600
                              : AppTheme.borderDark,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image),
                            SizedBox(width: 8),
                            Text('Upload'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              child:
                  _mode == 'camera' ? _buildCameraView() : _buildUploadView(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.lavender600,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.close),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        ms.MobileScanner(
          controller: _cameraController,
          onDetect: _handleDetection,
          errorBuilder: (context, error, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.statusError,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Error',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Please grant camera permissions in your app settings',
                      style: TextStyle(color: AppTheme.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Scan frame overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.lavender600,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Point at QR code',
                style: TextStyle(
                  color: AppTheme.lavender600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.image,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 24),
            MaterialButton(
              onPressed: _isProcessing ? null : _pickAndScanImage,
              color: AppTheme.lavender600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 24.0,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 32,
                      color: Colors.white,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Upload QR Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 18),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.lavender600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scanning image…',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Select a photo/screenshot that contains a QR code. The app will detect and read it automatically.',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusError.withOpacity(0.1),
                  border:
                      Border.all(color: AppTheme.statusError.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.statusError,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
