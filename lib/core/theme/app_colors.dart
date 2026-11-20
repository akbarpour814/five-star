import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF041E4F);
  static const primaryDark = Color(0xFF062A6B);
  static const primary = Color(0xFF0D47A1);
  static const primaryLight = Color(0xFF1976D2);
  static const sky = Color(0xFF42A5F5);
  static const ice = Color(0xFFE3F0FF);
  static const background = Color(0xFFF2F6FC);
  static const surface = Colors.white;
  static const brandRed = Color(0xFFE31E24);
  static const success = Color(0xFF2E9D57);
  static const warning = Color(0xFFF2A516);
  static const danger = Color(0xFFE53935);
  static const textPrimary = Color(0xFF0F1E3D);
  static const textSecondary = Color(0xFF5B6B86);
  static const divider = Color(0xFFE1E8F3);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy, primary, primaryLight],
    stops: [0, 0.55, 1],
  );

  static const buttonGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [primary, primaryLight],
  );
}
