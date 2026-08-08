class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.orderCount,
    required this.createdAt,
    this.email,
    this.deliveryAreaName,
    this.updatedAt,
  });

  factory AdminAccount.fromColumnMap(Map<String, dynamic> data) {
    return AdminAccount(
      id: data['id'].toString(),
      fullName: data['full_name'] as String,
      phone: data['phone'] as String,
      email: data['email'] as String?,
      role: (data['role'] as num).toInt(),
      isActive: data['is_active'] as bool,
      deliveryAreaName: data['delivery_area_name'] as String?,
      orderCount: (data['order_count'] as num).toInt(),
      createdAt: data['created_at'] as DateTime,
      updatedAt: data['updated_at'] as DateTime?,
    );
  }

  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final int role;
  final bool isActive;
  final String? deliveryAreaName;
  final int orderCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == 1;
}
