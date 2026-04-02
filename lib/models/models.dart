class Monitor {
  final String id;
  final String deviceName;
  final String qrCode;
  final String status; // active, maintenance, inactive
  final String? linkedUnit;
  final String? description;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Monitor({
    required this.id,
    required this.deviceName,
    required this.qrCode,
    required this.status,
    this.linkedUnit,
    this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Monitor.fromJson(Map<String, dynamic> json) {
    return Monitor(
      id: json['id'] ?? '',
      deviceName: json['deviceName'] ?? '',
      qrCode: json['qrCode'] ?? '',
      status: json['status'] ?? 'active',
      linkedUnit: json['linkedUnit'],
      description: json['description'],
      createdBy: json['createdBy'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceName': deviceName,
    'qrCode': qrCode,
    'status': status,
    'linkedUnit': linkedUnit,
    'description': description,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class SystemUnit {
  final String id;
  final String deviceName;
  final String qrCode;
  final String status; // active, maintenance, inactive
  final String location;
  final String? description;
  final String? linkedMonitor;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemUnit({
    required this.id,
    required this.deviceName,
    required this.qrCode,
    required this.status,
    required this.location,
    this.description,
    this.linkedMonitor,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SystemUnit.fromJson(Map<String, dynamic> json) {
    return SystemUnit(
      id: json['id'] ?? '',
      deviceName: json['deviceName'] ?? '',
      qrCode: json['qrCode'] ?? '',
      status: json['status'] ?? 'active',
      location: json['location'] ?? '',
      description: json['description'],
      linkedMonitor: json['linkedMonitor'],
      createdBy: json['createdBy'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceName': deviceName,
    'qrCode': qrCode,
    'status': status,
    'location': location,
    'description': description,
    'linkedMonitor': linkedMonitor,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class ActivityLog {
  final String id;
  final String action; // move, update, repair, swap
  final String assetId;
  final String assetQrCode;
  final String? oldLocation;
  final String? newLocation;
  final String? oldStatus;
  final String? newStatus;
  final String userId;
  final String timestamp;

  ActivityLog({
    required this.id,
    required this.action,
    required this.assetId,
    required this.assetQrCode,
    this.oldLocation,
    this.newLocation,
    this.oldStatus,
    this.newStatus,
    required this.userId,
    required this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      assetId: json['assetId'] ?? '',
      assetQrCode: json['assetQrCode'] ?? '',
      oldLocation: json['oldLocation'],
      newLocation: json['newLocation'],
      oldStatus: json['oldStatus'],
      newStatus: json['newStatus'],
      userId: json['userId'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'assetId': assetId,
    'assetQrCode': assetQrCode,
    'oldLocation': oldLocation,
    'newLocation': newLocation,
    'oldStatus': oldStatus,
    'newStatus': newStatus,
    'userId': userId,
    'timestamp': timestamp,
  };
}

class User {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'staff',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'role': role,
    'is_active': isActive,
    'createdAt': createdAt.toIso8601String(),
  };
}
