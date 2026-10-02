// Implements Firestore reminder queries, pagination, and reminder mutations.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reminder_model.dart';
import '../services/audit_log_service.dart';
import 'firestore_code_sequence.dart';
import 'firestore_page.dart';

/// Implements Firestore data access for reminder records.
class FirestoreReminderRepository {
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _reminders;
  late final FirestoreCodeSequence _codes;

  /// Creates a reminder repository using the supplied or default Firestore instance.
  FirestoreReminderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _reminders = _firestore.collection('reminders');
    _codes = FirestoreCodeSequence(collection: _reminders, prefix: 'REM');
  }

  /// Subscribes to Firestore changes for reminders and maps snapshots to typed records.
  Stream<List<ReminderModel>> watchReminders() {
    return _reminders.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
    );
  }

  /// Streams reminders scheduled within the supplied half-open date range.
  Stream<List<ReminderModel>> watchRemindersInRange({
    required DateTime start,
    required DateTime end,
  }) {
    return _reminders
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReminderModel.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Retrieves one reminder by ID when handling a notification outside the
  /// Loads one reminder by ID, returning `null` when the document no longer exists.
  Future<ReminderModel?> getReminder(String id) async {
    final snapshot = await _reminders.doc(id).get();
    final data = snapshot.data();
    return snapshot.exists && data != null
        ? ReminderModel.fromMap(snapshot.id, data)
        : null;
  }

  /// Loads at most ten reminders in appointment order after [cursor].
  Future<FirestorePage<ReminderModel>> fetchReminderPage({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    return FirestorePageQuery<ReminderModel>(
      query: _reminders.orderBy('scheduledAt'),
      map: (doc) => ReminderModel.fromMap(doc.id, doc.data()),
    ).load(cursor: cursor);
  }

  /// Creates a reminder with its scheduled notification time and generated display code.
  Future<String> addReminder({
    required String customerId,
    required DateTime scheduledAt,
  }) async {
    final highestExistingNumber = await _codes
        .highestExistingNumberIfCounterMissing();
    final reminderRef = _codes.createDocumentRef();
    final now = DateTime.now().millisecondsSinceEpoch;

    await AuditLogService.instance.track(
      entity: 'Reminder',
      action: 'create',
      recordId: reminderRef.id,
      operation: () => _firestore.runTransaction((transaction) async {
        final counter = await transaction.get(_codes.counterRef);
        _codes.writeInTransaction(
          transaction,
          documentRef: reminderRef,
          counterSnapshot: counter,
          highestExistingNumber: highestExistingNumber,
          data: {
            'customerId': _firestore.collection('customers').doc(customerId),
            'scheduledAt': Timestamp.fromDate(scheduledAt),
            'notifyAt': Timestamp.fromDate(
              scheduledAt.subtract(const Duration(hours: 1)),
            ),
            'status': 'scheduled',
            'createdAt': now,
            'updatedAt': now,
          },
        );
      }),
    );
    return reminderRef.id;
  }

  /// Updates the selected reminder record with the supplied values.
  Future<void> updateReminder({
    required String id,
    required String customerId,
    required DateTime scheduledAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await AuditLogService.instance.track(
      entity: 'Reminder',
      action: 'update',
      recordId: id,
      operation: () => _reminders.doc(id).update({
        'customerId': _firestore.collection('customers').doc(customerId),
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'notifyAt': Timestamp.fromDate(
          scheduledAt.subtract(const Duration(hours: 1)),
        ),
        'status': 'scheduled',
        'updatedAt': now,
      }),
    );
  }

  /// Updates a reminder's notification time and marks it as snoozed.
  Future<void> snoozeReminder({
    required String id,
    required DateTime notifyAt,
  }) async {
    await AuditLogService.instance.track(
      entity: 'Reminder',
      action: 'snooze',
      recordId: id,
      operation: () => _reminders.doc(id).update({
        'notifyAt': Timestamp.fromDate(notifyAt),
        'status': 'snoozed',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Marks a reminder as stopped so it is no longer treated as scheduled.
  Future<void> stopReminder(String id) async {
    await AuditLogService.instance.track(
      entity: 'Reminder',
      action: 'stop',
      recordId: id,
      operation: () => _reminders.doc(id).update({
        'status': 'stopped',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Deletes the selected reminder record and records the operation result.
  Future<void> deleteReminder(String id) => AuditLogService.instance.track(
    entity: 'Reminder',
    action: 'delete',
    recordId: id,
    operation: () => _reminders.doc(id).delete(),
  );
}
