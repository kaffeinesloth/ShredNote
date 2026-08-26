import 'package:flutter/material.dart';

import 'screens/workspace_screen.dart';

class ShredNoteApp extends StatelessWidget {
  const ShredNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShredNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A5C3E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F0E8),
        useMaterial3: true,
      ),
      home: const WorkspaceScreen(),
    );
  }
}
