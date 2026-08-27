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
          id: 'paper-${index + 1}',
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

    expect(find.text('Untitled Paper'), findsWidgets);
    expect(find.text('Start writing...'), findsOneWidget);
  });

  testWidgets('renaming a paper updates its preview title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('title-editor-paper-1')),
      'Project Plan',
    );
    await tester.pump();

    expect(find.widgetWithText(PaperPreview, 'Project Plan'), findsOneWidget);
  });

  testWidgets('each paper keeps its own editor content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('editor-paper-1')),
      'First paper content',
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(find.text('Untitled Paper 2'), findsWidgets);
    expect(find.text('First paper content'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('editor-paper-2')),
      'Second paper content',
    );
    await tester.pump();

    await tester.tap(find.text('Untitled Paper').first);
    await tester.pumpAndSettle();

    expect(find.text('First paper content'), findsOneWidget);

    await tester.tap(find.text('Untitled Paper 2').first);
    await tester.pumpAndSettle();

    expect(find.text('Second paper content'), findsOneWidget);
  });

  testWidgets('command b bolds selected editor text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.tap(editorFinder);
    await tester.enterText(editorFinder, 'Heavy riff');
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Heavy riff',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '**Heavy** riff');
  });

  testWidgets('bold markdown markers are hidden in styled editor text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    final context = tester.element(find.byType(ShredNoteApp));
    final controller = PaperEditingController(text: '**Heavy** riff');
    addTearDown(controller.dispose);

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 18),
      withComposing: false,
    );
    final hiddenBoldMarkerSpans = span.children!
        .where(
          (child) =>
              child is TextSpan &&
              child.text == '**' &&
              child.style?.color == Colors.transparent,
        )
        .length;
    final boldTextSpans = span.children!.where(
      (child) =>
          child is TextSpan &&
          child.text == 'Heavy' &&
          child.style?.fontWeight == FontWeight.w800,
    );

    expect(hiddenBoldMarkerSpans, 2);
    expect(boldTextSpans.length, 1);
    expect(span.toPlainText(), '**Heavy** riff');
  });

  testWidgets('command i italicizes selected editor text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.tap(editorFinder);
    await tester.enterText(editorFinder, 'Fast phrase');
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Fast phrase',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '*Fast* phrase');
  });

  testWidgets('command u underlines selected editor text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.tap(editorFinder);
    await tester.enterText(editorFinder, 'Held chord');
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Held chord',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '<u>Held</u> chord');
  });

  testWidgets('italic and underline markers are hidden in styled editor text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    final context = tester.element(find.byType(ShredNoteApp));
    final controller = PaperEditingController(text: '*Fast* <u>Held</u>');
    addTearDown(controller.dispose);

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 18),
      withComposing: false,
    );
    final hiddenItalicMarkerSpans = span.children!
        .where(
          (child) =>
              child is TextSpan &&
              child.text == '*' &&
              child.style?.color == Colors.transparent,
        )
        .length;
    final hiddenUnderlineMarkerSpans = span.children!
        .where(
          (child) =>
              child is TextSpan &&
              (child.text == '<u>' || child.text == '</u>') &&
              child.style?.color == Colors.transparent,
        )
        .length;
    final italicTextSpans = span.children!.where(
      (child) =>
          child is TextSpan &&
          child.text == 'Fast' &&
          child.style?.fontStyle == FontStyle.italic,
    );
    final underlineTextSpans = span.children!.where(
      (child) =>
          child is TextSpan &&
          child.text == 'Held' &&
          child.style?.decoration == TextDecoration.underline,
    );

    expect(hiddenItalicMarkerSpans, 2);
    expect(hiddenUnderlineMarkerSpans, 2);
    expect(italicTextSpans.length, 1);
    expect(underlineTextSpans.length, 1);
    expect(span.toPlainText(), '*Fast* <u>Held</u>');
  });

  testWidgets('enter exits active inline styles before the new line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.tap(editorFinder);
    await tester.pump();

    final cases = [
      (brokenText: '**Heavy\n** riff', fixedText: '**Heavy**\n riff'),
      (brokenText: '*Fast\n* phrase', fixedText: '*Fast*\n phrase'),
      (brokenText: '<u>Held\n</u> chord', fixedText: '<u>Held</u>\n chord'),
    ];

    for (final testCase in cases) {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: testCase.brokenText,
          selection: TextSelection.collapsed(
            offset: testCase.brokenText.indexOf('\n') + 1,
          ),
        ),
      );
      await tester.pump();

      final editor = tester.widget<TextField>(editorFinder);
      expect(editor.controller!.text, testCase.fixedText);
    }
  });

  testWidgets('collapsed inline shortcuts can exit before normal typing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.tap(editorFinder);
    await tester.pump();

    final cases = [
      (
        key: LogicalKeyboardKey.keyB,
        activeText: '**Heavy**',
        activeCursor: 7,
        exitCursor: 9,
        normalText: '**Heavy** riff',
      ),
      (
        key: LogicalKeyboardKey.keyI,
        activeText: '*Fast*',
        activeCursor: 5,
        exitCursor: 6,
        normalText: '*Fast* phrase',
      ),
      (
        key: LogicalKeyboardKey.keyU,
        activeText: '<u>Held</u>',
        activeCursor: 7,
        exitCursor: 11,
        normalText: '<u>Held</u> chord',
      ),
    ];

    for (final testCase in cases) {
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      await tester.pump();

      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: testCase.activeText,
          selection: TextSelection.collapsed(offset: testCase.activeCursor),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(testCase.key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      var editor = tester.widget<TextField>(editorFinder);
      expect(editor.controller!.selection.extentOffset, testCase.exitCursor);

      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: testCase.normalText,
          selection: TextSelection.collapsed(
            offset: testCase.normalText.length,
          ),
        ),
      );
      await tester.pump();

      editor = tester.widget<TextField>(editorFinder);
      expect(editor.controller!.text, testCase.normalText);
    }
  });

  testWidgets('slash h command creates a heading line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.enterText(editorFinder, '/h\n');
    await tester.pump();

    final editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '# ');
  });

  testWidgets('slash hh and hhh commands create smaller heading lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.enterText(editorFinder, '/hh\n');
    await tester.pump();

    var editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '## ');

    await tester.enterText(editorFinder, '/hhh\n');
    await tester.pump();

    editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '### ');
  });

  testWidgets('heading markdown markers are hidden in styled editor text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    final context = tester.element(find.byType(ShredNoteApp));
    final controller = PaperEditingController(
      text: '# Main\n## Mid\n### Small',
    );
    addTearDown(controller.dispose);

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 18),
      withComposing: false,
    );
    final hiddenMarkerSpans = span.children!
        .where(
          (child) =>
              child is TextSpan &&
              (child.text == '# ' ||
                  child.text == '## ' ||
                  child.text == '### ') &&
              child.style?.color == Colors.transparent,
        )
        .length;

    expect(hiddenMarkerSpans, 3);
    expect(span.toPlainText(), '# Main\n## Mid\n### Small');
  });

  testWidgets('slash l command creates a bullet line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShredNoteApp());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final editorFinder = find.byKey(const ValueKey('editor-paper-1'));
    await tester.enterText(editorFinder, '/l\n');
    await tester.pump();

    final editor = tester.widget<TextField>(editorFinder);
    expect(editor.controller!.text, '- ');
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

  testWidgets('smaller papers expose more nearby previews', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      paperStackFixture(papers: papers(30, selectedIndex: 8)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(PaperPreview).evaluate().length,
      greaterThanOrEqualTo(6),
    );
  });

  testWidgets('paper stack can show at least five previews in view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      paperStackFixture(papers: papers(30, selectedIndex: 8)),
    );
    await tester.pumpAndSettle();

    final visiblePreviewCount = find.byType(PaperPreview).evaluate().where((
      element,
    ) {
      final renderBox = element.renderObject! as RenderBox;
      final topLeft = renderBox.localToGlobal(Offset.zero);
      final rect = topLeft & renderBox.size;

      return rect.bottom > 0 && rect.top < 600;
    }).length;

    expect(visiblePreviewCount, greaterThanOrEqualTo(5));
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

    expect(secondPaperTop - firstPaperBottom, inInclusiveRange(4, 24));
    expect(secondTitleTop, greaterThan(firstPaperBottom));
  });

  testWidgets('focused paper has balanced adjacent spacing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      paperStackFixture(papers: papers(3, selectedIndex: 1)),
    );
    await tester.pumpAndSettle();

    final previousRect = tester.getRect(
      find.widgetWithText(PaperPreview, 'Paper 1'),
    );
    final focusedRect = tester.getRect(
      find.widgetWithText(PaperPreview, 'Paper 2'),
    );
    final nextRect = tester.getRect(
      find.widgetWithText(PaperPreview, 'Paper 3'),
    );
    final gapAbove = focusedRect.top - previousRect.bottom;
    final gapBelow = nextRect.top - focusedRect.bottom;

    expect((gapAbove - gapBelow).abs(), lessThan(8));
  });

  testWidgets('selected paper renders larger than unselected neighbours', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      paperStackFixture(papers: papers(3, selectedIndex: 1)),
    );
    await tester.pumpAndSettle();

    final selectedRect = tester.getRect(
      find.widgetWithText(PaperPreview, 'Paper 2'),
    );
    final unselectedRect = tester.getRect(
      find.widgetWithText(PaperPreview, 'Paper 1'),
    );

    expect(selectedRect.width, greaterThan(unselectedRect.width));
    expect(selectedRect.height, greaterThan(unselectedRect.height));
  });

  testWidgets('small scroll does not immediately snap to another paper', (
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
                            isSelected: paper.id == selectedPaper.id,
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

    await tester.drag(find.byType(PaperStack), const Offset(0, -90));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final selectedTitles = tester
        .widgetList<PaperPreview>(find.byType(PaperPreview))
        .where((preview) => preview.paper.isSelected)
        .map((preview) => preview.paper.title);

    expect(selectedTitles, contains('Paper 1'));
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
                            isSelected: paper.id == selectedPaper.id,
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
    await tester.pumpAndSettle();

    final selectedTitles = tester
        .widgetList<PaperPreview>(find.byType(PaperPreview))
        .where((preview) => preview.paper.isSelected)
        .map((preview) => preview.paper.title);

    expect(selectedTitles, contains('Paper 2'));
  });
}
