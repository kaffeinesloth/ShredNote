import 'package:flutter/material.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF20272A)),
                child: _NotesSidebar(),
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFF1E9DD)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesSidebar extends StatelessWidget {
  const _NotesSidebar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ShredNote',
                  style: TextStyle(
                    color: Color(0xFFF7EFE2),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: null,
                icon: Icon(Icons.add),
                tooltip: 'New note',
                color: Color(0xFFF7EFE2),
                disabledColor: Color(0xFFF7EFE2),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Papers',
            style: TextStyle(
              color: Color(0xFFB9C0BD),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                _PaperPreview(
                  title: 'Songwriting Ideas',
                  preview: 'Verse melody, chorus hook, and rough bridge notes.',
                  isActive: true,
                ),
                _PaperPreview(
                  title: 'Practice Log',
                  preview: 'Scales, timing drills, and progress notes.',
                ),
                _PaperPreview(
                  title: 'Gear Checklist',
                  preview: 'Strings, picks, tuner, cable, and backup notes.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperPreview extends StatelessWidget {
  const _PaperPreview({
    required this.title,
    required this.preview,
    this.isActive = false,
  });

  final String title;
  final String preview;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFFFF8EA) : Color(0xFFE9DDCC),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: isActive ? Color(0xFFD8B66E) : Color(0xFFCDBFAE),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF2D2A26),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF68615A),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
