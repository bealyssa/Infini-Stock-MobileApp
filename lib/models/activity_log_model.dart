class ActivityLog {
  final String id;
  final String assetId;
  final String assetQrCode;
  final String action;
  final String? oldLocation;
  final String? newLocation;
  final String? oldStatus;
  final String? newStatus;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? itemName;
  final String? itemQr;
  final String? deletedItemName;
  final String? deletedItemQr;
  final String? description;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.assetId,
    required this.assetQrCode,
    required this.action,
    this.oldLocation,
    this.newLocation,
    this.oldStatus,
    this.newStatus,
    this.userId,
    this.userName,
    this.userEmail,
    this.itemName,
    this.itemQr,
    this.deletedItemName,
    this.deletedItemQr,
    this.description,
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    String? pickString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    Map<String, dynamic>? userMap;
    if (json['user'] is Map) {
      userMap = Map<String, dynamic>.from(json['user'] as Map);
    }

    return ActivityLog(
      id: json['id'] as String? ?? '',
      assetId: (json['assetId'] as String?) ?? (json['asset_id'] as String?) ?? '',
      assetQrCode: (json['assetQrCode'] as String?) ?? (json['asset_qr_code'] as String?) ?? '',
      action: json['action'] as String? ?? 'unknown',
      oldLocation: json['oldLocation'] as String?,
      newLocation: json['newLocation'] as String?,
      oldStatus: json['oldStatus'] as String?,
      newStatus: json['newStatus'] as String?,
      userId: (json['userId'] as String?) ?? (json['user_id'] as String?),
      userName: pickString(json['userName']) ??
          pickString(json['user_name']) ??
          pickString(json['updatedBy']) ??
          pickString(userMap?['fullName']) ??
          pickString(userMap?['full_name']) ??
          pickString(userMap?['name']),
      userEmail: pickString(json['userEmail']) ??
          pickString(json['user_email']) ??
          pickString(userMap?['email']),
        itemName: pickString(json['itemName']) ?? pickString(json['item_name']),
        itemQr: pickString(json['itemQr']) ?? pickString(json['item_qr']),
        deletedItemName: pickString(json['deletedItemName']) ??
          pickString(json['deleted_item_name']),
        deletedItemQr: pickString(json['deletedItemQr']) ??
          pickString(json['deleted_item_qr']),
      description: json['description'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetId': assetId,
      'assetQrCode': assetQrCode,
      'action': action,
      'oldLocation': oldLocation,
      'newLocation': newLocation,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'itemName': itemName,
      'itemQr': itemQr,
      'deletedItemName': deletedItemName,
      'deletedItemQr': deletedItemQr,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get updaterDisplayName {
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = userEmail?.trim();
    if (email != null && email.isNotEmpty) return email;

    final idVal = userId?.trim();
    if (idVal != null && idVal.isNotEmpty) return idVal;

    return 'System';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return 'Unknown';
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  String get displayAction {
    return _capitalize(action);
  }

  String get displayDetails {
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      return desc;
    }

    if (oldStatus != null && newStatus != null) {
      return 'Status: $oldStatus -> $newStatus';
    }

    if (oldLocation != null && newLocation != null) {
      return 'Location: $oldLocation -> $newLocation';
    }

    if (newStatus != null && newStatus!.trim().isNotEmpty) {
      return 'Status: $newStatus';
    }

    if (newLocation != null && newLocation!.trim().isNotEmpty) {
      return 'Location: $newLocation';
    }

    return 'No details';
  }
}
