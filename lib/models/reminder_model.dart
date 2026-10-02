// Defines reminder data and normalizes Firestore references and scheduled dates.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a scheduled reminder and its notification state.
class ReminderModel {
  final String id;
  final String code;
  final String customerId;
  final DateTime scheduledAt;
  final DateTime notifyAt;
  final String status;
  final int? createdAt;
  final int? updatedAt;

  /// Creates a reminder with its customer, scheduled time, and notification state.
  const ReminderModel({
    required this.id,
    required this.code,
    required this.customerId,
    required this.scheduledAt,
    required this.notifyAt,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a typed reminder model from its serialized fields.
  factory ReminderModel.fromMap(String id, Map<String, dynamic> map) {
    final scheduledAt = _dateTime(map['scheduledAt']);
    return ReminderModel(
      id: id,
      code: map['code'] as String? ?? '',
      customerId: _referenceId(map['customerId']),
      scheduledAt: scheduledAt,
      notifyAt: map['notifyAt'] == null
          ? scheduledAt.subtract(const Duration(hours: 1))
          : _dateTime(map['notifyAt']),
      status: map['status'] as String? ?? 'scheduled',
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
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Converts a numeric Firestore timestamp value to milliseconds since the epoch.
  static int? _timestampValue(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    return null;
  }
}
