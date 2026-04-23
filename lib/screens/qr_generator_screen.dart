import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/qr_display_helper.dart';
import '../utils/responsive.dart';

class QRGeneratorScreen extends StatefulWidget {
  final bool embedded;

  const QRGeneratorScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final _assetIdController = TextEditingController();
  String? _selectedType = 'monitor';

  @override
  void dispose() {
    _assetIdController.dispose();
    super.dispose();
  }

  void _generateAndDisplayQR() {
    if (_assetIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an asset ID')),
      );
      return;
    }

    final qrData = '${_selectedType?.toUpperCase()}-${_assetIdController.text}';
    QRDisplayHelper.showQRDialog(
      context,
      qrData: qrData,
      title: 'QR Code: $qrData',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final content = SingleChildScrollView(
      padding: r.insetsAll(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate QR Codes',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          SizedBox(height: r.dp(16)),
          // Asset Type Selection
          Text(
            'Asset Type',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          SizedBox(height: r.dp(6)),
          Container(
            padding: r.insetsSymmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderDark),
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.darkBg,
            ),
            child: DropdownButton<String>(
              value: _selectedType,
              onChanged: (value) {
                setState(() => _selectedType = value);
              },
              items: [
                DropdownMenuItem(
                  value: 'monitor',
                  child: Text(
                    'Monitor',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                DropdownMenuItem(
                  value: 'unit',
                  child: Text(
                    'System Unit',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppTheme.darkBg,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: r.sp(12),
                  ),
            ),
          ),
          SizedBox(height: r.dp(12)),
          // Asset ID Input
          Text(
            'Asset ID',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
          ),
          SizedBox(height: r.dp(6)),
          TextField(
            controller: _assetIdController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  r.insetsSymmetric(horizontal: 12, vertical: 10),
              hintText: 'Enter asset ID (e.g., HQ-001)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderDark),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderDark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.lavender600,
                  width: 2,
                ),
              ),
            ),
          ),
          SizedBox(height: r.dp(12)),
          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateAndDisplayQR,
              icon: Icon(Icons.qr_code_2, size: r.icon(16)),
              label: Text(
                'Generate QR Code',
                style: TextStyle(fontSize: r.sp(11)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lavender600,
                foregroundColor: Colors.white,
                minimumSize: Size(0, r.dp(34)),
                padding:
                    r.insetsSymmetric(vertical: 8, horizontal: 12),
              ),
            ),
          ),
          SizedBox(height: r.dp(16)),
          // Info Box
          Container(
            padding: r.insetsAll(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderDark),
              borderRadius: BorderRadius.circular(8),
              color: AppTheme.darkBg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About QR Codes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: r.sp(12),
                      ),
                ),
                SizedBox(height: r.dp(6)),
                Text(
                  'QR codes are used to quickly identify and track assets in the system. '
                  'Generate codes for new monitors or system units using this tool.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: r.sp(11),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('QR Code Generator'),
        centerTitle: false,
      ),
      body: content,
    );
  }
}
