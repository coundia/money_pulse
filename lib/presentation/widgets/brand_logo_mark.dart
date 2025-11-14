// File renders the JK rounded-square logo with gradient background.
import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';
import 'BrandMonogram.dart';

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
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: BrandMonogram(size: 28)),
      ),
    );
  }
}
