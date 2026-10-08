// Стиль приложения: тёплая «кофейная» палитра, мягкие тени, скругления.

import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF5EFE8); // сливочный фон
  static const surface = Color(0xFFFFFCF8); // карточки
  static const espresso = Color(0xFF3B2A22); // основной тёмный
  static const caramel = Color(0xFFC68B59); // акцент
  static const latte = Color(0xFFEADBCB); // мягкий акцент / плашки
  static const text = Color(0xFF2B211C);
  static const muted = Color(0xFF8C7B70);
  static const line = Color(0xFFE8DED4);
}

class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x143B2A22), blurRadius: 18, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A3B2A22), blurRadius: 4, offset: Offset(0, 1)),
  ];
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.caramel,
    primary: AppColors.espresso,
    secondary: AppColors.caramel,
    surface: AppColors.surface,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.espresso,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
      elevation: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.espresso,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.espresso,
        side: const BorderSide(color: AppColors.line, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.espresso,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.caramel, width: 1.6)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.espresso,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}

/// Белая карточка с мягкой тенью.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const SoftCard({super.key, required this.child, this.padding, this.radius = 18});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppShadows.soft,
        ),
        child: child,
      );
}

/// Заголовок раздела: «СОСТАВ» мелкими буквами с акцентной чертой.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 18, height: 3, decoration: BoxDecoration(color: AppColors.caramel, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text.toUpperCase(),
              style: const TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ]),
      );
}
