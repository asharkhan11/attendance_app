import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design_system/attendance_theme.dart';

class AppTheme {
  AppTheme._();

  // ─── Light Palette ─────────────────────────────────────────────────────────
  static const Color _primaryLight = Color(0xFF4F46E5); // Indigo 600
  static const Color _secondaryLight = Color(0xFF0EA5E9); // Sky 500
  static const Color _backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color _textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color _textMutedLight = Color(0xFF94A3B8); // Slate 400
  static const Color _borderLight = Color(0xFFE2E8F0); // Slate 200

  // ─── Dark Palette ──────────────────────────────────────────────────────────
  static const Color _primaryDark = Color(0xFF818CF8); // Indigo 400
  static const Color _secondaryDark = Color(0xFF38BDF8); // Sky 400
  static const Color _backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color _surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color _surfaceVariantDark = Color(0xFF334155); // Slate 700
  static const Color _textPrimaryDark = Color(0xFFF1F5F9); // Slate 100
  static const Color _textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color _textMutedDark = Color(0xFF64748B); // Slate 500
  static const Color _borderDark = Color(0xFF334155); // Slate 700

  static const Color _error = Color(0xFFEF4444);
  static const Color _success = Color(0xFF10B981);

  // ─── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.bold, letterSpacing: -1.0),
        displayMedium: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.bold, letterSpacing: -0.8),
        displaySmall: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineLarge: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        headlineSmall: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleLarge: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.w500, fontSize: 16),
        titleSmall: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: _textPrimaryLight, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: _textSecondaryLight, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: _textMutedLight, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(color: _textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium: TextStyle(color: _textSecondaryLight, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall: TextStyle(color: _textMutedLight, fontWeight: FontWeight.w500, fontSize: 10),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _primaryLight,
      scaffoldBackgroundColor: _backgroundLight,
      extensions: const [AttendanceTheme.light],
      textTheme: textTheme,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _primaryLight,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFEEF2FF),
        onPrimaryContainer: Color(0xFF312E81),
        secondary: _secondaryLight,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE0F2FE),
        onSecondaryContainer: Color(0xFF0369A1),
        error: _error,
        onError: Colors.white,
        surface: _surfaceLight,
        onSurface: _textPrimaryLight,
        surfaceContainerHighest: Color(0xFFF1F5F9),
        onSurfaceVariant: _textSecondaryLight,
        outline: Color(0xFFCBD5E1),
        outlineVariant: _borderLight,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _textPrimaryLight, size: 24),
        actionsIconTheme: IconThemeData(color: _textPrimaryLight, size: 24),
      ),

      cardTheme: CardThemeData(
        color: _surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderLight, width: 1),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderLight, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderLight, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryLight, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _error, width: 2)),
        labelStyle: const TextStyle(color: _textSecondaryLight, fontSize: 14),
        hintStyle: const TextStyle(color: _textMutedLight, fontSize: 14),
        prefixIconColor: _textSecondaryLight,
        suffixIconColor: _textSecondaryLight,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryLight,
          side: const BorderSide(color: _borderLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? _primaryLight : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(color: _textPrimaryLight, fontSize: 20, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: _textSecondaryLight, fontSize: 15),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: const DividerThemeData(color: _borderLight, thickness: 1, space: 1),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceLight,
        indicatorColor: _primaryLight.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? _primaryLight : _textSecondaryLight,
          ),
        ),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: _primaryLight,
        unselectedLabelColor: _textSecondaryLight,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: _borderLight,
        indicatorColor: _primaryLight,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryLight,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: _surfaceLight,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? _primaryLight : null),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? _primaryLight.withValues(alpha: 0.4) : null),
      ),
    );
  }

  // ─── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.bold, letterSpacing: -1.0),
        displayMedium: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.bold, letterSpacing: -0.8),
        displaySmall: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineLarge: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        headlineSmall: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleLarge: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.w500, fontSize: 16),
        titleSmall: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: _textPrimaryDark, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: _textSecondaryDark, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: _textMutedDark, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(color: _textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium: TextStyle(color: _textSecondaryDark, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall: TextStyle(color: _textMutedDark, fontWeight: FontWeight.w500, fontSize: 10),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primaryDark,
      scaffoldBackgroundColor: _backgroundDark,
      extensions: const [AttendanceTheme.dark],
      textTheme: textTheme,

      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: _primaryDark,
        onPrimary: Color(0xFF1E1B4B),
        primaryContainer: Color(0xFF312E81),
        onPrimaryContainer: Color(0xFFE0E7FF),
        secondary: _secondaryDark,
        onSecondary: Color(0xFF0C4A6E),
        secondaryContainer: Color(0xFF0369A1),
        onSecondaryContainer: Color(0xFFE0F2FE),
        error: Color(0xFFF87171),
        onError: Color(0xFF7F1D1D),
        surface: _surfaceDark,
        onSurface: _textPrimaryDark,
        surfaceContainerHighest: _surfaceVariantDark,
        onSurfaceVariant: _textSecondaryDark,
        outline: Color(0xFF475569),
        outlineVariant: _borderDark,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _textPrimaryDark, size: 24),
        actionsIconTheme: const IconThemeData(color: _textPrimaryDark, size: 24),
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderDark, width: 1),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderDark, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _borderDark, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryDark, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF87171), width: 2)),
        labelStyle: const TextStyle(color: _textSecondaryDark, fontSize: 14),
        hintStyle: const TextStyle(color: _textMutedDark, fontSize: 14),
        prefixIconColor: _textSecondaryDark,
        suffixIconColor: _textSecondaryDark,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryDark,
          foregroundColor: const Color(0xFF1E1B4B),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryDark,
          side: const BorderSide(color: _borderDark, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? _primaryDark : _surfaceVariantDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: const BorderSide(color: Color(0xFF475569), width: 1.5),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(color: _textPrimaryDark, fontSize: 20, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: _textSecondaryDark, fontSize: 15),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: const DividerThemeData(color: _borderDark, thickness: 1, space: 1),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: _primaryDark.withValues(alpha: 0.20),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? _primaryDark : _textSecondaryDark,
          ),
        ),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: _primaryDark,
        unselectedLabelColor: _textSecondaryDark,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: _borderDark,
        indicatorColor: _primaryDark,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryDark,
        foregroundColor: const Color(0xFF1E1B4B),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: _surfaceDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? _primaryDark : _textMutedDark),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
            states.contains(WidgetState.selected) ? _primaryDark.withValues(alpha: 0.4) : _surfaceVariantDark),
      ),
    );
  }

  // ─── Convenience accessors (for non-theme-aware code) ────────────────────
  static const Color primary = _primaryLight;
  static const Color secondary = _secondaryLight;
  static const Color background = _backgroundLight;
  static const Color surface = _surfaceLight;
  static const Color textPrimary = _textPrimaryLight;
  static const Color textSecondary = _textSecondaryLight;
  static const Color textMuted = _textMutedLight;
  static const Color border = _borderLight;
  static const Color borderFocused = _primaryLight;
  static const Color error = _error;
  static const Color success = _success;
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        // shadowColor: primary.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
>>>>>>> main
}
