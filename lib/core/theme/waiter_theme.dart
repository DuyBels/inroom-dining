import 'package:flutter/material.dart';

/// Material 3 Expressive Theme - Tone Xanh Lá (Emerald Green Palette)
/// Tối ưu hóa cho trải nghiệm cảm ứng trên Máy tính bảng & Điện thoại
class WaiterTheme {
  // Bảng màu Material 3 Expressive (Đã đồng bộ sang Tone Xanh Dương của Admin)
  static const Color primaryGreen = Color(0xFF0061A4); // Xanh dương Sapphire chủ đạo
  static const Color primaryDarkGreen = Color(0xFF001F3E); // Xanh navy đậm cho text & accent
  static const Color secondaryGreen = Color(0xFF007ACC); // Xanh biển tươi sáng
  static const Color lightGreenContainer = Color(0xFFD6E3FF); // Container xanh nhạt expressive
  static const Color greenTint = Color(0xFFF0F5FF); // Nền phụ xanh nhạt
  static const Color bgExpressiveGreen = Color(0xFFF6F9FE); // Nền ứng dụng xanh nhạt dịu
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Thẻ / Card trắng
  static const Color accentTeal = Color(0xFF0284C7); // Accent teal tươi
  static const Color textDarkGreen = Color(0xFF0F172A); // Chữ xanh đậm
  static const Color textMutedGreen = Color(0xFF475569); // Chữ xám xanh phụ
  static const Color borderGreen = Color(0xFFD8E2F0); // Viền xanh xám nhạt

  // Status colors cho Waiter
  static const Color readyGreen = Color(0xFF2E7D32);
  static const Color cookingOrange = Color(0xFFE65100);
  static const Color deliveryBlue = Color(0xFF1565C0);
  static const Color serviceColor = Color(0xFF6A1B9A);
  static const Color cleaningColor = Color(0xFF0277BD);

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: lightGreenContainer,
      onPrimaryContainer: primaryDarkGreen,
      secondary: secondaryGreen,
      onSecondary: Colors.white,
      secondaryContainer: greenTint,
      onSecondaryContainer: primaryDarkGreen,
      tertiary: accentTeal,
      surface: surfaceWhite,
      onSurface: textDarkGreen,
      onSurfaceVariant: textMutedGreen,
      outline: borderGreen,
      outlineVariant: const Color(0xFFDDE8DE),
      error: const Color(0xFFBA1A1A),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgExpressiveGreen,
      
      // Material 3 Touch Target Optimization
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,

      // AppBar Styling Expressive Green
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
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
        selectedIconTheme: const IconThemeData(color: primaryGreen, size: 26),
        unselectedIconTheme: const IconThemeData(color: textMutedGreen, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textMutedGreen,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: lightGreenContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        minWidth: 76,
      ),

      // NavigationDrawer Styling
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: surfaceWhite,
        indicatorColor: lightGreenContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryGreen, size: 24);
          }
          return const IconThemeData(color: textMutedGreen, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 14);
          }
          return const TextStyle(color: textMutedGreen, fontSize: 14);
        }),
      ),

      // Material 3 Expressive Card Styling
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 2,
        shadowColor: primaryGreen.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderGreen, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      // TabBar Styling
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryGreen,
        unselectedLabelColor: textMutedGreen,
        indicatorColor: primaryGreen,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      // Chip Styling - Tối ưu nút bấm cảm ứng
      chipTheme: ChipThemeData(
        backgroundColor: surfaceWhite,
        disabledColor: const Color(0xFFF0F5F0),
        selectedColor: primaryGreen,
        secondarySelectedColor: lightGreenContainer,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDarkGreen),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: borderGreen, width: 0.8),
        elevation: 0,
        pressElevation: 2,
      ),

      // Buttons Styling (Đạt chuẩn tối thiểu 48px touch target)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primaryGreen.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
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
          borderSide: const BorderSide(color: borderGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: borderGreen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
        labelStyle: const TextStyle(color: textMutedGreen, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF8CA88E), fontSize: 14),
      ),

      // Dialog Styling M3 Expressive
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: borderGreen, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          color: textDarkGreen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // FloatingActionButton Styling Expressive M3
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
