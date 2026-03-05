import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color _primaryColor = Color(0xFFE94560);
  static const Color _backgroundColor = Color(0xFF1A1A2E);
  static const Color _surfaceColor = Color(0xFF16213E);
  static const Color _cardColor = Color(0xFF0F3460);
  static const Color _textColor = Color(0xFFECECEC);
  static const Color _subtitleColor = Color(0xFF8D8D9B);
  static const Color _sentBubbleColor = Color(0xFFE94560);
  static const Color _receivedBubbleColor = Color(0xFF16213E);

  static Color get primaryColor => _primaryColor;
  static Color get backgroundColor => _backgroundColor;
  static Color get surfaceColor => _surfaceColor;
  static Color get cardColor => _cardColor;
  static Color get sentBubbleColor => _sentBubbleColor;
  static Color get receivedBubbleColor => _receivedBubbleColor;
  static Color get subtitleColor => _subtitleColor;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        surface: _surfaceColor,
        onSurface: _textColor,
      ),
      scaffoldBackgroundColor: _backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceColor,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
      cardTheme: const CardThemeData(
        color: _cardColor,
        elevation: 0,
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: _subtitleColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: _textColor),
          bodyMedium: TextStyle(color: _textColor),
          bodySmall: TextStyle(color: _subtitleColor),
          titleLarge: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: _textColor),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A4A),
        thickness: 0.5,
      ),
    );
  }
}
