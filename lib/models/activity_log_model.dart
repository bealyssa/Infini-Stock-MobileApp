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
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      assetQrCode: json['assetQrCode'] as String? ?? '',
      action: json['action'] as String? ?? 'unknown',
      oldLocation: json['oldLocation'] as String?,
      newLocation: json['newLocation'] as String?,
      oldStatus: json['oldStatus'] as String?,
      newStatus: json['newStatus'] as String?,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
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
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get displayAction {
    switch (action.toLowerCase()) {
      case 'move':
        return '📍 Moved';
      case 'swap':
        return '🔄 Swapped';
      case 'repair':
        return '🔧 Repair';
      case 'update':
        return '✏️ Updated';
      default:
        return '📝 ${action[0].toUpperCase()}${action.substring(1)}';
    }
  }

  String get displayDetails {
    if (oldStatus != null && newStatus != null) {
      return '$oldStatus → $newStatus';
    }
    if (newLocation != null) {
      return 'Moved to $newLocation';
    }
    return 'No details';
  }
}
