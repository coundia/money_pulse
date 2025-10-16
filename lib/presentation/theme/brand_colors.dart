// File describes brand color constants extracted from the JK logo gradient.
import 'package:flutter/material.dart';

class BrandColors {
  static const Color greenLight = Color(0xFF2AD07C);
  static const Color green = Color(0xFF18A874);
  static const Color greenDark = Color(0xFF0E7052);
  static const Color onBrand = Colors.white;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenLight, green],
  );
}
