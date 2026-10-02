// Defines bounded Firestore page results and cursor-based page fetching.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Carries one bounded query result, its cursor, and continuation state.
class FirestorePage<T> {
  /// Records contained in this page.
  final List<T> items;

  /// Cursor to pass to the next query, or `null` when this page is empty.
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  /// Whether the query may have more records after this page.
  final bool hasMore;

  /// Creates a page with mapped records, its last-document cursor, and continuation state.
  const FirestorePage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

/// Executes a bounded Firestore query and maps its documents.
class FirestorePageQuery<T> {
  /// Maximum number of records read in a page.
  final int pageSize;

  /// Query to execute, optionally continuing after [cursor].
  final Query<Map<String, dynamic>> query;

  /// Converts each Firestore document to the application's model.
  final T Function(QueryDocumentSnapshot<Map<String, dynamic>> document) map;

  /// Configures a Firestore query, document mapper, and maximum page size.
  const FirestorePageQuery({
    required this.query,
    required this.map,
    this.pageSize = 10,
  }) : assert(pageSize > 0);

  /// Executes the query with the page limit and optional document cursor.
  Future<FirestorePage<T>> load({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    final pageQuery = cursor == null
        ? query.limit(pageSize)
        : query.startAfterDocument(cursor).limit(pageSize);
    final snapshot = await pageQuery.get();
    return FirestorePage<T>(
      items: snapshot.docs.map(map).toList(growable: false),
      lastDocument: snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }
}
