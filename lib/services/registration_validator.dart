class RegistrationValidator {
  const RegistrationValidator._();

  static String? fullName(String? value) {
    if ((value?.trim() ?? '').length < 2) {
      return 'Vui lòng nhập họ và tên.';
    }
    return null;
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(phone)) {
      return 'Số điện thoại chưa đúng định dạng.';
    }
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 6) {
      return 'Mật khẩu cần ít nhất 6 ký tự.';
    }
    return null;
  }

  static String? confirmation({required String password, String? value}) {
    if (value != password) {
      return 'Mật khẩu xác nhận chưa khớp.';
    }
    return null;
  }

  static String? addressDetail(String? value) {
    if ((value?.trim() ?? '').isEmpty) {
      return 'Vui lòng nhập số nhà và tên đường.';
    }
    return null;
  }

  static String? deliveryAreaId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng chọn khu vực giao hàng.';
    }
    return null;
  }
}
