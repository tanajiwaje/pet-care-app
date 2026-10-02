// Stores local activity and error history with serialized writes and time-based retention.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents one local activity or application-error log entry.
class AuditLogEntry {
  final DateTime timestamp;
  final String category;
  final String entity;
  final String action;
  final String message;
  final String? recordId;
  final String? error;
  final String? stackTrace;

  /// Creates a timestamped activity or error record with optional diagnostic details.
  const AuditLogEntry({
    required this.timestamp,
    required this.category,
    required this.entity,
    required this.action,
    required this.message,
    this.recordId,
    this.error,
    this.stackTrace,
  });

  /// Creates a typed audit log entry from its serialized fields.
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String,
      entity: json['entity'] as String,
      action: json['action'] as String,
      message: json['message'] as String,
      recordId: json['recordId'] as String?,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  /// Serializes this audit log entry into a map.
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'category': category,
    'entity': entity,
    'action': action,
    'message': message,
    if (recordId != null) 'recordId': recordId,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };
}

/// Serializes local audit writes, retrieval, cleanup, and retention.
class AuditLogService {
  AuditLogService._();

  static final AuditLogService instance = AuditLogService._();
  static const _storageKey = 'pet_care_audit_logs_v1';

  static Future<void> _writeQueue = Future<void>.value();

  Future<T> track<T>({
    required String entity,
    required String action,
    required Future<T> Function() operation,
    String? recordId,
  }) async {
    late final T result;
    try {
      result = await operation();
    } catch (error, stackTrace) {
      await _recordSafely(
        AuditLogEntry(
          timestamp: DateTime.now(),
          category: 'error',
          entity: entity,
          action: action,
          message: '$entity $action failed',
          recordId: recordId,
          error: error.toString(),
          stackTrace: stackTrace.toString(),
        ),
      );
      rethrow;
    }

    await _recordSafely(
      AuditLogEntry(
        timestamp: DateTime.now(),
        category: 'activity',
        entity: entity,
        action: action,
        message: '$entity ${_pastTense(action)}',
        recordId: recordId,
      ),
    );
    return result;
  }

  /// Persists an application or operation error with its stack trace.
  Future<void> recordError({
    required String entity,
    required String message,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    await _recordSafely(
      AuditLogEntry(
        timestamp: DateTime.now(),
        category: 'error',
        entity: entity,
        action: 'error',
        message: message,
        error: error.toString(),
        stackTrace: stackTrace.toString(),
      ),
    );
  }

  /// Applies the one-month retention policy to locally stored entries.
  Future<void> pruneExpiredEntries() async {
    try {
      await getEntries();
    } catch (error, stackTrace) {
      debugPrint('Could not prune local activity logs: $error\n$stackTrace');
    }
  }

  /// Returns newest-first entries and removes records outside the retention window.
  Future<List<AuditLogEntry>> getEntries() async {
    final result = <AuditLogEntry>[];
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final encodedEntries = preferences.getStringList(_storageKey) ?? [];
      final cutoff = _retentionCutoff(DateTime.now());
      var removedExpiredEntries = false;

      for (final encodedEntry in encodedEntries) {
        final entry = AuditLogEntry.fromJson(
          jsonDecode(encodedEntry) as Map<String, dynamic>,
        );
        if (entry.timestamp.isAfter(cutoff)) {
          result.add(entry);
        } else {
          removedExpiredEntries = true;
        }
      }

      if (removedExpiredEntries) {
        await _saveEntries(preferences, result);
      }
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
    _writeQueue = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Could not load local activity logs: $error\n$stackTrace');
    });
    await operation;
    return result;
  }

  /// Removes every persisted activity and error entry from local storage.
  Future<void> clear() async {
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setStringList(_storageKey, []);
      if (!saved) throw StateError('Could not clear local activity logs.');
    });
    _writeQueue = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Could not clear local activity logs: $error\n$stackTrace');
    });
    await operation;
  }

  /// Serializes an audit-entry write and reports local-storage failures.
  Future<void> _recordSafely(AuditLogEntry entry) async {
    final operation = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final encodedEntries = preferences.getStringList(_storageKey) ?? [];
      final cutoff = _retentionCutoff(DateTime.now());
      final entries =
          encodedEntries
              .map(
                (encoded) => AuditLogEntry.fromJson(
                  jsonDecode(encoded) as Map<String, dynamic>,
                ),
              )
              .where((existing) => existing.timestamp.isAfter(cutoff))
              .toList()
            ..add(entry);
      await _saveEntries(preferences, entries);
    });
    _writeQueue = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Could not save local activity log: $error\n$stackTrace');
    });
    await _writeQueue;
  }

  /// Replaces the locally stored log list and throws if persistence fails.
  Future<void> _saveEntries(
    SharedPreferences preferences,
    List<AuditLogEntry> entries,
  ) async {
    final saved = await preferences.setStringList(
      _storageKey,
      entries.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    if (!saved) throw StateError('Could not save local activity logs.');
  }

  /// Calculates the time boundary used to expire old audit entries.
  DateTime _retentionCutoff(DateTime now) {
    final previousMonthLastDay = DateTime(now.year, now.month, 0).day;
    final day = math.min(now.day, previousMonthLastDay);
    return DateTime(
      now.year,
      now.month - 1,
      day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  /// Converts an audit action into its past-tense activity label.
  String _pastTense(String action) => switch (action) {
    'create' => 'created',
    'update' => 'updated',
    'delete' => 'deleted',
    'add' => 'added',
    'snooze' => 'snoozed',
    'stop' => 'stopped',
    _ => action,
  };
}
