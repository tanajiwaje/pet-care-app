// Tests activity logging, failed-operation logging, and log retention.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_care_app/services/audit_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers tests for audit-log persistence, errors, and retention.
void main() {
  const storageKey = 'pet_care_audit_logs_v1';
  final service = AuditLogService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records successful changes and failed operations locally', () async {
    await service.track<void>(
      entity: 'Customer',
      action: 'create',
      operation: () async {},
    );

    await expectLater(
      service.track<void>(
        entity: 'Visit',
        action: 'update',
        recordId: 'visit-1',
        operation: () async => throw StateError('write failed'),
      ),
      throwsA(isA<StateError>()),
    );

    final entries = await service.getEntries();
    expect(entries, hasLength(2));
    expect(entries.first.category, 'error');
    expect(entries.first.recordId, 'visit-1');
    expect(entries.last.category, 'activity');
    expect(entries.last.message, 'Customer created');
  });

  test('removes entries older than one calendar month', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(storageKey, [
      jsonEncode({
        'timestamp': DateTime(2020).toIso8601String(),
        'category': 'activity',
        'entity': 'Customer',
        'action': 'create',
        'message': 'Customer created',
      }),
      jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'category': 'activity',
        'entity': 'Pet',
        'action': 'create',
        'message': 'Pet created',
      }),
    ]);

    final entries = await service.getEntries();

    expect(entries, hasLength(1));
    expect(entries.single.entity, 'Pet');
    expect(preferences.getStringList(storageKey), hasLength(1));
  });
}
