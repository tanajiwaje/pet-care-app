// Defines visit and billing data and normalizes its Firestore values.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer visit, selected service, and billed amount.
class VisitModel {
  final String id;
  final String code;
  final String customerId;
  final String petId;
  final String serviceTypeId;
  final double defaultAmount;
  final double actualAmount;
  final String notes;
  final DateTime visitDate;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a visit record with its customer, pet, service, date, and billed amount.
  const VisitModel({
    required this.id,
    this.code = '',
    required this.customerId,
    required this.petId,
    required this.serviceTypeId,
    required this.defaultAmount,
    required this.actualAmount,
    required this.notes,
    required this.visitDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed visit model from its serialized fields.
  factory VisitModel.fromMap(String id, Map<String, dynamic> map) {
    return VisitModel(
      id: id,
      code: map['code'] as String? ?? '',
      customerId: _referenceId(map['customerId']),
      petId: _referenceId(map['petId']),
      serviceTypeId: _referenceId(map['serviceTypeId']),
      defaultAmount: (map['defaultAmount'] as num?)?.toDouble() ?? 0,
      actualAmount: (map['actualAmount'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      visitDate: _dateTime(map['visitDate']),
      createdAt: _timestampValue(map['createdAt']),
      updatedAt: _timestampValue(map['updatedAt']),
    );
  }

  /// Extracts a linked document ID from a Firestore reference or stored string.
  static String _referenceId(Object? value) {
    if (value is DocumentReference) return value.id;
    if (value is String) return value;
    return '';
  }

  /// Converts a Firestore Timestamp or supported date value to a DateTime.
  static DateTime _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Converts a numeric Firestore timestamp value to milliseconds since the epoch.
  static int? _timestampValue(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    return null;
  }
}
