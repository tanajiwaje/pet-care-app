// Verifies the startup screen while Firebase initialization is pending.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_care_app/main.dart';

/// Registers a widget test for the animated Firebase startup state.
void main() {
  testWidgets('shows the animated startup screen while Firebase initializes', (
    WidgetTester tester,
  ) async {
    final firebaseInitialization = Completer<void>();
    await tester.pumpWidget(
      PetCareApp(firebaseInitializer: () => firebaseInitialization.future),
    );

    expect(find.text('PetCare'), findsOneWidget);
    expect(find.text('A little care goes a long way.'), findsOneWidget);
    expect(find.text('Getting everything ready...'), findsOneWidget);
    expect(find.bySemanticsLabel('Animated cat'), findsOneWidget);
    expect(find.bySemanticsLabel('Animated dog'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Getting everything ready...'), findsOneWidget);
  });
}
