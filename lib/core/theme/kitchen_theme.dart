import 'package:flutter/material.dart';

/// Material 3 Expressive Theme - Tone Cam Ấm (Warm Orange Palette)
/// Tối ưu hóa cho trải nghiệm cảm ứng trên Máy tính bảng & Điện thoại
class KitchenTheme {
  // Bảng màu Material 3 Expressive (Đã đồng bộ sang Tone Xanh Dương của Admin)
  static const Color primaryOrange = Color(0xFF0061A4); // Xanh dương Sapphire chủ đạo
  static const Color primaryDarkOrange = Color(0xFF001F3E); // Xanh navy đậm cho text & accent
  static const Color secondaryOrange = Color(0xFF007ACC); // Xanh biển tươi sáng
  static const Color lightOrangeContainer = Color(0xFFD6E3FF); // Container xanh nhạt expressive
  static const Color orangeTint = Color(0xFFF0F5FF); // Nền phụ xanh băng nhạt
  static const Color bgExpressiveOrange = Color(0xFFF6F9FE); // Nền ứng dụng xanh nhạt dịu mát
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Thẻ / Card trắng
  static const Color accentAmber = Color(0xFF0284C7); // Accent xanh cyan tươi
  static const Color textDarkOrange = Color(0xFF0F172A); // Chữ navy đậm
  static const Color textMutedOrange = Color(0xFF475569); // Chữ xám xanh phụ
  static const Color borderOrange = Color(0xFFD8E2F0); // Viền xanh xám nhạt

  // Status colors cho Kitchen
  static const Color pendingBlue = Color(0xFF1565C0);
  static const Color cookingOrange = Color(0xFFE65100);
  static const Color doneGreen = Color(0xFF2E7D32);
  static const Color overtimeRed = Color(0xFFC62828);

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryOrange,
      primary: primaryOrange,
      onPrimary: Colors.white,
      primaryContainer: lightOrangeContainer,
      onPrimaryContainer: primaryDarkOrange,
      secondary: secondaryOrange,
      onSecondary: Colors.white,
      secondaryContainer: orangeTint,
      onSecondaryContainer: primaryDarkOrange,
      tertiary: accentAmber,
      surface: surfaceWhite,
      onSurface: textDarkOrange,
      onSurfaceVariant: textMutedOrange,
      outline: borderOrange,
      outlineVariant: const Color(0xFFEDE7E0),
      error: const Color(0xFFBA1A1A),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgExpressiveOrange,
      
      // Material 3 Touch Target Optimization
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,

      // AppBar Styling Expressive Orange
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryOrange,
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
        selectedIconTheme: const IconThemeData(color: primaryOrange, size: 26),
        unselectedIconTheme: const IconThemeData(color: textMutedOrange, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: primaryOrange,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textMutedOrange,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: lightOrangeContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        minWidth: 76,
      ),

      // NavigationDrawer Styling
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: surfaceWhite,
        indicatorColor: lightOrangeContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryOrange, size: 24);
          }
          return const IconThemeData(color: textMutedOrange, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryOrange, fontWeight: FontWeight.bold, fontSize: 14);
          }
          return const TextStyle(color: textMutedOrange, fontSize: 14);
        }),
      ),

      // Material 3 Expressive Card Styling
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: primaryOrange.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderOrange, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      // TabBar Styling
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryOrange,
        unselectedLabelColor: textMutedOrange,
        indicatorColor: primaryOrange,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      // Chip Styling - Tối ưu nút bấm cảm ứng
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWhite,
        disabledColor: const Color(0xFFF5F0EB),
        selectedColor: primaryOrange,
        secondarySelectedColor: lightOrangeContainer,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDarkOrange),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: borderOrange, width: 0.8),
        elevation: 0,
        pressElevation: 2,
      ),

      // Buttons Styling (Đạt chuẩn tối thiểu 48px touch target)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryOrange.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOrange,
          side: const BorderSide(color: primaryOrange, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      // Input / TextFormField Styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: borderOrange),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: borderOrange),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
        labelStyle: const TextStyle(color: textMutedOrange, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFFA08C7D), fontSize: 14),
      ),

      // Dialog Styling M3 Expressive
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: borderOrange, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          color: textDarkOrange,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // FloatingActionButton Styling Expressive M3
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
