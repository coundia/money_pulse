// Small helpers to parse amount text controllers into cents.
import 'package:flutter/material.dart';

extension AmountCtrlX on TextEditingController {
  int toCents() {
    final raw = text
        .trim()
        .replaceAll(RegExp(r'[\u00A0\u202F\s]'), '')
        .replaceAll(',', '.');
    final d = double.tryParse(raw) ?? 0;
    final c = (d * 100).round();
    return c < 0 ? 0 : c;
  }
}
