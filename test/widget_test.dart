import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shred_note/app.dart';

void main() {
  testWidgets('shows the ShredNote app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ShredNoteApp());

    expect(find.byType(ShredNoteApp), findsOneWidget);
  });

  testWidgets('creates a paper with the command n shortcut', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    expect(find.text('Untitled Paper'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(find.text('Untitled Paper'), findsOneWidget);
  });
}
