enum DiscountType { fixed, percentage }

extension DiscountTypeX on DiscountType {
  String get databaseValue => name;

  String get label => switch (this) {
    DiscountType.fixed => 'Giảm tiền mặt',
    DiscountType.percentage => 'Giảm phần trăm',
  };

  static DiscountType fromDatabase(String value) {
    return value == DiscountType.percentage.name
        ? DiscountType.percentage
        : DiscountType.fixed;
  }
}

class DiscountCode {
  const DiscountCode({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.discountValue,
    required this.minimumOrderValue,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.usedCount,
    this.maximumDiscount,
    this.usageLimit,
    this.createdAt,
    this.updatedAt,
  });

  factory DiscountCode.fromColumnMap(Map<String, dynamic> data) {
    return DiscountCode(
      id: data['id'] as String,
      code: data['code'] as String,
      description: (data['description'] as String?) ?? '',
      type: DiscountTypeX.fromDatabase(data['discount_type'] as String),
      discountValue: (data['discount_value'] as num).toInt(),
      minimumOrderValue: (data['minimum_order_value'] as num).toInt(),
      maximumDiscount: (data['maximum_discount'] as num?)?.toInt(),
      usageLimit: (data['usage_limit'] as num?)?.toInt(),
      usedCount: (data['used_count'] as num).toInt(),
      startAt: data['start_at'] as DateTime,
      endAt: data['end_at'] as DateTime,
      isActive: data['is_active'] as bool,
      createdAt: data['created_at'] as DateTime?,
      updatedAt: data['updated_at'] as DateTime?,
    );
  }

  final String id;
  final String code;
  final String description;
  final DiscountType type;
  final int discountValue;
  final int minimumOrderValue;
  final int? maximumDiscount;
  final int? usageLimit;
  final int usedCount;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isUsageAvailable => usageLimit == null || usedCount < usageLimit!;

  bool isAvailableFor({required int subtotal, DateTime? at}) {
    final now = at ?? DateTime.now();
    return isActive &&
        !now.isBefore(startAt) &&
        !now.isAfter(endAt) &&
        subtotal >= minimumOrderValue &&
        isUsageAvailable;
  }

  int calculateDiscount(int subtotal) {
    if (subtotal <= 0) return 0;
    final raw = switch (type) {
      DiscountType.fixed => discountValue,
      DiscountType.percentage => (subtotal * discountValue) ~/ 100,
    };
    final capped = maximumDiscount == null
        ? raw
        : raw.clamp(0, maximumDiscount!).toInt();
    return capped.clamp(0, subtotal).toInt();
  }
}

class AppliedDiscount {
  const AppliedDiscount({required this.discount, required this.amount});

  final DiscountCode discount;
  final int amount;
}
