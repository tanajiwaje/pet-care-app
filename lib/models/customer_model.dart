// Defines the typed customer record and its map serialization.

/// Represents a customer record and its contact details.
class CustomerModel {
  final String id;
  final String code;
  final String firstName;
  final String lastName;
  final String mobile;
  final String address;
  final bool isActive;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a customer record from its identity and contact fields.
  const CustomerModel({
    required this.id,
    this.code = '',
    required this.firstName,
    required this.lastName,
    required this.mobile,
    required this.address,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed customer model from its serialized fields.
  factory CustomerModel.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final updatedAtValue = map['updatedAt'];

    return CustomerModel(
      id: id,
      code: map['code'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      address: map['address'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: createdAtValue is int ? createdAtValue : null,
      updatedAt: updatedAtValue is int ? updatedAtValue : null,
    );
  }

  /// Serializes this customer model into a map.
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'code': code,
      'mobile': mobile,
      'address': address,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
