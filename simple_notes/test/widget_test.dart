import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simple_notes/app.dart';

void main() {
  testWidgets('Home screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SecureNotesApp()));

    expect(find.text('Secure Notes'), findsOneWidget);
  });
}