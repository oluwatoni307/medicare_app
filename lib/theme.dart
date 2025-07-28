import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Core Colors (HARMONIZED WITH PRIMARY BLUE BACKGROUND)
  static const Color primaryBlue = Color(0xFFDCEFFF); // Your primary blue background
  static const Color primaryAction = Color(0xFF1E40AF); // Deeper blue for actions (better contrast on blue bg)
  static const Color secondary = Color(0xFF7C3AED); // Rich purple (complements blue beautifully)
  static const Color accent = Color(0xFF059669); // Emerald green for success states
  static const Color darkText = Color(0xFF1E293B); // Slate gray (optimal contrast on blue)
  static const Color lightText = Color(0xFF64748B); // Medium slate (softer on blue background)
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards for maximum contrast
  static const Color surfaceMuted = Color(0xFFF8FAFC); // Very light blue-gray tint
  static const Color surfaceHover = Color(0xFFF1F5F9); // Slightly more blue-tinted for hover states
  static const Color error = Color(0xFFDC2626);
  
  // OPTIMIZED SPACING - More Mobile-Friendly
  static const double spacingXS = 4.0;
  static const double spacingS = 6.0;    // Reduced from 8.0
  static const double spacingM = 12.0;   // Reduced from 16.0  
  static const double spacingL = 18.0;   // Reduced from 24.0
  static const double spacingXL = 24.0;  // Reduced from 32.0
  
  // OPTIMIZED RADIUS - Less Extreme Rounding
  static const double radiusS = 6.0;     // Reduced from 8.0
  static const double radiusM = 10.0;    // Reduced from 12.0
  static const double radiusL = 14.0;    // Reduced from 16.0
  static const double radiusXL = 18.0;   // Reduced from 24.0

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Main Color Scheme (HARMONIZED WITH BLUE BACKGROUND)
      colorScheme: ColorScheme.light(
        primary: primaryAction,
        secondary: secondary,
        tertiary: accent, // Emerald green for tertiary actions
        surface: surface,
        surfaceVariant: surfaceMuted,
        background: primaryBlue, // Your blue background as primary
        onBackground: darkText,
        onSurface: darkText,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onError: Colors.white,
        error: error,
        outline: Color(0xFFCBD5E1), // Cool gray outline
        outlineVariant: Color(0xFFE2E8F0), // Lighter outline variant
      ).copyWith(
        // Material 3 surface containers (blue-harmonized)
        surfaceContainer: surfaceMuted,
        surfaceContainerLow: Color(0xFFFBFCFE), // Barely-there blue tint
        surfaceContainerHigh: surfaceHover,
        inverseSurface: Color(0xFF0F172A), // Dark slate for dark elements
        onInverseSurface: Colors.white,
      ),
      
      // Scaffold Background (PRIMARY BLUE)
      scaffoldBackgroundColor: primaryBlue,
      
      // Typography Theme (UNCHANGED - already excellent)
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: darkText,
            height: 1.2,
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: darkText,
            height: 1.2,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: darkText,
            height: 1.3,
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: darkText,
            height: 1.3,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: darkText,
            height: 1.4,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: darkText,
            height: 1.4,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: darkText,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: darkText,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: lightText,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: darkText,
            height: 1.4,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: lightText,
            height: 1.4,
          ),
        ),
      ),
      
      // App Bar Theme (ADJUSTED for blue background)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        iconTheme: IconThemeData(
          color: darkText,
          size: 24,
        ),
      ),
      
      // Card Theme (OPTIMIZED MARGINS)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2, // Subtle shadow for depth
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        margin: const EdgeInsets.all(4.0), // Reduced from 8.0
      ),
      
      // Elevated Button Theme (OPTIMIZED PADDING)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAction,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0, // Reduced from spacingL (24.0)
            vertical: 10.0,   // Reduced from spacingM (16.0)
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Outlined Button Theme (HARMONIZED WITH BLUE BACKGROUND)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: BorderSide(color: Color(0xFFCBD5E1).withOpacity(0.6)), // Softer border on blue
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 10.0,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Text Button Theme (HARMONIZED COLORS)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAction, // Use primary action color instead of secondary
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0, // Reduced from spacingL (24.0)
            vertical: 10.0,   // Reduced from spacingM (16.0)
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Floating Action Button Theme (OPTIMIZED RADIUS)
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAction,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusL)),
        ),
      ),
      
      // Input Decoration Theme (OPTIMIZED PADDING)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface, // Pure white (NO TRANSPARENCY)
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: primaryAction, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0, // Reduced from spacingM (16.0)
          vertical: 12.0,   // Reduced from spacingM (16.0)
        ),
        hintStyle: TextStyle(
          color: lightText,
          fontSize: 16,
        ),
      ),
      
      // Icon Theme (UNCHANGED)
      iconTheme: const IconThemeData(
        color: darkText,
        size: 24,
      ),
      
      // Divider Theme (HARMONIZED WITH BLUE)
      dividerTheme: DividerThemeData(
        color: Color(0xFFE2E8F0), // Cooler gray that works on blue
        thickness: 1,
        space: 1,
      ),
      
      // Bottom Navigation Bar Theme (ADJUSTED for blue)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryAction,
        unselectedItemColor: lightText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      ),
      
      // Tab Bar Theme (ADDED for medication list tabs)
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: darkText,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusM),
          color: primaryAction,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      
      // Switch Theme (HARMONIZED COLORS)
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return accent; // Use emerald green for positive actions
            }
            return Color(0xFF94A3B8); // Cooler gray for inactive
          },
        ),
        trackColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return accent.withOpacity(0.3);
            }
            return Color(0xFFE2E8F0); // Cool gray track
          },
        ),
      ),
      
      // Checkbox Theme (OPTIMIZED RADIUS)
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return primaryAction;
            }
            return Colors.transparent;
          },
        ),
        checkColor: MaterialStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3.0), // Reduced from radiusS/2
        ),
      ),
      
      // Snackbar Theme (OPTIMIZED RADIUS)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkText,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),
      
      // Dialog Theme (OPTIMIZED RADIUS)
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        elevation: 16,
      ),
      
      // Chip Theme (HARMONIZED WITH BLUE BACKGROUND)
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHover, // Slightly blue-tinted background
        selectedColor: primaryAction.withOpacity(0.1),
        disabledColor: Color(0xFFF1F5F9),
        secondarySelectedColor: secondary.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(
          horizontal: 8.0,
          vertical: 4.0,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: darkText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        side: BorderSide(
          color: Color(0xFFE2E8F0).withOpacity(0.5),
          width: 1,
        ),
      ),
      
      // List Tile Theme (ADDED for medication cards)
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 4.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
    );
  }
}