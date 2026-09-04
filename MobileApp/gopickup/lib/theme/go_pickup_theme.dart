import 'package:flutter/material.dart';

class GoPickupColors {
  static const verde = Color(0xFF3AAA35);
  static const verdeOscuro = Color(0xFF2C8028);
  static const blanco = Color(0xFFFFFFFF);
  static const grisTexto = Color(0xFF1F2937);
  static const grisFondo = Color(0xFFF4F6F8);
}

class GoPickupTheme {
  static ThemeData get tema {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: GoPickupColors.verde,
      scaffoldBackgroundColor: GoPickupColors.grisFondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: GoPickupColors.verde,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GoPickupColors.verde,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GoPickupColors.verdeOscuro,
          side: const BorderSide(color: GoPickupColors.verde),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
