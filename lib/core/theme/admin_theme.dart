import 'package:flutter/material.dart';

/// Admin Theme - Material 3 Tone Trắng Nâu Gỗ (White & Warm Wood)
class AdminTheme {
  // Bảng màu Tone Trắng Nâu Gỗ
  static const Color primaryWood = Color(0xFF5D4037); // Nâu gỗ sẫm chủ đạo
  static const Color primaryDarkWood = Color(0xFF3E2723); // Nâu gỗ đậm
  static const Color secondaryWood = Color(0xFF8D6E63); // Nâu gỗ ấm vừa
  static const Color lightWoodCream = Color(0xFFEFEBE9); // Trắng kem gỗ nhạt
  static const Color woodTint = Color(0xFFF5F0EB); // Nền phụ gỗ nhạt
  static const Color bgWarmWhite = Color(0xFFFBF8F5); // Nền ứng dụng trắng ấm
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Thẻ / Card trắng
  static const Color accentAmber = Color(0xFFC87D55); // Cam hổ phách / Gỗ ấm
  static const Color textDarkWood = Color(0xFF2C1E1A); // Chữ nâu đen đậm
  static const Color textMutedWood = Color(0xFF6D4C41); // Chữ nâu phụ
  static const Color borderWood = Color(0xFFE0D7D0); // Viền gỗ nhạt

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryWood,
      primary: primaryWood,
      onPrimary: Colors.white,
      primaryContainer: lightWoodCream,
      onPrimaryContainer: primaryDarkWood,
      secondary: secondaryWood,
      onSecondary: Colors.white,
      secondaryContainer: woodTint,
      onSecondaryContainer: primaryDarkWood,
      tertiary: accentAmber,
      surface: surfaceWhite,
      onSurface: textDarkWood,
      onSurfaceVariant: textMutedWood,
      outline: borderWood,
      outlineVariant: const Color(0xFFEDE5DE),
      error: const Color(0xFFB00020),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgWarmWhite,
      
      // AppBar Styling
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryWood,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),

      // NavigationRail Styling
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceWhite,
        selectedIconTheme: const IconThemeData(color: primaryWood, size: 24),
        unselectedIconTheme: const IconThemeData(color: textMutedWood, size: 22),
        selectedLabelTextStyle: const TextStyle(
          color: primaryWood,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textMutedWood,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: lightWoodCream,
        elevation: 1,
      ),

      // NavigationDrawer Styling
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: surfaceWhite,
        indicatorColor: lightWoodCream,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryWood);
          }
          return const IconThemeData(color: textMutedWood);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryWood, fontWeight: FontWeight.bold, fontSize: 13);
          }
          return const TextStyle(color: textMutedWood, fontSize: 13);
        }),
      ),

      // Card Styling
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 1.5,
        shadowColor: primaryDarkWood.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderWood, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      // TabBar Styling
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryWood,
        unselectedLabelColor: textMutedWood,
        indicatorColor: primaryWood,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),

      // Buttons Styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryWood,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryWood,
          side: const BorderSide(color: primaryWood, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryWood,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Input / TextFormField Styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderWood),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderWood),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryWood, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB00020)),
        ),
        labelStyle: const TextStyle(color: textMutedWood, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFFA1887F), fontSize: 13),
      ),

      // Dialog Styling
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderWood, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          color: textDarkWood,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // DataTable Styling
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(lightWoodCream),
        headingTextStyle: const TextStyle(
          color: primaryDarkWood,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        dataTextStyle: const TextStyle(
          color: textDarkWood,
          fontSize: 13,
        ),
        dividerThickness: 0.8,
        horizontalMargin: 16,
        columnSpacing: 20,
      ),

      // FloatingActionButton Styling
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryWood,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
