import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shred_note/app.dart';
import 'package:shred_note/screens/workspace_screen.dart';

void main() {
  List<PaperStackItem> papers(int count, {int selectedIndex = 0}) {
    return [
      for (var index = 0; index < count; index += 1)
        PaperStackItem(
          title: 'Paper ${index + 1}',
          createdAt: DateTime(2026, 8, 27, 12, index),
          isSelected: index == selectedIndex,
        ),
    ];
  }

  Widget paperStackFixture({
    required List<PaperStackItem> papers,
    ValueChanged<PaperStackItem>? onPaperSelected,
  }) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 260,
          height: 600,
          child: PaperStack(papers: papers, onPaperSelected: onPaperSelected),
        ),
      ),
    );
  }

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

  testWidgets('paper previews keep an A4-like vertical proportion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(paperStackFixture(papers: papers(1)));

    final previewSize = tester.getSize(find.byType(PaperPreview));

    expect(previewSize.height / previewSize.width, closeTo(1.414, 0.01));
  });

  testWidgets('paper stack renders a nearby carousel window', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(paperStackFixture(papers: papers(30)));

    expect(find.byType(PaperPreview), findsWidgets);
    expect(find.byType(PaperPreview).evaluate().length, lessThan(10));
    expect(find.text('Paper 30'), findsNothing);
  });

  testWidgets('paper stack keeps a small gap around the focused sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(paperStackFixture(papers: papers(3)));

    final firstPaperBottom = tester
        .getBottomLeft(find.widgetWithText(PaperPreview, 'Paper 1'))
        .dy;
    final secondPaperTop = tester
        .getTopLeft(find.widgetWithText(PaperPreview, 'Paper 2'))
        .dy;
    final secondTitleTop = tester.getTopLeft(find.text('Paper 2')).dy;

    expect(secondPaperTop - firstPaperBottom, inInclusiveRange(8, 28));
    expect(secondTitleTop, greaterThan(firstPaperBottom));
  });

  testWidgets('tapping a neighbouring paper selects it', (
    WidgetTester tester,
  ) async {
    var currentPapers = papers(5);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                height: 600,
                child: PaperStack(
                  papers: currentPapers,
                  onPaperSelected: (selectedPaper) {
                    setState(() {
                      currentPapers = [
                        for (final paper in currentPapers)
                          paper.copyWith(
                            isSelected:
                                paper.createdAt == selectedPaper.createdAt,
                          ),
                      ];
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Paper 2'));
    await tester.pump();

    final selectedTitles = tester
        .widgetList<PaperPreview>(find.byType(PaperPreview))
        .where((preview) => preview.paper.isSelected)
        .map((preview) => preview.paper.title);

    expect(selectedTitles, contains('Paper 2'));
  });
}
