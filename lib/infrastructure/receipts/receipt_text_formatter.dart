import 'package:money_pulse/domain/receipts/entities/receipt_models.dart';

typedef AmountFormatter = String Function(int cents);
typedef DateFormatter = String Function(DateTime dt);

// Map internal/remote type codes to human-friendly French labels.
String _labelForType(String typeEntry) {
  final t = typeEntry.toUpperCase().trim();
  if (t == 'CREDIT') return 'Vente';
  if (t == 'DEBIT') return 'Dépense';
  if (t.contains('DEBT')) return 'Dette';
  if (t.startsWith('REMBOUR')) return 'Remboursement';
  return t.isEmpty ? 'Transaction' : t;
}

class ReceiptTextFormatter {
  final AmountFormatter amount;
  final DateFormatter date;

  ReceiptTextFormatter({required this.amount, required this.date});

  String build(ReceiptData d, {int width = 32}) {
    final b = StringBuffer();
    String line([String char = '-']) => char * width;
    String center(String s) {
      final t = s.trim();
      if (t.length >= width) return t;
      final pad = (width - t.length) ~/ 2;
      return ' ' * pad + t;
    }

    String lr(String l, String r) {
      final left = l.trim();
      final right = r.trim();
      final space = width - left.length - right.length;
      return space <= 0 ? '$left $right' : '$left${' ' * space}$right';
    }

    List<String> wrap(String text, int max) {
      final words = text.split(RegExp(r'\s+'));
      final lines = <String>[];
      var cur = '';
      for (final w in words) {
        if (cur.isEmpty) {
          cur = w;
        } else if ((cur.length + 1 + w.length) <= max) {
          cur = '$cur $w';
        } else {
          lines.add(cur);
          cur = w;
        }
      }
      if (cur.isNotEmpty) lines.add(cur);
      return lines;
    }

    b.writeln(center(d.storeName?.toUpperCase() ?? 'REÇU'));
    if ((d.accountLabel ?? '').isNotEmpty) b.writeln(center(d.accountLabel!));
    b.writeln(center(d.title));
    b.writeln(line());
    b.writeln(lr('Date', date(d.date)));

    // ✅ Fixed type mapping
    b.writeln(lr('Type', _labelForType(d.typeEntry)));

    if ((d.categoryLabel ?? '').isNotEmpty) {
      b.writeln(lr('Catégorie', d.categoryLabel!));
    }
    b.writeln(line());

    const qtyW = 3;
    const priceW = 9;
    const totalW = 9;
    final labelW = width - qtyW - priceW - totalW - 3;

    for (final it in d.lines) {
      final lblLines = wrap(it.label, labelW);
      final qtyStr = it.quantity.toString().padLeft(qtyW);
      final unitStr = amount(it.unitPrice).padLeft(priceW);
      final totStr = amount(it.total).padLeft(totalW);
      b.writeln('${lblLines.first.padRight(labelW)} $qtyStr $unitStr $totStr');
      for (var i = 1; i < lblLines.length; i++) {
        b.writeln(
          '${lblLines[i].padRight(labelW)} ${' ' * qtyW} ${' ' * priceW} ${' ' * totalW}',
        );
      }
    }

    b.writeln(line());
    b.writeln(lr('Sous-total', '${amount(d.subtotal)} ${d.currency}'));
    b.writeln(lr('Total', '${amount(d.total)} ${d.currency}'));
    b.writeln(line());
    b.writeln(center('Merci'));
    if ((d.footerNote ?? '').isNotEmpty) b.writeln(center(d.footerNote!));
    b.writeln();
    return b.toString();
  }
}

extension _Mul on String {
  String operator *(int n) => List.filled(n, this).join();
}
