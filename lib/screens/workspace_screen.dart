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
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'WorkspaceShortcuts',
  );

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
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  void _addPaper() {
    final createdAt = DateTime.now();

    setState(() {
      for (var index = 0; index < _papers.length; index += 1) {
        _papers[index] = _papers[index].copyWith(isSelected: false);
      }

      _papers.add(
        PaperStackItem(
          title: _nextPaperTitle(),
          createdAt: createdAt,
          isSelected: true,
        ),
      );
      _papers.sort(
        (first, second) => first.createdAt.compareTo(second.createdAt),
      );
    });
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
          isSelected: paper.createdAt == selectedPaper.createdAt,
        );
      }
    });
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _shortcutFocusNode.requestFocus,
            child: Scaffold(
              body: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
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
                    const Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFF1E9DD)),
                      ),
                    ),
                  ],
                ),
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
  static const double _paperWidthFactor = 0.82;
  static const double _paperStrideFactor = 1.13;

  late final ScrollController _scrollController;
  bool _isSnapping = false;
  bool _shouldAlignSelectedPaper = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
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
        final paperWidth = max(1.0, constraints.maxWidth * _paperWidthFactor);
        final paperHeight = paperWidth * _a4HeightRatio;
        final paperStride = paperHeight * _paperStrideFactor;
        final viewportHeight = constraints.maxHeight;
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
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              if (!_isSnapping) {
                _snapToNearestPaper(paperStride);
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
                              top: verticalInset + index * paperStride,
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
                            top: layout.top,
                            scrollOffset: scrollOffset,
                            viewportCenter: viewportCenter,
                            paperWidth: paperWidth,
                            paperHeight: paperHeight,
                            distanceFromFocus: layout.distanceFromFocus,
                            onTap: () {
                              _snapToPaper(layout.index, paperStride);
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

    final nearestIndex = (_scrollController.offset / paperStride)
        .round()
        .clamp(0, widget.papers.length - 1)
        .toInt();

    widget.onPaperSelected?.call(widget.papers[nearestIndex]);
    _snapToPaper(nearestIndex, paperStride, selectPaper: false);
  }

  void _snapToPaper(int index, double paperStride, {bool selectPaper = true}) {
    if (!_scrollController.hasClients || widget.papers.isEmpty) {
      return;
    }

    if (selectPaper) {
      widget.onPaperSelected?.call(widget.papers[index]);
    }

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final targetOffset = (index * paperStride)
        .clamp(0.0, maxScrollExtent)
        .toDouble();

    if ((_scrollController.offset - targetOffset).abs() < 0.5) {
      return;
    }

    _isSnapping = true;
    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted) {
            _isSnapping = false;
          }
        });
  }
}

class _PaperStackLayout {
  const _PaperStackLayout({
    required this.paper,
    required this.index,
    required this.top,
    required this.distanceFromFocus,
  });

  final PaperStackItem paper;
  final int index;
  final double top;
  final double distanceFromFocus;
}

class _PositionedPaperPreview extends StatelessWidget {
  const _PositionedPaperPreview({
    required this.paper,
    required this.top,
    required this.scrollOffset,
    required this.viewportCenter,
    required this.paperWidth,
    required this.paperHeight,
    required this.distanceFromFocus,
    required this.onTap,
  });

  final PaperStackItem paper;
  final double top;
  final double scrollOffset;
  final double viewportCenter;
  final double paperWidth;
  final double paperHeight;
  final double distanceFromFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paperCenter = top - scrollOffset + paperHeight / 2;
    final distance = ((paperCenter - viewportCenter).abs() / viewportCenter)
        .clamp(0.0, 1.0);
    final focus = 1 - distance;
    final paperDistance = distanceFromFocus.clamp(0.0, 2.0);
    final scale = max(0.88, 1.08 - paperDistance * 0.14);
    final widthFactor = lerpDouble(0.86, 1, focus)!;
    final shadowBlur = lerpDouble(8, 18, focus)!;
    final shadowOpacity = lerpDouble(0.12, 0.28, focus)!;

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: paperWidth * widthFactor,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
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
    required this.title,
    required this.createdAt,
    this.isSelected = false,
  });

  final String title;
  final DateTime createdAt;
  final bool isSelected;

  PaperStackItem copyWith({
    String? title,
    DateTime? createdAt,
    bool? isSelected,
  }) {
    return PaperStackItem(
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
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
