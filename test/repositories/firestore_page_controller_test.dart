// Tests bounded page loading, duplicate-request prevention, and pagination errors.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_care_app/repositories/firestore_page.dart';
import 'package:pet_care_app/repositories/firestore_page_controller.dart';

/// Registers tests for pagination, overlapping requests, and error reporting.
void main() {
  test(
    'appends bounded pages until the query reports no more records',
    () async {
      var requestedPage = 0;
      final controller = FirestorePageController<int>(
        fetchPage: ({cursor}) async {
          requestedPage++;
          final isFirstPage = requestedPage == 1;
          return FirestorePage<int>(
            items: isFirstPage
                ? List.generate(10, (index) => index)
                : const [10, 11],
            lastDocument: null,
            hasMore: isFirstPage,
          );
        },
      );
      addTearDown(controller.dispose);

      await controller.loadMore();
      expect(controller.items, hasLength(10));
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items, hasLength(12));
      expect(controller.hasMore, isFalse);

      await controller.loadMore();
      expect(requestedPage, 2);
    },
  );

  test('prevents overlapping page requests', () async {
    final response = Completer<FirestorePage<int>>();
    var requests = 0;
    final controller = FirestorePageController<int>(
      fetchPage: ({cursor}) {
        requests++;
        return response.future;
      },
    );
    addTearDown(controller.dispose);

    final firstRequest = controller.loadMore();
    await controller.loadMore();
    expect(requests, 1);

    response.complete(
      const FirestorePage<int>(items: [1], lastDocument: null, hasMore: false),
    );
    await firstRequest;
    expect(controller.items, [1]);
  });

  test('exposes a failed page request so the screen can offer retry', () async {
    final controller = FirestorePageController<int>(
      fetchPage: ({cursor}) async => throw StateError('network unavailable'),
    );
    addTearDown(controller.dispose);

    await controller.loadMore();

    expect(controller.error, isA<StateError>());
    expect(controller.hasMore, isTrue);
    expect(controller.isLoading, isFalse);
  });
}
