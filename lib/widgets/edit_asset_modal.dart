import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class EditAssetModal extends StatefulWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onSaved;

  const EditAssetModal({
    required this.asset,
    required this.onSaved,
    Key? key,
  }) : super(key: key);

  @override
  State<EditAssetModal> createState() => _EditAssetModalState();
}

class _EditAssetModalState extends State<EditAssetModal> {
  late TextEditingController deviceNameController;
  late TextEditingController descriptionController;
  late TextEditingController notesController;
  late TextEditingController serialNumberController;
  late TextEditingController modelTypeController;
  
  String? selectedStatus;
  String? selectedCondition;
  String? selectedLocation;

  bool isLoading = false;
  String? error;

  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    deviceNameController = TextEditingController(
      text: widget.asset['deviceName'] ?? '',
    );
    descriptionController = TextEditingController(
      text: widget.asset['description'] ?? '',
    );
    notesController = TextEditingController(
      text: widget.asset['notes'] ?? '',
    );
    serialNumberController = TextEditingController(
      text: widget.asset['serialNumber'] ?? '',
    );
    modelTypeController = TextEditingController(
      text: widget.asset['modelType'] ?? '',
    );
    
    selectedStatus = widget.asset['status'];
    selectedCondition = widget.asset['condition'];
    selectedLocation = widget.asset['location'];
  }

  @override
  void dispose() {
    deviceNameController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    serialNumberController.dispose();
    modelTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveAsset() async {
    if (deviceNameController.text.isEmpty) {
      setState(() {
        error = 'Device name is required';
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final updateData = {
        'deviceName': deviceNameController.text.trim(),
        'description': descriptionController.text.trim(),
        'notes': notesController.text.trim(),
        'serialNumber': serialNumberController.text.trim(),
        'modelType': modelTypeController.text.trim(),
        if (selectedStatus != null) 'status': selectedStatus,
        if (selectedCondition != null) 'condition': selectedCondition,
        if (selectedLocation != null) 'location': selectedLocation,
      };

      final assetType = widget.asset['type'] ?? 'unit';
      final assetId = widget.asset['id'] ?? widget.asset['_id'];

      if (assetType == 'monitor') {
        await _apiClient.updateMonitor(assetId, updateData);
      } else {
        await _apiClient.updateUnit(assetId, updateData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset updated successfully')),
      );
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final media = MediaQuery.of(context);
    final compact = media.size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? r.dp(10) : r.dp(24),
        vertical: compact ? r.dp(10) : r.dp(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? media.size.width - r.dp(20) : r.dp(700),
          maxHeight: media.size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF211339),
            borderRadius: BorderRadius.circular(r.dp(18)),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.dp(18),
                  r.dp(16),
                  r.dp(12),
                  r.dp(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Asset',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderDark),
              LimitedBox(
                maxHeight: media.size.height * 0.65,
                child: SingleChildScrollView(
                  padding: r.insetsAll(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (error != null)
                        Container(
                          margin: EdgeInsets.only(bottom: r.dp(12)),
                          padding: r.insetsAll(12),
                          decoration: BoxDecoration(
                            color: AppTheme.statusError.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.statusError.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: AppTheme.statusError,
                              fontSize: r.sp(13),
                            ),
                          ),
                        ),
                      Text(
                        'Device Information',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: r.dp(12)),
                      TextField(
                        controller: deviceNameController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Device Name',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                      SizedBox(height: r.dp(12)),
                      TextField(
                        controller: serialNumberController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Serial Number',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                      SizedBox(height: r.dp(12)),
                      TextField(
                        controller: modelTypeController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Model Type',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                      SizedBox(height: r.dp(16)),
                      Text(
                        'Status & Condition',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: r.dp(12)),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text(
                              'Active',
                              style: TextStyle(
                                color: AppTheme.statusSuccess,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text(
                              'Inactive',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text(
                              'Maintenance',
                              style: TextStyle(
                                color: AppTheme.statusWarning,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedStatus = value);
                        },
                        dropdownColor: AppTheme.darkBg,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: r.sp(14),
                        ),
                      ),
                      SizedBox(height: r.dp(12)),
                      DropdownButtonFormField<String>(
                        value: selectedCondition,
                        decoration: InputDecoration(
                          labelText: 'Condition',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'good',
                            child: Text(
                              'Good',
                              style: TextStyle(
                                color: AppTheme.statusSuccess,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'fair',
                            child: Text(
                              'Fair',
                              style: TextStyle(
                                color: AppTheme.statusWarning,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'broken',
                            child: Text(
                              'Broken',
                              style: TextStyle(
                                color: AppTheme.statusError,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedCondition = value);
                        },
                        dropdownColor: AppTheme.darkBg,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: r.sp(14),
                        ),
                      ),
                      SizedBox(height: r.dp(12)),
                      TextField(
                        controller: selectedLocation != null
                            ? TextEditingController(text: selectedLocation)
                            : TextEditingController(),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        onChanged: (value) =>
                            selectedLocation = value.isEmpty ? null : value,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                      SizedBox(height: r.dp(16)),
                      Text(
                        'Additional Info',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: r.dp(12)),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Description',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                      SizedBox(height: r.dp(12)),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          filled: true,
                          fillColor: AppTheme.darkBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppTheme.borderDark,
                            ),
                          ),
                          labelStyle:
                              const TextStyle(color: AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.borderDark),
              Padding(
                padding: r.insetsAll(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: r.dp(10)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveAsset,
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppTheme.textPrimary,
                                  ),
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
