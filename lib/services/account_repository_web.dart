import '../config/database_config.dart';
import '../models/admin_account.dart';

class AccountRepository {
  const AccountRepository({this.config = DatabaseConfig.local});

  final DatabaseConfig config;

  Future<List<AdminAccount>> fetchAccounts() => throw _error();
  Future<void> setAccountActive({
    required String actorId,
    required String accountId,
    required bool isActive,
  }) => throw _error();

  UnsupportedError _error() => UnsupportedError(
    'Bản Chrome/web không thể quản trị PostgreSQL trực tiếp. Hãy chạy app Windows/native.',
  );
}

class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}
