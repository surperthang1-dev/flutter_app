import '../config/database_config.dart';
import '../models/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostgresAuthRepository {
  const PostgresAuthRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<AuthUser> login({
    required String phone,
    required String password,
  }) async {
    throw const AuthException(
      'Bản Chrome/web không thể kết nối PostgreSQL trực tiếp. Hãy chạy app Windows/native để đăng nhập admin.',
    );
  }

  Future<AuthUser> register({
    required String fullName,
    required String phone,
    required String password,
    String? email,
    required String addressDetail,
    required String deliveryAreaId,
    String? addressNote,
  }) async {
    throw const AuthException(
      'Bản Chrome/web không thể tạo tài khoản trực tiếp với PostgreSQL. Hãy chạy app Windows/native.',
    );
  }

  Future<void> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    throw const AuthException(
      'Bản Chrome/web không thể đổi mật khẩu trực tiếp với PostgreSQL. Hãy chạy app Windows/native.',
    );
  }

  Future<AuthUser> updateProfile({
    required AuthUser user,
    required String fullName,
    required String phone,
    String? email,
    required String addressDetail,
    required String addressNote,
    required String deliveryAreaId,
    String currentPassword = '',
  }) {
    throw const AuthException(
      'Bản Chrome/web không thể cập nhật tài khoản trực tiếp với PostgreSQL. Hãy chạy app Windows/native.',
    );
  }

  Future<void> changePassword({
    required AuthUser user,
    required String currentPassword,
    required String newPassword,
  }) {
    throw const AuthException(
      'Bản Chrome/web không thể đổi mật khẩu trực tiếp với PostgreSQL. Hãy chạy app Windows/native.',
    );
  }
}
