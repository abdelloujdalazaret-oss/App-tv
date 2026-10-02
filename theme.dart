import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E131C);
  static const field = Color(0xFF182131);
  static const accent = Color(0xFF14B8A6);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(primary: AppColors.accent, surface: AppColors.bg);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: shape, minimumSize: const Size(48, 48))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: shape, minimumSize: const Size(48, 48))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.field,
      indicatorColor: AppColors.accent.withOpacity(.25),
    ),
    listTileTheme: ListTileThemeData(shape: shape),
    dividerColor: Colors.white12,
  );
}

/// Décoration arrondie (12 px) utilisée pour les cartes.
BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(12),
      border: selected ? Border.all(color: AppColors.accent, width: 1.5) : null,
    );
