// ReceiptPdfRenderer: builds a 58mm-style PDF receipt including company and customer info.
// Also includes ReceiptTextFormatter (text receipt) with consistent type mapping (CREDIT/DEBIT/DETTE/etc).

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:money_pulse/domain/receipts/entities/receipt_models.dart';
import 'package:printing/printing.dart';

typedef AmountFormatter = String Function(int cents);
typedef DateFormatter = String Function(DateTime dt);

// ---- Type mapping (shared) ---------------------------------------------------
String _labelForType(String typeEntry) {
  final t = typeEntry.toUpperCase().trim();
  if (t == 'CREDIT') return 'Vente';
  if (t == 'DEBIT') return 'Dépense';
  if (t.contains('DETTE')) return 'Dette';
  if (t.startsWith('REMBOUR')) return 'Remboursement';
  if (t.startsWith('TRANSF')) return 'Transfert';
  if (t == 'AVOIR') return 'Avoir';
  if (t == 'VERSEMENT') return 'Versement';
  return t.isEmpty ? 'Transaction' : t;
}
// -----------------------------------------------------------------------------

class ReceiptPdfRenderer {
  final AmountFormatter amount;
  final DateFormatter date;

  ReceiptPdfRenderer({required this.amount, required this.date});

  Future<Uint8List> render(ReceiptData d) async {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: base, bold: bold);

    final doc = pw.Document(theme: theme);
    final style = const pw.TextStyle(fontSize: 9);
    final width = PdfPageFormat.mm * 58;
    const margin = 6.0;

    pw.Widget hr() => pw.Container(
      width: double.infinity,
      height: 0.8,
      color: PdfColor.fromInt(0xFF000000),
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
    );

    pw.Widget rowLR(String l, String r, {bool strong = false}) {
      final s = strong ? style.copyWith(fontWeight: pw.FontWeight.bold) : style;
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(l, style: s),
          pw.Text(r, style: s),
        ],
      );
    }

    pw.Widget headerBlock() {
      // Prefer the business/store name, fall back to the ReceiptData.title if present
      final title =
          (d.storeName?.trim().isNotEmpty == true
                  ? d.storeName!
                  : (d.title.trim().isNotEmpty ? d.title : 'Reçu'))
              .toUpperCase();

      final sub = <String>[];
      if ((d.companyCode ?? '').trim().isNotEmpty)
        sub.add('Code: ${d.companyCode}');
      if ((d.companyTaxId ?? '').trim().isNotEmpty)
        sub.add('N° Fiscal: ${d.companyTaxId}');

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: style.copyWith(fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          if ((d.accountLabel ?? '').isNotEmpty)
            pw.Text(
              d.accountLabel!,
              style: style,
              textAlign: pw.TextAlign.center,
            ),
          if (sub.isNotEmpty)
            pw.Text(
              sub.join(' • '),
              style: style,
              textAlign: pw.TextAlign.center,
            ),
          if ((d.companyAddress ?? '').trim().isNotEmpty)
            pw.Text(
              d.companyAddress!,
              style: style,
              textAlign: pw.TextAlign.center,
            ),
          if ((d.companyPhone ?? '').trim().isNotEmpty ||
              (d.companyEmail ?? '').trim().isNotEmpty)
            pw.Text(
              [
                d.companyPhone,
                d.companyEmail,
              ].where((e) => (e ?? '').trim().isNotEmpty).join(' • '),
              style: style,
              textAlign: pw.TextAlign.center,
            ),
        ],
      );
    }

    pw.Widget partyBlock() {
      final left = <pw.Widget>[
        rowLR('Date', date(d.date)),
        // ✅ Fixed mapping for type (handles DETTE/REMBOURSEMENT/TRANSFERT/…)
        rowLR('Type', _labelForType(d.typeEntry)),
        if ((d.categoryLabel ?? '').isNotEmpty)
          rowLR('Catégorie', d.categoryLabel!),
      ];
      final right = <pw.Widget>[
        if ((d.customerName ?? '').trim().isNotEmpty)
          rowLR('Client', d.customerName!),
        if ((d.customerPhone ?? '').trim().isNotEmpty)
          rowLR('Téléphone', d.customerPhone!),
        if ((d.customerEmail ?? '').trim().isNotEmpty)
          rowLR('Email', d.customerEmail!),
      ];
      return pw.Column(children: [...left, ...right]);
    }

    pw.Widget lines() {
      return pw.Column(
        children: [
          for (final it in d.lines)
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 6, child: pw.Text(it.label, style: style)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      '${it.quantity}',
                      textAlign: pw.TextAlign.right,
                      style: style,
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      amount(it.unitPrice),
                      textAlign: pw.TextAlign.right,
                      style: style,
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      amount(it.total),
                      textAlign: pw.TextAlign.right,
                      style: style.copyWith(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity, marginAll: margin),
        build: (c) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              headerBlock(),
              pw.SizedBox(height: 6),
              hr(),
              partyBlock(),
              hr(),
              lines(),
              hr(),
              rowLR('Sous-total', '${amount(d.subtotal)} ${d.currency}'),
              rowLR('Total', '${amount(d.total)} ${d.currency}', strong: true),
              hr(),
              pw.SizedBox(height: 6),
              pw.Text(
                // Keep generic message; could be adapted per type if desired
                'Merci ',
                style: style,
                textAlign: pw.TextAlign.center,
              ),
              if ((d.footerNote ?? '').isNotEmpty)
                pw.Text(
                  d.footerNote!,
                  style: style,
                  textAlign: pw.TextAlign.center,
                ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}

// ====================== TEXT RENDERER ===============================

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
    b.writeln(center(d.title)); // already adapted in controller
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
