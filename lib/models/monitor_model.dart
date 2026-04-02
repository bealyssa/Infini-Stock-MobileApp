class Monitor {
  final String id;
  final String deviceName;
  final String qrCode;
  final String status;
  final String? linkedUnit;
  final String? description;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Monitor({
    required this.id,
    required this.deviceName,
    required this.qrCode,
    required this.status,
    this.linkedUnit,
    this.description,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Monitor.fromJson(Map<String, dynamic> json) {
    // Handle linkedUnit which can be either a string ID or an object
    String? linkedUnitVal;
    if (json['linkedUnit'] != null) {
      if (json['linkedUnit'] is String) {
        linkedUnitVal = json['linkedUnit'] as String;
      } else if (json['linkedUnit'] is Map) {
        linkedUnitVal = (json['linkedUnit'] as Map)['id'] as String?;
      }
    }

    return Monitor(
      id: json['id'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      qrCode: json['qrCode'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      linkedUnit: linkedUnitVal,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'qrCode': qrCode,
      'status': status,
      'linkedUnit': linkedUnit,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == 'active';
  bool get isBroken => status == 'broken' || status == 'repair';
  bool get isInMaintenance => status == 'maintenance';
}
