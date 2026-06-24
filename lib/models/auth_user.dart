class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
    this.address,
  });

  factory AuthUser.fromColumnMap(Map<String, dynamic> data) {
    return AuthUser(
      id: data['id'].toString(),
      fullName: data['full_name'] as String,
      phone: data['phone'] as String,
      role: data['role'] as int? ?? 0,
      email: data['email'] as String?,
      address: data['address'] as String?,
    );
  }

  final String id;
  final String fullName;
  final String phone;
  final int role;
  final String? email;
  final String? address;

  bool get isAdmin => role == 1;
}
