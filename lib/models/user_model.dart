class User {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ??
          json['fullName'] as String? ??
          'Unknown',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'viewer',
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
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
      'full_name': fullName,
      'email': email,
      'role': role,
      'is_active': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isTechnician => role == 'technician';
}
