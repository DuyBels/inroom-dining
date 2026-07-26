import 'package:flutter/material.dart';

/// Material 3 Expressive Theme - Tone Xanh Dương (Expressive Blue Palette)
/// Tối ưu hóa cho trải nghiệm cảm ứng trên Máy tính bảng & Điện thoại
class AdminTheme {
  // Bảng màu Material 3 Expressive Tone Xanh Dương
  static const Color primaryBlue = Color(0xFF0061A4); // Xanh dương Sapphire chủ đạo
  static const Color primaryDarkBlue = Color(0xFF001F3E); // Xanh navy đậm cho text & accent
  static const Color secondaryBlue = Color(0xFF007ACC); // Xanh biển tươi sáng
  static const Color lightBlueContainer = Color(0xFFD6E3FF); // Container xanh nhạt expressive
  static const Color blueTint = Color(0xFFF0F5FF); // Nền phụ xanh băng nhạt
  static const Color bgExpressiveBlue = Color(0xFFF6F9FE); // Nền ứng dụng xanh nhạt dịu mát
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Thẻ / Card trắng tinh khiết
  static const Color accentBlueCyan = Color(0xFF0284C7); // Accent xanh cyan tươi
  static const Color textDarkBlue = Color(0xFF0F172A); // Chữ navy đậm
  static const Color textMutedBlue = Color(0xFF475569); // Chữ xám xanh phụ
  static const Color borderBlue = Color(0xFFD8E2F0); // Viền xanh xám nhạt

  // Aliases tương thích ngược để không làm gãy code cũ
  static const Color primaryWood = primaryBlue;
  static const Color primaryDarkWood = primaryDarkBlue;
  static const Color secondaryWood = secondaryBlue;
  static const Color lightWoodCream = lightBlueContainer;
  static const Color woodTint = blueTint;
  static const Color bgWarmWhite = bgExpressiveBlue;
  static const Color accentAmber = accentBlueCyan;
  static const Color textDarkWood = textDarkBlue;
  static const Color textMutedWood = textMutedBlue;
  static const Color borderWood = borderBlue;

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      onPrimary: Colors.white,
      primaryContainer: lightBlueContainer,
      onPrimaryContainer: primaryDarkBlue,
      secondary: secondaryBlue,
      onSecondary: Colors.white,
      secondaryContainer: blueTint,
      onSecondaryContainer: primaryDarkBlue,
      tertiary: accentBlueCyan,
      surface: surfaceWhite,
      onSurface: textDarkBlue,
      onSurfaceVariant: textMutedBlue,
      outline: borderBlue,
      outlineVariant: const Color(0xFFE2E8F0),
      error: const Color(0xFFBA1A1A),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgExpressiveBlue,
      
      // Material 3 Touch Target Optimization
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,

      // AppBar Styling Expressive Blue
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white, size: 24),
        actionsIconTheme: IconThemeData(color: Colors.white, size: 24),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),

      // NavigationRail Styling (Tối ưu cảm ứng máy tính bảng)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceWhite,
        selectedIconTheme: const IconThemeData(color: primaryBlue, size: 26),
        unselectedIconTheme: const IconThemeData(color: textMutedBlue, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textMutedBlue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: lightBlueContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        minWidth: 76,
      ),

      // NavigationDrawer Styling
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: surfaceWhite,
        indicatorColor: lightBlueContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryBlue, size: 24);
          }
          return const IconThemeData(color: textMutedBlue, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14);
          }
          return const TextStyle(color: textMutedBlue, fontSize: 14);
        }),
      ),

      // Material 3 Expressive Card Styling
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: primaryBlue.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderBlue, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      // TabBar Styling
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryBlue,
        unselectedLabelColor: textMutedBlue,
        indicatorColor: primaryBlue,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      // Chip Styling (ChoiceChip / FilterChip) - Tối ưu nút bấm cảm ứng
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWhite,
        disabledColor: const Color(0xFFF1F5F9),
        selectedColor: primaryBlue,
        secondarySelectedColor: lightBlueContainer,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDarkBlue),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: borderBlue, width: 0.8),
        elevation: 0,
        pressElevation: 2,
      ),

      // Buttons Styling (Đạt chuẩn tối thiểu 48px touch target)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryBlue.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      // Input / TextFormField Styling Expressive Blue
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: borderBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
        labelStyle: const TextStyle(color: textMutedBlue, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),

      // Dialog Styling M3 Expressive
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: borderBlue, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          color: textDarkBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // DataTable Styling
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(lightBlueContainer),
        headingTextStyle: const TextStyle(
          color: primaryDarkBlue,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        dataTextStyle: const TextStyle(
          color: textDarkBlue,
          fontSize: 13,
        ),
        dividerThickness: 0.8,
        horizontalMargin: 16,
        columnSpacing: 20,
      ),

      // FloatingActionButton Styling Expressive M3
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

