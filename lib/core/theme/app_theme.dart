import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Couleurs
  static const Color marineBlue = Color(0xFF0A192F);
  static const Color gold = Color(0xFFD4AF37);
  static const Color offWhite = Color(0xFFFAFAFA);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFED6C02);
  static const Color emeraldGreen = Color(0xFF00A86B); // Jade/Emerald Premium

  // Thème principal
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: offWhite,
      colorScheme: ColorScheme.fromSeed(
        seedColor: marineBlue,
        primary: marineBlue,
        secondary: gold,
        surface: offWhite,
        error: errorRed,
        onSurface: Colors.black87, // Explicit text color on surfaces
        onPrimary: Colors.white,
        onSecondary: marineBlue,
      ),
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: marineBlue,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Input Theme - FIXED FOR PROPER CONTRAST
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        // Text styles
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        floatingLabelStyle: TextStyle(color: marineBlue, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Colors.black38),
        helperStyle: const TextStyle(color: Colors.black54),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        // Icon colors
        prefixIconColor: marineBlue,
        suffixIconColor: Colors.black54,
        // Borders
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: marineBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Text Selection Theme - FIX INPUT TEXT COLOR
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: marineBlue,
        selectionColor: Color(0x40D4AF37), // Gold with opacity
        selectionHandleColor: gold,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: marineBlue,
        ),
        titleLarge: GoogleFonts.montserrat(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: marineBlue,
        ),
        titleMedium: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87, // For Step titles
        ),
        bodyLarge: GoogleFonts.lato(
          fontSize: 16,
          color: Colors.black87,
        ),
        bodyMedium: GoogleFonts.lato(
          fontSize: 14,
          color: Colors.black87,
        ),
        labelLarge: GoogleFonts.lato(
          fontSize: 14,
          color: Colors.black87, // For form labels
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: marineBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: marineBlue,
        ),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return gold;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(marineBlue),
      ),

      // ListTile Theme
      listTileTheme: const ListTileThemeData(
        textColor: Colors.black87,
        subtitleTextStyle: TextStyle(color: Colors.black54),
      ),
    );
  }

  // Thème Sombre (V3.5)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212), // OLED Black
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: marineBlue,
        primary: gold, // Gold devient la primaire en dark mode
        secondary: marineBlue,
        surface: const Color(0xFF1E1E1E),
        error: errorRed,
        onSurface: Colors.white,
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600, color: gold),
        iconTheme: const IconThemeData(color: gold),
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.white),
        titleLarge: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.white),
        // Forcing slightly darker text in dark mode if it's rendered on light backgrounds (as some screens do)
        // This is a safety measure for the current app state
        bodyLarge: GoogleFonts.lato(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.lato(fontSize: 14, color: Colors.white70),
      ),

      // Input Theme for Dark Mode - MUST OVERRIDE TEXT COLOR
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: gold, width: 2)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: marineBlue, // Texte foncé sur bouton or
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static const Color white = Colors.white;
}
