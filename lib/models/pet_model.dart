// Defines pet data and its Firestore map representation.

/// Represents a pet and its customer, type, and breed references.
class PetModel {
  final String id;
  final String code;
  final String customerId;
  final String petTypeId;
  final String breedId;
  final bool gender;
  final bool isActive;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a pet record with its customer, pet type, breed, and profile details.
  const PetModel({
    required this.id,
    this.code = '',
    required this.customerId,
    required this.petTypeId,
    required this.breedId,
    required this.gender,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed pet model from its serialized fields.
  factory PetModel.fromMap(String id, Map<String, dynamic> map) {
    return PetModel(
      id: id,
      code: map['code'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      petTypeId: map['petTypeId'] as String? ?? '',
      breedId: map['breedId'] as String? ?? '',
      gender: map['gender'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _timestampValue(map['createdAt']),
      updatedAt: _timestampValue(map['updatedAt']),
    );
  }

  /// Serializes this pet model into a map.
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'code': code,
      'petTypeId': petTypeId,
      'breedId': breedId,
      'gender': gender,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Converts a numeric Firestore timestamp value to milliseconds since the epoch.
  static int? _timestampValue(Object? value) =>
      value is num ? value.toInt() : null;
}
