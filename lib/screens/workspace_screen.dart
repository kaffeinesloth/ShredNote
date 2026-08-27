import 'dart:async';
import 'dart:math' show max, min;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _hapticsChannel = MethodChannel('shred_note/haptics');

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final List<PaperStackItem> _papers = [];
  final TextEditingController _titleController = TextEditingController();
  final PaperEditingController _editorController = PaperEditingController();
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'WorkspaceShortcuts',
  );
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'PaperBodyEditor');
  String _lastEditorText = '';
  int _nextPaperSequence = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _shortcutFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _editorController.dispose();
    _shortcutFocusNode.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _addPaper() {
    final createdAt = DateTime.now();
    final paper = PaperStackItem(
      id: 'paper-${_nextPaperSequence++}',
      title: _nextPaperTitle(),
      createdAt: createdAt,
      isSelected: true,
    );

    setState(() {
      for (var index = 0; index < _papers.length; index += 1) {
        _papers[index] = _papers[index].copyWith(isSelected: false);
      }

      _papers.add(paper);
      _papers.sort(
        (first, second) => first.createdAt.compareTo(second.createdAt),
      );
    });
    _syncEditorWithPaper(paper);
  }

  String _nextPaperTitle() {
    final number = _papers.length + 1;

    if (number == 1) {
      return 'Untitled Paper';
    }

    return 'Untitled Paper $number';
  }

  void _selectPaper(PaperStackItem selectedPaper) {
    setState(() {
      for (var index = 0; index < _papers.length; index += 1) {
        final paper = _papers[index];

        _papers[index] = paper.copyWith(
          isSelected: paper.id == selectedPaper.id,
        );
      }
    });
    _syncEditorWithPaper(selectedPaper);
  }

  void _updateSelectedPaperContent(String content) {
    final selectedIndex = _selectedPaperIndex;
    if (selectedIndex == -1) {
      return;
    }

    setState(() {
      _papers[selectedIndex] = _papers[selectedIndex].copyWith(
        content: content,
      );
    });
  }

  void _handleEditorContentChanged(String content) {
    final previousEditorText = _lastEditorText;
    final inlineContinueResult = _inlineStyleContinueOnEnterReplacement();

    if (inlineContinueResult != null) {
      _editorController.value = inlineContinueResult;
      _updateSelectedPaperContent(inlineContinueResult.text);
      _lastEditorText = inlineContinueResult.text;
      return;
    }

    final commandResult = _completedLineCommandReplacement();

    if (commandResult != null) {
      _editorController.value = commandResult;
      _updateSelectedPaperContent(commandResult.text);
      _lastEditorText = commandResult.text;
      return;
    }

    final listContinuationResult = _listContinuationOnEnterReplacement(
      previousEditorText,
    );

    if (listContinuationResult != null) {
      _editorController.value = listContinuationResult;
      _updateSelectedPaperContent(listContinuationResult.text);
      _lastEditorText = listContinuationResult.text;
      return;
    }

    _updateSelectedPaperContent(content);
    _lastEditorText = content;
  }

  TextEditingValue? _completedLineCommandReplacement() {
    final value = _editorController.value;
    final text = value.text;
    final selectionOffset = value.selection.extentOffset;

    if (selectionOffset <= 0 ||
        selectionOffset > text.length ||
        text.codeUnitAt(selectionOffset - 1) != 10) {
      return null;
    }

    final commandEnd = selectionOffset - 1;
    final lineStart = text.lastIndexOf('\n', max(0, commandEnd - 1)) + 1;
    final command = text.substring(lineStart, commandEnd).trim();
    final replacement = switch (command) {
      '/h' => '# ',
      '/hh' => '## ',
      '/hhh' => '### ',
      '/l' => '- ',
      _ => null,
    };

    if (replacement == null) {
      return null;
    }

    final updatedText = text.replaceRange(
      lineStart,
      selectionOffset,
      replacement,
    );
    final updatedOffset = lineStart + replacement.length;

    return TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedOffset),
    );
  }

  TextEditingValue? _inlineStyleContinueOnEnterReplacement() {
    final value = _editorController.value;
    final text = value.text;
    final selectionOffset = value.selection.extentOffset;

    if (selectionOffset <= 0 ||
        selectionOffset > text.length ||
        text.codeUnitAt(selectionOffset - 1) != 10) {
      return null;
    }

    final styles = [
      (openingMarker: '<u>', closingMarker: '</u>', skipDoubleAsterisks: false),
      (openingMarker: '**', closingMarker: '**', skipDoubleAsterisks: false),
      (openingMarker: '_', closingMarker: '_', skipDoubleAsterisks: false),
    ];

    for (final style in styles) {
      if (!text.startsWith(style.closingMarker, selectionOffset)) {
        continue;
      }

      final beforeNewline = text.substring(0, selectionOffset - 1);
      final hasOpenStyle = _hasUnclosedInlineMarkerBeforeCursor(
        beforeNewline,
        openingMarker: style.openingMarker,
        closingMarker: style.closingMarker,
        skipDoubleAsterisks: style.skipDoubleAsterisks,
      );

      if (!hasOpenStyle) {
        continue;
      }

      final currentLineStart =
          text.lastIndexOf('\n', max(0, selectionOffset - 2)) + 1;
      final currentLine = text.substring(currentLineStart, selectionOffset - 1);
      final listMarker = _listMarkerForLine(currentLine) ?? '';
      final replacement =
          '${style.closingMarker}\n$listMarker${style.openingMarker}${style.closingMarker}';
      final updatedText = text.replaceRange(
        selectionOffset - 1,
        selectionOffset + style.closingMarker.length,
        replacement,
      );
      final updatedOffset =
          selectionOffset -
          1 +
          style.closingMarker.length +
          1 +
          listMarker.length +
          style.openingMarker.length;

      return TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: updatedOffset),
      );
    }

    return null;
  }

  TextEditingValue? _listContinuationOnEnterReplacement(String previousText) {
    final value = _editorController.value;
    final text = value.text;
    final selectionOffset = value.selection.extentOffset;

    if (selectionOffset <= 0 ||
        selectionOffset > text.length ||
        text.codeUnitAt(selectionOffset - 1) != 10) {
      return null;
    }

    final insertedNewline =
        text.length == previousText.length + 1 &&
        text.replaceRange(selectionOffset - 1, selectionOffset, '') ==
            previousText;
    if (!insertedNewline) {
      return null;
    }

    final previousLineEnd = selectionOffset - 1;
    final previousLineStart =
        text.lastIndexOf('\n', max(0, previousLineEnd - 1)) + 1;
    final previousLine = text.substring(previousLineStart, previousLineEnd);
    final marker = _listMarkerForLine(previousLine);

    if (marker == null) {
      return null;
    }

    if (previousLine.length == marker.length) {
      if (marker.trim() != '+') {
        return null;
      }

      final updatedText = text.replaceRange(
        previousLineStart,
        selectionOffset,
        '- ',
      );

      return TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: previousLineStart + 2),
      );
    }

    if (text.startsWith(marker, selectionOffset)) {
      return null;
    }

    final updatedText = text.replaceRange(
      selectionOffset,
      selectionOffset,
      marker,
    );
    final updatedOffset = selectionOffset + marker.length;

    return TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedOffset),
    );
  }

  String? _listMarkerForLine(String line) {
    final markerStart = line.indexOf(RegExp(r'[^ ]'));
    if (markerStart == -1) {
      return null;
    }

    final marker = line.substring(markerStart);
    if (!marker.startsWith('- ') && !marker.startsWith('+ ')) {
      return null;
    }

    return '${line.substring(0, markerStart)}${marker.substring(0, 2)}';
  }

  bool _hasUnclosedInlineMarkerBeforeCursor(
    String text, {
    required String openingMarker,
    required String closingMarker,
    required bool skipDoubleAsterisks,
  }) {
    var cursor = 0;
    var isOpen = false;

    while (cursor < text.length) {
      final openingIndex = _nextMarkerIndex(
        text,
        openingMarker,
        cursor,
        skipDoubleAsterisks: skipDoubleAsterisks,
      );
      final closingIndex = _nextMarkerIndex(
        text,
        closingMarker,
        cursor,
        skipDoubleAsterisks: skipDoubleAsterisks,
      );

      if (openingIndex == -1 && closingIndex == -1) {
        return isOpen;
      }

      if (openingIndex != -1 &&
          (closingIndex == -1 || openingIndex <= closingIndex)) {
        isOpen = !isOpen;
        cursor = openingIndex + openingMarker.length;
      } else {
        isOpen = !isOpen;
        cursor = closingIndex + closingMarker.length;
      }
    }

    return isOpen;
  }

  int _nextMarkerIndex(
    String text,
    String marker,
    int start, {
    required bool skipDoubleAsterisks,
  }) {
    var markerIndex = start;

    while (markerIndex < text.length) {
      markerIndex = text.indexOf(marker, markerIndex);
      if (markerIndex == -1) {
        return -1;
      }

      if (!skipDoubleAsterisks || !_isPartOfDoubleAsterisk(text, markerIndex)) {
        return markerIndex;
      }

      markerIndex += marker.length;
    }

    return -1;
  }

  bool _isPartOfDoubleAsterisk(String text, int index) {
    return text[index] == '*' &&
        ((index > 0 && text[index - 1] == '*') ||
            (index + 1 < text.length && text[index + 1] == '*'));
  }

  void _updateSelectedPaperTitle(String title) {
    final selectedIndex = _selectedPaperIndex;
    if (selectedIndex == -1) {
      return;
    }

    setState(() {
      _papers[selectedIndex] = _papers[selectedIndex].copyWith(title: title);
    });
  }

  int get _selectedPaperIndex {
    return _papers.indexWhere((paper) => paper.isSelected);
  }

  PaperStackItem? get _selectedPaper {
    final selectedIndex = _selectedPaperIndex;
    if (selectedIndex == -1) {
      return null;
    }

    return _papers[selectedIndex];
  }

  void _syncEditorWithPaper(PaperStackItem paper) {
    _titleController.value = TextEditingValue(
      text: paper.title,
      selection: TextSelection.collapsed(offset: paper.title.length),
    );
    _editorController.value = TextEditingValue(
      text: paper.content,
      selection: TextSelection.collapsed(offset: paper.content.length),
    );
    _lastEditorText = paper.content;
  }

  void _toggleSelectedPaperBold() {
    _toggleSelectedPaperInlineStyle(openingMarker: '**', closingMarker: '**');
  }

  void _toggleSelectedPaperItalic() {
    _toggleSelectedPaperInlineStyle(openingMarker: '_', closingMarker: '_');
  }

  void _toggleSelectedPaperUnderline() {
    _toggleSelectedPaperInlineStyle(
      openingMarker: '<u>',
      closingMarker: '</u>',
    );
  }

  void _promoteCurrentListMarker() {
    if (_selectedPaperIndex == -1 || !_editorFocusNode.hasFocus) {
      return;
    }

    final value = _editorController.value;
    final selection = value.selection;
    if (!selection.isValid) {
      return;
    }

    final text = value.text;
    final cursor = selection.extentOffset;
    final lineStart = text.lastIndexOf('\n', max(0, cursor - 1)) + 1;
    final lineEnd = text.indexOf('\n', lineStart);
    final line = text.substring(
      lineStart,
      lineEnd == -1 ? text.length : lineEnd,
    );
    final markerStart = line.indexOf(RegExp(r'[^ ]'));

    if (markerStart == -1 || !line.startsWith('- ', markerStart)) {
      return;
    }

    final markerOffset = lineStart + markerStart;
    final updatedText = text.replaceRange(
      markerOffset,
      markerOffset + 2,
      '  + ',
    );
    final offsetDelta = 2;
    final updatedSelection = TextSelection(
      baseOffset: selection.baseOffset + offsetDelta,
      extentOffset: selection.extentOffset + offsetDelta,
    );

    _editorController.value = TextEditingValue(
      text: updatedText,
      selection: updatedSelection,
    );
    _updateSelectedPaperContent(updatedText);
    _lastEditorText = updatedText;
  }

  void _toggleSelectedPaperInlineStyle({
    required String openingMarker,
    required String closingMarker,
  }) {
    if (_selectedPaperIndex == -1 || !_editorFocusNode.hasFocus) {
      return;
    }

    final value = _editorController.value;
    final selection = value.selection;
    if (!selection.isValid) {
      return;
    }

    final text = value.text;
    final start = min(selection.start, selection.end);
    final end = max(selection.start, selection.end);
    late final String updatedText;
    late final TextSelection updatedSelection;

    if (selection.isCollapsed) {
      if (text.startsWith(closingMarker, start) &&
          _hasUnclosedInlineMarkerBeforeCursor(
            text.substring(0, start),
            openingMarker: openingMarker,
            closingMarker: closingMarker,
            skipDoubleAsterisks: openingMarker == '*',
          )) {
        updatedText = text;
        updatedSelection = TextSelection.collapsed(
          offset: start + closingMarker.length,
        );
      } else {
        updatedText = text.replaceRange(
          start,
          start,
          '$openingMarker$closingMarker',
        );
        updatedSelection = TextSelection.collapsed(
          offset: start + openingMarker.length,
        );
      }
    } else {
      final hasStyleMarkers =
          start >= openingMarker.length &&
          end + closingMarker.length <= text.length &&
          text.substring(start - openingMarker.length, start) ==
              openingMarker &&
          text.substring(end, end + closingMarker.length) == closingMarker;

      if (hasStyleMarkers) {
        updatedText = text
            .replaceRange(end, end + closingMarker.length, '')
            .replaceRange(start - openingMarker.length, start, '');
        updatedSelection = TextSelection(
          baseOffset: start - openingMarker.length,
          extentOffset: end - openingMarker.length,
        );
      } else {
        updatedText = text
            .replaceRange(end, end, closingMarker)
            .replaceRange(start, start, openingMarker);
        updatedSelection = TextSelection(
          baseOffset: start + openingMarker.length,
          extentOffset: end + openingMarker.length,
        );
      }
    }

    _editorController.value = TextEditingValue(
      text: updatedText,
      selection: updatedSelection,
    );
    _updateSelectedPaperContent(updatedText);
    _lastEditorText = updatedText;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const AddPaperIntent(),
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            const ToggleBoldIntent(),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
            const ToggleItalicIntent(),
        const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
            const ToggleUnderlineIntent(),
        const SingleActivator(LogicalKeyboardKey.tab):
            const PromoteListMarkerIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AddPaperIntent: CallbackAction<AddPaperIntent>(
            onInvoke: (intent) {
              _addPaper();
              return null;
            },
          ),
          ToggleBoldIntent: CallbackAction<ToggleBoldIntent>(
            onInvoke: (intent) {
              _toggleSelectedPaperBold();
              return null;
            },
          ),
          ToggleItalicIntent: CallbackAction<ToggleItalicIntent>(
            onInvoke: (intent) {
              _toggleSelectedPaperItalic();
              return null;
            },
          ),
          ToggleUnderlineIntent: CallbackAction<ToggleUnderlineIntent>(
            onInvoke: (intent) {
              _toggleSelectedPaperUnderline();
              return null;
            },
          ),
          PromoteListMarkerIntent: CallbackAction<PromoteListMarkerIntent>(
            onInvoke: (intent) {
              _promoteCurrentListMarker();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _shortcutFocusNode,
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _shortcutFocusNode.requestFocus,
                    child: SizedBox(
                      width: 260,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xFF20272A),
                        ),
                        child: _NotesSidebar(
                          papers: _papers,
                          onPaperSelected: _selectPaper,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Color(0xFFF1E9DD)),
                      child: _WorkspaceEditor(
                        paper: _selectedPaper,
                        titleController: _titleController,
                        controller: _editorController,
                        editorFocusNode: _editorFocusNode,
                        onTitleChanged: _updateSelectedPaperTitle,
                        onContentChanged: _handleEditorContentChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddPaperIntent extends Intent {
  const AddPaperIntent();
}

class ToggleBoldIntent extends Intent {
  const ToggleBoldIntent();
}

class ToggleItalicIntent extends Intent {
  const ToggleItalicIntent();
}

class ToggleUnderlineIntent extends Intent {
  const ToggleUnderlineIntent();
}

class PromoteListMarkerIntent extends Intent {
  const PromoteListMarkerIntent();
}

class PaperEditingController extends TextEditingController {
  PaperEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final defaultStyle = style ?? const TextStyle();

    return TextSpan(
      style: defaultStyle,
      children: _styledLines(text, defaultStyle),
    );
  }

  List<TextSpan> _styledLines(String source, TextStyle defaultStyle) {
    final spans = <TextSpan>[];
    final lines = source.split('\n');

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final heading = _headingForLine(line);
      final lineStyle = heading == null
          ? defaultStyle
          : defaultStyle.copyWith(
              fontSize: heading.fontSize,
              fontWeight: FontWeight.w800,
            );

      if (heading != null) {
        spans.add(
          _hiddenMarkdownMarker(
            line.substring(0, heading.markerLength),
            lineStyle,
          ),
        );
      }

      spans.addAll(
        _styledInlineSegments(
          line.substring(heading?.markerLength ?? 0),
          lineStyle,
        ),
      );

      if (index < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: lineStyle));
      }
    }

    return spans;
  }

  List<TextSpan> _styledInlineSegments(String source, TextStyle defaultStyle) {
    final match = _firstInlineMarkerMatch(source);
    if (match == null) {
      return [TextSpan(text: source, style: defaultStyle)];
    }

    final spans = <TextSpan>[];

    if (match.openStart > 0) {
      spans.addAll(
        _styledInlineSegments(
          source.substring(0, match.openStart),
          defaultStyle,
        ),
      );
    }

    spans.add(_hiddenMarkdownMarker(match.openingMarker, defaultStyle));
    spans.addAll(
      _styledInlineSegments(
        source.substring(match.contentStart, match.closeStart),
        match.applyTo(defaultStyle),
      ),
    );
    spans.add(_hiddenMarkdownMarker(match.closingMarker, defaultStyle));

    final afterClose = match.closeStart + match.closingMarker.length;
    if (afterClose < source.length) {
      spans.addAll(
        _styledInlineSegments(source.substring(afterClose), defaultStyle),
      );
    }

    return spans;
  }

  _InlineMarkerMatch? _firstInlineMarkerMatch(String source) {
    final matches = <_InlineMarkerMatch>[
      ?_delimitedMatch(
        source,
        openingMarker: '<u>',
        closingMarker: '</u>',
        styleBuilder: (style) =>
            style.copyWith(decoration: TextDecoration.underline),
      ),
      ?_delimitedMatch(
        source,
        openingMarker: '**',
        closingMarker: '**',
        styleBuilder: (style) => style.copyWith(fontWeight: FontWeight.w800),
      ),
      ?_delimitedMatch(
        source,
        openingMarker: '_',
        closingMarker: '_',
        styleBuilder: (style) => style.copyWith(fontStyle: FontStyle.italic),
      ),
    ]..sort((first, second) => first.openStart.compareTo(second.openStart));

    if (matches.isEmpty) {
      return null;
    }

    return matches.first;
  }

  _InlineMarkerMatch? _delimitedMatch(
    String source, {
    required String openingMarker,
    required String closingMarker,
    required TextStyle Function(TextStyle style) styleBuilder,
    bool skipDoubleAsterisks = false,
  }) {
    var openStart = 0;

    while (openStart < source.length) {
      openStart = source.indexOf(openingMarker, openStart);
      if (openStart == -1) {
        return null;
      }

      final contentStart = openStart + openingMarker.length;
      if (skipDoubleAsterisks &&
          ((openStart > 0 && source[openStart - 1] == '*') ||
              (contentStart < source.length && source[contentStart] == '*'))) {
        openStart = contentStart;
        continue;
      }

      final closeStart = source.indexOf(closingMarker, contentStart);
      if (closeStart == -1) {
        return null;
      }

      if (skipDoubleAsterisks &&
          ((closeStart > 0 && source[closeStart - 1] == '*') ||
              (closeStart + 1 < source.length &&
                  source[closeStart + 1] == '*'))) {
        openStart = closeStart + closingMarker.length;
        continue;
      }

      return _InlineMarkerMatch(
        openingMarker: openingMarker,
        closingMarker: closingMarker,
        openStart: openStart,
        contentStart: contentStart,
        closeStart: closeStart,
        styleBuilder: styleBuilder,
      );
    }

    return null;
  }

  TextSpan _hiddenMarkdownMarker(String marker, TextStyle defaultStyle) {
    return TextSpan(
      text: marker,
      style: defaultStyle.copyWith(
        color: Colors.transparent,
        fontSize: 0.1,
        height: 0.01,
      ),
    );
  }

  _HeadingStyle? _headingForLine(String line) {
    if (line.startsWith('### ')) {
      return const _HeadingStyle(markerLength: 4, fontSize: 20);
    }

    if (line.startsWith('## ')) {
      return const _HeadingStyle(markerLength: 3, fontSize: 24);
    }

    if (line.startsWith('# ')) {
      return const _HeadingStyle(markerLength: 2, fontSize: 28);
    }

    return null;
  }
}

