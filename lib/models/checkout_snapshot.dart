import 'delivery_area.dart';

class CheckoutSnapshot {
  const CheckoutSnapshot({
    required this.fullName,
    required this.phone,
    required this.addressDetail,
    required this.addressNote,
    required this.deliveryArea,
  });

  final String fullName;
  final String phone;
  final String addressDetail;
  final String? addressNote;
  final DeliveryArea deliveryArea;

  String get deliveryAddress {
    final note = addressNote?.trim() ?? '';
    return note.isEmpty ? addressDetail : '$addressDetail ($note)';
  }
}
