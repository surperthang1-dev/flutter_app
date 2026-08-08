class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
    this.address,
    this.addressDetail,
    this.addressNote,
    this.deliveryAreaId,
    this.deliveryAreaName,
  });

  factory AuthUser.fromColumnMap(Map<String, dynamic> data) {
    return AuthUser(
      id: data['id'].toString(),
      fullName: data['full_name'] as String,
      phone: data['phone'] as String,
      role: data['role'] as int? ?? 0,
      email: data['email'] as String?,
      address: data['address'] as String?,
      addressDetail:
          data['address_detail'] as String? ?? data['address'] as String?,
      addressNote: data['address_note'] as String?,
      deliveryAreaId: data['delivery_area_id'] as String?,
      deliveryAreaName: data['delivery_area_name'] as String?,
    );
  }

  final String id;
  final String fullName;
  final String phone;
  final int role;
  final String? email;
  final String? address;
  final String? addressDetail;
  final String? addressNote;
  final String? deliveryAreaId;
  final String? deliveryAreaName;

  bool get isAdmin => role == 1;

  String? get displayAddress {
    final detail = addressDetail?.trim().isNotEmpty == true
        ? addressDetail!.trim()
        : address?.trim();
    if (detail == null || detail.isEmpty) return null;
    final note = addressNote?.trim() ?? '';
    return note.isEmpty ? detail : '$detail ($note)';
  }
}
