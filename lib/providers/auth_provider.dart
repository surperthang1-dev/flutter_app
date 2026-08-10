import 'package:flutter/material.dart';

import '../models/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  // Lưu phiên người dùng trong bộ nhớ để các màn hình phân quyền và lấy hồ sơ.
  AuthUser? _user;

  AuthUser? get user => _user;
  bool get isAdmin => _user?.isAdmin ?? false;

  void signIn(AuthUser user) {
    // Phát thông báo để màn Menu, đơn hàng và tài khoản cập nhật theo user mới.
    _user = user;
    notifyListeners();
  }

  /// Replaces the in-memory session after the customer updates their profile.
  /// Keeping this in one place prevents checkout and the account header from
  /// showing stale contact or delivery information.
  void updateUser(AuthUser user) {
    _user = user;
    notifyListeners();
  }

  void signOut() {
    // Xóa phiên hiện tại trước khi điều hướng về màn đăng nhập.
    _user = null;
    notifyListeners();
  }
}

class AuthScope extends InheritedNotifier<AuthProvider> {
  // Cung cấp AuthProvider cho toàn bộ widget tree mà không cần truyền tham số.
  const AuthScope({
    super.key,
    required AuthProvider super.notifier,
    required super.child,
  });

  static AuthProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope không tồn tại trong widget tree.');
    return scope!.notifier!;
  }
}
