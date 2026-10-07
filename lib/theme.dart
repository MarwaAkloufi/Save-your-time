
import 'package:flutter/material.dart';

class C {
  C._();

  static const Color primary = Color(0xFF1E5E2F);
  static const Color primaryLight = Color(0xFF3A7D34);
  static const Color gold = Color(0xFFE0A526);
  static const Color cream = Color(0xFFFFF4D6);
  static const Color splashTop = Color(0xFF6B7634);
  static const Color splashMid = Color(0xFF3F6B30);

  static const Color bg = Color(0xFFF6F5EE);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1F2A22);
  static const Color textSoft = Color(0xFF5B665E);
  static const Color border = Color(0xFFDCE3DD);
  static const Color error = Color(0xFFC62828);

  // ألوان الأقسام (نفس ألوان أزرار التطبيق)
  static const Color products = Color(0xFF1B7F3B);
  static const Color productsBg = Color(0xFFE6F4EA);
  static const Color info = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE3F2FD);
  static const Color ideas = Color(0xFFA8690A);
  static const Color ideasBg = Color(0xFFFFF3D6);
  static const Color story = Color(0xFFC2410C);
  static const Color storyBg = Color(0xFFFBE9E1);
  static const Color poll = Color(0xFF6A1B9A);
  static const Color pollBg = Color(0xFFF3E5F5);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.primary,
    primary: C.primary,
    brightness: Brightness.light,
  );

  OutlineInputBorder border(Color color, [double w = 1.2]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(C.border),
      enabledBorder: border(C.border),
      focusedBorder: border(C.primary, 2),
      labelStyle: const TextStyle(color: C.textSoft, fontSize: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: const TextStyle(
            fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(
            fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