class _HeadingStyle {
  const _HeadingStyle({required this.markerLength, required this.fontSize});

  final int markerLength;
  final double fontSize;
}

class _InlineMarkerMatch {
  const _InlineMarkerMatch({
    required this.openingMarker,
    required this.closingMarker,
    required this.openStart,
    required this.contentStart,
    required this.closeStart,
    required this.styleBuilder,
  });

  final String openingMarker;
  final String closingMarker;
  final int openStart;
  final int contentStart;
  final int closeStart;
  final TextStyle Function(TextStyle style) styleBuilder;

  TextStyle applyTo(TextStyle style) => styleBuilder(style);
}

class _NotesSidebar extends StatelessWidget {
  const _NotesSidebar({required this.papers, required this.onPaperSelected});

  final List<PaperStackItem> papers;
  final ValueChanged<PaperStackItem> onPaperSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PaperStack(papers: papers, onPaperSelected: onPaperSelected),
    );
  }
}

class _WorkspaceEditor extends StatelessWidget {
  const _WorkspaceEditor({
    required this.paper,
    required this.titleController,
    required this.controller,
    required this.editorFocusNode,
    required this.onTitleChanged,
    required this.onContentChanged,
  });

  final PaperStackItem? paper;
  final TextEditingController titleController;
  final TextEditingController controller;
  final FocusNode editorFocusNode;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;

