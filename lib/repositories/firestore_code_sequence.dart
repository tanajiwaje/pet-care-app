// Allocates unique sequential display codes using Firestore transactions.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Creates records with transactionally allocated display codes.
class FirestoreCodeSequence {
  final CollectionReference<Map<String, dynamic>> collection;
  final String prefix;

  /// Configures display-code allocation for a collection and code prefix.
  const FirestoreCodeSequence({required this.collection, required this.prefix});

  /// Returns the counter document used to allocate codes for this collection.
  DocumentReference<Map<String, dynamic>> get counterRef =>
      collection.firestore.collection('_counters').doc(collection.id);

  /// Allocates an unpersisted Firestore document reference in the collection.
  DocumentReference<Map<String, dynamic>> createDocumentRef() =>
      collection.doc();

  /// Reads existing codes only when no sequence counter exists, for migration safety.
  Future<int> highestExistingNumberIfCounterMissing() async {
    if ((await counterRef.get()).exists) return 0;
    final existingRecords = await collection.get();
    var highestExistingNumber = 0;
    for (final document in existingRecords.docs) {
      final existingNumber = _numberFromCode(document.data()['code']);
      if (existingNumber > highestExistingNumber) {
        highestExistingNumber = existingNumber;
      }
    }
    return highestExistingNumber;
  }

  /// Writes the coded record and advances its counter in the supplied transaction.
  void writeInTransaction(
    Transaction transaction, {
    required DocumentReference<Map<String, dynamic>> documentRef,
    required DocumentSnapshot<Map<String, dynamic>> counterSnapshot,
    required int highestExistingNumber,
    required Map<String, dynamic> data,
  }) {
    final lastNumber = counterSnapshot.data()?['lastNumber'];
    final currentNumber = lastNumber is num ? lastNumber.toInt() : 0;
    final nextNumber =
        (currentNumber > highestExistingNumber
            ? currentNumber
            : highestExistingNumber) +
        1;

    transaction.set(counterRef, {'lastNumber': nextNumber});
    transaction.set(documentRef, {...data, 'code': '$prefix-$nextNumber'});
  }

  /// Creates a record with the next sequential code in a Firestore transaction.
  Future<void> add(Map<String, dynamic> data) async {
    final highestExistingNumber = await highestExistingNumberIfCounterMissing();
    final documentRef = createDocumentRef();

    await collection.firestore.runTransaction((transaction) async {
      final counterSnapshot = await transaction.get(counterRef);
      writeInTransaction(
        transaction,
        documentRef: documentRef,
        counterSnapshot: counterSnapshot,
        highestExistingNumber: highestExistingNumber,
        data: data,
      );
    });
  }

  /// Pads an integer to the width required for a display code.
  int _numberFromCode(Object? value) {
    if (value is! String) return 0;
    final match = RegExp(
      '^${RegExp.escape(prefix)}-([0-9]+)\$',
    ).firstMatch(value);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
