import 'package:flutter_test/flutter_test.dart';
import 'package:shred_note/app.dart';

void main() {
  testWidgets('shows the ShredNote app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ShredNoteApp());

    expect(find.byType(ShredNoteApp), findsOneWidget);
  });
}
