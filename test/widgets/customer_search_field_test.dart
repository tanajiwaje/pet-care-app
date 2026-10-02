// Tests customer search by name and mobile number.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_care_app/core/widgets/customer_search_field.dart';
import 'package:pet_care_app/models/customer_model.dart';

/// Verifies that the customer picker filters both identity and contact fields.
void main() {
  final customers = [
    const CustomerModel(
      id: 'ada',
      firstName: 'Ada',
      lastName: 'Lovelace',
      mobile: '555-0101',
      address: '',
      isActive: true,
    ),
    const CustomerModel(
      id: 'grace',
      firstName: 'Grace',
      lastName: 'Hopper',
      mobile: '555-0142',
      address: '',
      isActive: true,
    ),
  ];

  testWidgets('filters customers by name and returns the selected ID', (
    tester,
  ) async {
    String? selectedId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerSearchField(
            customers: customers,
            selectedCustomerId: 'ada',
            onChanged: (value) => selectedId = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ada Lovelace · 555-0101'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'grace hop');
    await tester.pumpAndSettle();

    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    await tester.tap(find.text('Grace Hopper'));
    await tester.pumpAndSettle();

    expect(selectedId, 'grace');
  });

  testWidgets('filters customers by mobile number', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerSearchField(
            customers: customers,
            selectedCustomerId: 'ada',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ada Lovelace · 555-0101'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0142');
    await tester.pumpAndSettle();

    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
  });
}
