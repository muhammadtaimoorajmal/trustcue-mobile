import 'package:flutter/material.dart';
import 'package:trustcue_mobile/core/theme/app_theme.dart';
import 'package:trustcue_mobile/features/home/presentation/screens/home_screen.dart';

class TrustCueApp extends StatelessWidget {
  const TrustCueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustCue',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(title: 'TrustCue'),
    );
  }
}
