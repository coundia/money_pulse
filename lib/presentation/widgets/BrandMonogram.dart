import 'package:flutter/material.dart';

class BrandMonogram extends StatelessWidget {
  final double size;
  const BrandMonogram({required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset('assets/logo/app_icon.png', fit: BoxFit.cover),
      ),
    );
  }
}
