class Unit {
  final String id;
  final String deviceName;
  final String qrCode;
  final String status;
  final String? location;
  final String? linkedMonitor;
  final String? description;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Unit({
    required this.id,
    required this.deviceName,
    required this.qrCode,
    required this.status,
    this.location,
    this.linkedMonitor,
    this.description,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      qrCode: json['qrCode'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      location: json['location'] as String?,
      linkedMonitor: json['linkedMonitor'] as String?,
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
      'location': location,
      'linkedMonitor': linkedMonitor,
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
