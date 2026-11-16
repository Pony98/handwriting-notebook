import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'features/home/home_screen.dart';

class HandwritingNotebookApp extends StatelessWidget {
  const HandwritingNotebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handwriting Notebook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const HomeScreen(),
    );
  }
}
