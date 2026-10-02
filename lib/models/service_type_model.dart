// Defines service-type data including default amount and active status.

/// Represents a service and its default price and active state.
class ServiceTypeModel {
  final String id;
  final String code;
  final String name;
  final num defaultAmount;
  final bool isActive;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a service record with its name, default amount, and active status.
  const ServiceTypeModel({
    required this.id,
    this.code = '',
    required this.name,
    required this.defaultAmount,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed service type model from its serialized fields.
  factory ServiceTypeModel.fromMap(String id, Map<String, dynamic> map) {
    return ServiceTypeModel(
      id: id,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      defaultAmount: map['defaultAmount'] as num? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _timestampValue(map['createdAt']),
      updatedAt: _timestampValue(map['updatedAt']),
    );
  }

  /// Serializes this service type model into a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'defaultAmount': defaultAmount,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Converts a numeric Firestore timestamp value to milliseconds since the epoch.
  static int? _timestampValue(Object? value) =>
      value is num ? value.toInt() : null;
}
