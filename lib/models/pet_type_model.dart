// Defines pet-type data and its Firestore map representation.

/// Represents a supported pet type.
class PetTypeModel {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a pet-type record with its name, status, and timestamps.
  const PetTypeModel({
    required this.id,
    this.code = '',
    required this.name,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed pet type model from its serialized fields.
  factory PetTypeModel.fromMap(String id, Map<String, dynamic> map) {
    return PetTypeModel(
      id: id,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _timestampValue(map['createdAt']),
      updatedAt: _timestampValue(map['updatedAt']),
    );
  }

  /// Serializes this pet type model into a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Converts a numeric Firestore timestamp value to milliseconds since the epoch.
  static int? _timestampValue(Object? value) =>
      value is num ? value.toInt() : null;
}
