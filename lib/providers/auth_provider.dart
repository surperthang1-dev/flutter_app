import 'package:flutter/material.dart';

import '../models/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;

  AuthUser? get user => _user;
  bool get isAdmin => _user?.isAdmin ?? false;

  void signIn(AuthUser user) {
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
    _user = null;
    notifyListeners();
  }
}

class AuthScope extends InheritedNotifier<AuthProvider> {
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
