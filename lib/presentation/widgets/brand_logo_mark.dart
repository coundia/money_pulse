// File renders the JK rounded-square logo with gradient background.
import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';

class BrandLogoMark extends StatelessWidget {
  final double size;
  const BrandLogoMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: BrandColors.brandGradient,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      alignment: Alignment.center,
      child: const Text(
        'JK',
        style: TextStyle(
          color: BrandColors.onBrand,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
