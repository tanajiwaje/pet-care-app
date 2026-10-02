// Maintains incremental page state for scrollable Firestore-backed lists.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_page.dart';

/// Defines the observable state contract for paginated screens.
abstract class FirestorePageControllerState extends ChangeNotifier {
  /// Number of records already fetched.
  int get itemCount;

  /// Whether another page may be available.
  bool get hasMore;

  /// Whether a page query is currently in progress.
  bool get isLoading;

  /// Most recent page-loading error.
  Object? get error;

  /// Fetches the next cursor page and appends records without overlapping another request.
  Future<void> loadMore();

  /// Resets the cursor and replaces loaded records with the first query page.
  Future<void> refresh();
}

/// Accumulates cursor-paginated results and exposes loading and error state.
class FirestorePageController<T> extends FirestorePageControllerState {
  /// Fetches the next page for an optional Firestore document cursor.
  final Future<FirestorePage<T>> Function({
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  })
  fetchPage;

  /// Records fetched so far, in query order.
  final List<T> items = [];

  /// Returns the number of records currently available to the list.
  @override
  int get itemCount => items.length;

  /// Cursor to pass to the next page query.
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  /// Whether another page may be available.
  @override
  bool hasMore = true;

  /// Whether a page query is currently in progress.
  @override
  bool isLoading = false;

  /// Most recent page-loading error, displayed by the owning screen.
  @override
  Object? error;

  /// Creates a pagination controller for a Firestore query.
  FirestorePageController({required this.fetchPage});

  /// Loads the next page once, appending new items on success.
  /// Fetches the next cursor page and appends records without overlapping another request.
  @override
  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final page = await fetchPage(cursor: _cursor);
      _cursor = page.lastDocument;
      items.addAll(page.items);
      hasMore = page.hasMore;
    } catch (loadError) {
      error = loadError;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Restarts the query and replaces loaded items with the first page.
  /// Resets the cursor and replaces loaded records with the first query page.
  @override
  Future<void> refresh() async {
    if (isLoading) return;
    _cursor = null;
    hasMore = true;
    items.clear();
    await loadMore();
  }
}
