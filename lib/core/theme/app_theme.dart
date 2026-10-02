// Defines the shared visual theme used throughout the PetCare application.

import 'package:flutter/material.dart';

/// Defines the shared Material 3 color scheme and scaffold styling.
class AppTheme {
  /// Builds the application's shared Material 3 theme.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    );
  }
}
