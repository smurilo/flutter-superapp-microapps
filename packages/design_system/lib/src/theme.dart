import 'package:flutter/material.dart';

abstract final class DsColors {
  static const primary = Color(0xFF1F3864);
  static const credit = Color(0xFF1B7F4F);
  static const debit = Color(0xFFB3261E);
}

abstract final class DsTheme {
  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: DsColors.primary),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: DsColors.primary, brightness: Brightness.dark),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}
