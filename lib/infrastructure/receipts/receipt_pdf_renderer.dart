import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:money_pulse/domain/receipts/entities/receipt_models.dart';
import 'package:printing/printing.dart';

typedef AmountFormatter = String Function(int cents);
typedef DateFormatter = String Function(DateTime dt);

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
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            l,
            style: strong
                ? style.copyWith(fontWeight: pw.FontWeight.bold)
                : style,
          ),
          pw.Text(
            r,
            style: strong
                ? style.copyWith(fontWeight: pw.FontWeight.bold)
                : style,
          ),
        ],
      );
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
              pw.SizedBox(height: 4),
              pw.Text(
                (d.storeName ?? 'Reçu').toUpperCase(),
                style: style.copyWith(fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              if ((d.accountLabel ?? '').isNotEmpty)
                pw.Text(
                  d.accountLabel!,
                  style: style,
                  textAlign: pw.TextAlign.center,
                ),
              pw.Text(d.title, style: style, textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 6),
              hr(),
              rowLR('Date', date(d.date)),
              rowLR('Type', d.typeEntry == 'CREDIT' ? 'Vente' : 'Dépense'),
              if ((d.categoryLabel ?? '').isNotEmpty)
                rowLR('Catégorie', d.categoryLabel!),
              hr(),
              lines(),
              hr(),
              rowLR('Sous-total', '${amount(d.subtotal)} ${d.currency}'),
              rowLR('Total', '${amount(d.total)} ${d.currency}', strong: true),
              hr(),
              pw.SizedBox(height: 6),
              pw.Text(
                'Merci pour votre achat',
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
