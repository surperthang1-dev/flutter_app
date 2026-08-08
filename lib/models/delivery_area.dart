class DeliveryArea {
  const DeliveryArea({
    required this.id,
    required this.name,
    required this.shippingFee,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryArea.fromColumnMap(Map<String, dynamic> data) {
    return DeliveryArea(
      id: data['id'] as String,
      name: data['name'] as String,
      shippingFee: (data['shipping_fee'] as num).toInt(),
      isActive: data['is_active'] as bool,
      createdAt: data['created_at'] as DateTime?,
      updatedAt: data['updated_at'] as DateTime?,
    );
  }

  final String id;
  final String name;
  final int shippingFee;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryArea copyWith({
    String? name,
    int? shippingFee,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return DeliveryArea(
      id: id,
      name: name ?? this.name,
      shippingFee: shippingFee ?? this.shippingFee,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
