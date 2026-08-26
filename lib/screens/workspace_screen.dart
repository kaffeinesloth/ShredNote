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
