// Provides opt-in diagnostics for connectivity to the configured Firebase services.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Runs bounded connectivity checks against the configured Realtime Database paths and Firestore collections.
Future<void> runFirebaseAccessDiagnostics() async {
  final tables = ['customers', 'pets', 'breeds', 'petTypes', 'serviceTypes'];

  debugPrint('--- Firebase access diagnostics ---');

  for (final table in tables) {
    final realtimeResult = await _checkRealtimeDatabaseTable(table);
    debugPrint('RTDB/$table -> $realtimeResult');

    final firestoreResult = await _checkFirestoreCollection(table);
    debugPrint('Firestore/$table -> $firestoreResult');
  }

  debugPrint('--- Firebase access diagnostics ended ---');
}

/// Attempts a read to verify access to the requested Realtime Database path.
Future<String> _checkRealtimeDatabaseTable(String table) async {
  try {
    final snapshot = await FirebaseDatabase.instance.ref(table).get();

    if (snapshot.exists) {
      final value = snapshot.value;

      if (value is Map) {
        return 'OK: table exists with ${value.length} item(s)';
      }

      return 'OK: table exists';
    }

    return 'NO DATA: path exists but no data found';
  } on FirebaseException catch (e) {
    return 'ERROR: ${e.code} - ${e.message ?? 'Realtime Database access failed'}';
  } catch (e) {
    return 'ERROR: $e';
  }
}

/// Attempts a read to verify access to the requested Firestore collection.
Future<String> _checkFirestoreCollection(String collection) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return 'OK: collection exists with ${snapshot.docs.length} document(s)';
    }

    return 'NO DATA: collection exists but no document found';
  } on FirebaseException catch (e) {
    return 'ERROR: ${e.code} - ${e.message ?? 'Firestore access failed'}';
  } catch (e) {
    return 'ERROR: $e';
  }
}
