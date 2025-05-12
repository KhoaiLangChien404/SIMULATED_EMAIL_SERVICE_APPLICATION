import 'package:flutter/material.dart';

class AppTheme {
  static final Color primaryColor = Colors.red;
  static final Color accentColor = Colors.redAccent;

  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
    ),
    scaffoldBackgroundColor: Colors.white,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Colors.white,
      foregroundColor: primaryColor,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: Color(0xFF202124),
      background: Color(0xFF202124),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF202124),
      elevation: 0,
    ),
    scaffoldBackgroundColor: Color(0xFF202124),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
    ),
  );
}