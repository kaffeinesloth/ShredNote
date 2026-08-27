import 'dart:async';
import 'dart:math' show max, min;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final List<PaperStackItem> _papers = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _editorController = TextEditingController();
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'WorkspaceShortcuts',
  );
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
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const AddPaperIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AddPaperIntent: CallbackAction<AddPaperIntent>(
            onInvoke: (intent) {
              _addPaper();
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
                        onTitleChanged: _updateSelectedPaperTitle,
                        onContentChanged: _updateSelectedPaperContent,
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
    required this.onTitleChanged,
    required this.onContentChanged,
  });

  final PaperStackItem? paper;
  final TextEditingController titleController;
  final TextEditingController controller;
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

  late final ScrollController _scrollController;
  Timer? _snapDebounceTimer;
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