  @override
  Widget build(BuildContext context) {
    if (paper == null) {
      return const Center(
        child: Text(
          'Press Command+N to create a paper',
          style: TextStyle(
            color: Color(0xFF756D63),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey('title-editor-${paper!.id}'),
            controller: titleController,
            onChanged: onTitleChanged,
            decoration: const InputDecoration(
              hintText: 'Untitled Paper',
              border: InputBorder.none,
              isCollapsed: true,
            ),
            style: const TextStyle(
              color: Color(0xFF28241F),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: TextField(
              key: ValueKey('editor-${paper!.id}'),
              controller: controller,
              focusNode: editorFocusNode,
              onChanged: onContentChanged,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Start writing...',
                border: InputBorder.none,
                isCollapsed: true,
              ),
              style: const TextStyle(
                color: Color(0xFF28241F),
                fontSize: 18,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class PaperStack extends StatefulWidget {
  const PaperStack({super.key, required this.papers, this.onPaperSelected});

  final List<PaperStackItem> papers;
  final ValueChanged<PaperStackItem>? onPaperSelected;

  @override
  State<PaperStack> createState() => _PaperStackState();
}

class _PaperStackState extends State<PaperStack> {
  static const double _a4HeightRatio = 1.414;
  static const double _paperWidthFactor = 0.70;
  static const double _paperStrideFactor = 1.03;
  static const double _targetVisiblePaperHeightFactor = 3.55;
  static const double _focusChangeThreshold = 0.58;
  static const Duration _snapDebounceDuration = Duration(milliseconds: 140);
  static const Duration _snapAnimationDuration = Duration(milliseconds: 420);
  static const Duration _scrollHapticMinimumInterval = Duration(
    milliseconds: 90,
  );

  late final ScrollController _scrollController;
  Timer? _snapDebounceTimer;
  DateTime? _lastScrollHapticAt;
  int? _lastMainAreaIndex;
  bool _isSnapping = false;
  bool _shouldAlignSelectedPaper = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _snapDebounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaperStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectedIndex = _selectedPaperIndex;
    if (selectedIndex == -1) {
      return;
    }

    final oldSelectedIndex = oldWidget.papers.indexWhere(
      (paper) => paper.isSelected,
    );
    if (selectedIndex != oldSelectedIndex ||
        widget.papers.length != oldWidget.papers.length) {
      _shouldAlignSelectedPaper = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.papers.isEmpty) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final maxPaperWidth = constraints.maxWidth * _paperWidthFactor;
        final widthBasedPaperHeight = maxPaperWidth * _a4HeightRatio;
        final heightBasedPaperHeight =
            viewportHeight / _targetVisiblePaperHeightFactor;
        final paperHeight = max(
          1.0,
          min(widthBasedPaperHeight, heightBasedPaperHeight),
        );
        final paperWidth = paperHeight / _a4HeightRatio;
        final paperStride = paperHeight * _paperStrideFactor;
        final viewportCenter = viewportHeight / 2;
        final verticalInset = max(24.0, (viewportHeight - paperHeight) / 2);
        final stackHeight =
            verticalInset * 2 +
            paperHeight +
            ((widget.papers.length - 1) * paperStride);
        if (_shouldAlignSelectedPaper) {
          _shouldAlignSelectedPaper = false;
          final selectedIndex = _selectedPaperIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && selectedIndex != -1) {
              _snapToPaper(selectedIndex, paperStride, selectPaper: false);
            }
          });
        }

        return ClipRect(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification ||
                  notification is ScrollUpdateNotification) {
                _snapDebounceTimer?.cancel();
              }

              if (notification is ScrollStartNotification) {
                _lastMainAreaIndex = _scrollController.hasClients
                    ? _mainPaperAreaIndex(paperStride)
                    : null;
              }

              if (notification is ScrollUpdateNotification && !_isSnapping) {
                _playScrollHapticIfNeeded(paperStride);
              }

              if (notification is ScrollEndNotification && !_isSnapping) {
                _scheduleSnapToRestingPaper(paperStride);
              }

              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: stackHeight,
                child: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final scrollOffset = _scrollController.hasClients
                        ? _scrollController.offset
                        : _targetScrollOffsetForSelectedPaper(paperStride);
                    final focusedPosition = scrollOffset / paperStride;
                    final focusedIndex = focusedPosition
                        .round()
                        .clamp(0, widget.papers.length - 1)
                        .toInt();
                    final visibleRadius = max(
                      2,
                      (viewportHeight / paperStride).ceil() + 1,
                    );
                    final firstVisibleIndex = max(
                      0,
                      focusedIndex - visibleRadius,
                    );
                    final lastVisibleIndex = min(
                      widget.papers.length - 1,
                      focusedIndex + visibleRadius,
                    );
                    final paperLayouts =
                        [
                          for (
                            var index = firstVisibleIndex;
                            index <= lastVisibleIndex;
                            index += 1
                          )
                            _PaperStackLayout(
                              paper: widget.papers[index],
                              index: index,
                              centerY:
                                  verticalInset +
                                  paperHeight / 2 +
                                  index * paperStride,
                              distanceFromFocus: (index - focusedPosition)
                                  .abs(),
                            ),
                        ]..sort(
                          (first, second) => second.distanceFromFocus.compareTo(
                            first.distanceFromFocus,
                          ),
                        );

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final layout in paperLayouts)
                          _PositionedPaperPreview(
                            paper: layout.paper,
                            centerY: layout.centerY,
                            scrollOffset: scrollOffset,
                            viewportCenter: viewportCenter,
                            paperWidth: paperWidth,
                            paperHeight: paperHeight,
                            distanceFromFocus: layout.distanceFromFocus,
                            onTap: () {
                              _snapToPaper(
                                layout.index,
                                paperStride,
                                selectPaper: true,
                                selectAfterSnap: true,
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int get _selectedPaperIndex {
    return widget.papers.indexWhere((paper) => paper.isSelected);
  }

  double _targetScrollOffsetForSelectedPaper(double paperStride) {
    final selectedIndex = _selectedPaperIndex;
    if (selectedIndex == -1) {
      return 0;
    }

    return selectedIndex * paperStride;
  }

  void _snapToNearestPaper(double paperStride) {
    if (!_scrollController.hasClients || widget.papers.isEmpty) {
      return;
    }

    final restingIndex = _restingPaperIndex(paperStride);

    _snapToPaper(
      restingIndex,
      paperStride,
      selectPaper: true,
      selectAfterSnap: true,
    );
  }

  void _scheduleSnapToRestingPaper(double paperStride) {
    _snapDebounceTimer?.cancel();
    _snapDebounceTimer = Timer(_snapDebounceDuration, () {
      if (mounted) {
        _snapToNearestPaper(paperStride);
      }
    });
  }

  int _restingPaperIndex(double paperStride) {
    final selectedIndex = _selectedPaperIndex;
    final focusedPosition = _scrollController.offset / paperStride;

    if (selectedIndex != -1 &&
        (focusedPosition - selectedIndex).abs() < _focusChangeThreshold) {
      return selectedIndex;
    }

    return focusedPosition.round().clamp(0, widget.papers.length - 1).toInt();
  }

  Future<void> _snapToPaper(
    int index,
    double paperStride, {
    bool selectPaper = true,
    bool selectAfterSnap = false,
  }) async {
    if (!_scrollController.hasClients || widget.papers.isEmpty) {
      return;
    }

    if (selectPaper && !selectAfterSnap) {
      widget.onPaperSelected?.call(widget.papers[index]);
    }

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final targetOffset = (index * paperStride)
        .clamp(0.0, maxScrollExtent)
        .toDouble();

    if ((_scrollController.offset - targetOffset).abs() < 0.5) {
      if (selectPaper && selectAfterSnap) {
        widget.onPaperSelected?.call(widget.papers[index]);
      }
      return;
    }

    _isSnapping = true;
    try {
      await _scrollController.animateTo(
        targetOffset,
        duration: _snapAnimationDuration,
        curve: Curves.easeOutCubic,
      );

      if (mounted && selectPaper && selectAfterSnap) {
        widget.onPaperSelected?.call(widget.papers[index]);
      }
    } finally {
      if (mounted) {
        _isSnapping = false;
      }
    }
  }

  void _playScrollHapticIfNeeded(double paperStride) {
    if (!_scrollController.hasClients) {
      return;
    }

    final now = DateTime.now();
    final currentMainAreaIndex = _mainPaperAreaIndex(paperStride);
    final previousMainAreaIndex = _lastMainAreaIndex ?? currentMainAreaIndex;
    final hasCrossedMainAreaThreshold =
        currentMainAreaIndex != previousMainAreaIndex;
    final hasWaitedEnough =
        _lastScrollHapticAt == null ||
        now.difference(_lastScrollHapticAt!) >= _scrollHapticMinimumInterval;

    if (!hasCrossedMainAreaThreshold || !hasWaitedEnough) {
      return;
    }

    _lastMainAreaIndex = currentMainAreaIndex;
    _lastScrollHapticAt = now;
    _playPaperScrollHaptic();
  }

  int _mainPaperAreaIndex(double paperStride) {
    return (_scrollController.offset / paperStride)
        .round()
        .clamp(0, widget.papers.length - 1)
        .toInt();
  }

  Future<void> _playPaperScrollHaptic() async {
    try {
      await _hapticsChannel.invokeMethod<void>('paperScroll');
    } on MissingPluginException {
      // Haptics are only wired on platforms that provide a native channel.
    } on PlatformException {
      // Haptics are optional; scrolling should never fail because of them.
    }
  }
}

class _PaperStackLayout {
  const _PaperStackLayout({
    required this.paper,
    required this.index,
    required this.centerY,
    required this.distanceFromFocus,
  });

  final PaperStackItem paper;
  final int index;
  final double centerY;
  final double distanceFromFocus;
}

class _PositionedPaperPreview extends StatelessWidget {
  const _PositionedPaperPreview({
    required this.paper,
    required this.centerY,
    required this.scrollOffset,
    required this.viewportCenter,
    required this.paperWidth,
    required this.paperHeight,
    required this.distanceFromFocus,
    required this.onTap,
  });

  final PaperStackItem paper;
  final double centerY;
  final double scrollOffset;
  final double viewportCenter;
  final double paperWidth;
  final double paperHeight;
  final double distanceFromFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visualCenterY = centerY - scrollOffset;
    final distance = ((visualCenterY - viewportCenter).abs() / viewportCenter)
        .clamp(0.0, 1.0);
    final focus = 1 - distance;
    final paperDistance = distanceFromFocus.clamp(0.0, 2.0);
    final scale = max(0.82, 1.04 - paperDistance * 0.12);
    final widthFactor = lerpDouble(0.86, 1, focus)!;
    final shadowBlur = lerpDouble(8, 18, focus)!;
    final shadowOpacity = lerpDouble(0.12, 0.28, focus)!;

    return Positioned(
      top: centerY - paperHeight / 2,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: paperWidth * widthFactor,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: PaperPreview(
              paper: paper,
              height: paperHeight,
              shadowBlur: shadowBlur,
              shadowOpacity: shadowOpacity,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class PaperStackItem {
  const PaperStackItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.content = '',
    this.isSelected = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String content;
  final bool isSelected;

  PaperStackItem copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    String? content,
    bool? isSelected,
  }) {
    return PaperStackItem(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

@visibleForTesting
class PaperPreview extends StatelessWidget {
  const PaperPreview({
    super.key,
    required this.paper,
    required this.height,
    required this.shadowBlur,
    required this.shadowOpacity,
    this.onTap,
  });

  final PaperStackItem paper;
  final double height;
  final double shadowBlur;
  final double shadowOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatShortDate(paper.createdAt);

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(7)),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: const BorderRadius.all(Radius.circular(7)),
              boxShadow: [
                BoxShadow(
                  color: Color(
                    0xFF000000,
                  ).withValues(alpha: paper.isSelected ? 0.32 : shadowOpacity),
                  blurRadius: paper.isSelected ? 20 : shadowBlur,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF28241F),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF756D63),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
