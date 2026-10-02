// Defines payment data and normalizes Firestore references and dates.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment associated with a customer and visit.
class PaymentModel {
  final String id;
  final String code;
  final double amount;
  final String customerId;
  final String visitId;
  final String notes;
  final DateTime paymentDate;
  final String paymentMode;
  final String referenceNo;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a payment record with its customer, visit, amount, and payment details.
  const PaymentModel({
    required this.id,
    this.code = '',
    required this.amount,
    required this.customerId,
    required this.visitId,
    required this.notes,
    required this.paymentDate,
    required this.paymentMode,
    required this.referenceNo,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed payment model from its serialized fields.
  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      code: map['code'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      customerId: _referenceId(map['customerId']),
      visitId: _referenceId(map['visitId']),
      notes: map['notes'] as String? ?? '',
      paymentDate: _dateTime(map['paymentDate']),
      paymentMode: map['paymentMode'] as String? ?? '',
      referenceNo: map['referenceNo'] as String? ?? '',
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
