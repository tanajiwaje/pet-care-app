// Defines the typed breed record and its Firestore field conversion.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a breed record stored in Firestore.
class BreedModel {
  final String id;
  final String code;
  final String petTypeId;
  final String name;
  final bool isActive;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a breed using its Firestore ID, pet type, name, and status.
  const BreedModel({
    required this.id,
    this.code = '',
    required this.petTypeId,
    required this.name,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed breed model from its serialized fields.
  factory BreedModel.fromMap(String id, Map<String, dynamic> map) {
    return BreedModel(
      id: id,
      code: map['code'] as String? ?? '',
      petTypeId: _petTypeIdValue(map['petTypeId']),
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _timestampValue(map['createdAt']),
      updatedAt: _timestampValue(map['updatedAt']),
    );
  }

  /// Serializes this breed model into a map.
  Map<String, dynamic> toMap() {
    return {
      'petTypeId': petTypeId,
      'code': code,
      'name': name,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Normalizes a pet-type reference stored as either a document reference or string ID.
  static String _petTypeIdValue(Object? value) {
    if (value is String) return value;
    if (value is DocumentReference) return value.id;
    return '';
  }

  /// Converts a numeric Firestore timestamp value to milliseconds since the epoch.
  static int? _timestampValue(Object? value) =>
      value is num ? value.toInt() : null;
}
