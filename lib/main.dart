import 'package:flutter/material.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/shiritori_game_screen.dart';

void main() {
  runApp(const ShiritoriApp());
}

class ShiritoriApp extends StatelessWidget {
  const ShiritoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '最強しりとりAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const ShiritoriGameScreen(),
    );
  }
}
