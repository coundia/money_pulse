// ReceiptPreviewPage: previews receipt with chips for date/type/total/company/customer and allows share/print/download.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:money_pulse/domain/receipts/entities/receipt_models.dart';
import 'package:money_pulse/infrastructure/receipts/receipt_text_formatter.dart';
import 'package:money_pulse/infrastructure/receipts/receipt_pdf_renderer.dart';
import 'package:money_pulse/presentation/features/transactions/receipt/receipt_controller.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class ReceiptPreviewPage extends ConsumerWidget {
  final String transactionId;
  const ReceiptPreviewPage({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptDataProvider(transactionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aperçu du reçu'),
        actions: [
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.ios_share),
            onPressed: async.hasValue
                ? () async {
                    final d = async.value!;
                    final temp = await getTemporaryDirectory();
                    final path = '${temp.path}/recu_${d.id}.pdf';
                    final bytes = await ReceiptPdfRenderer(
                      amount: fmtAmount,
                      date: fmtDate,
                    ).render(d);
                    await File(path).writeAsBytes(bytes, flush: true);
                    await Share.shareXFiles([XFile(path)], text: 'Reçu');
                  }
                : null,
          ),
          IconButton(
            tooltip: 'Imprimer',
            icon: const Icon(Icons.print),
            onPressed: async.hasValue
                ? () async {
                    try {
                      final d = async.value!;
                      final bytes = await ReceiptPdfRenderer(
                        amount: fmtAmount,
                        date: fmtDate,
                      ).render(d);
                      await Printing.layoutPdf(onLayout: (_) async => bytes);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Impression indisponible. Téléchargez puis imprimez le PDF via le système.',
                            ),
                          ),
                        );
                      }
                    }
                  }
                : null,
          ),
        ],
      ),
      body: async.when(
        data: (d) {
          final accent = d.typeEntry == 'CREDIT' ? Colors.green : Colors.red;
          final textBlock = ReceiptTextFormatter(
            amount: fmtAmount,
            date: fmtDate,
          ).build(d, width: 32);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderChips(
                date: fmtDate(d.date),
                type: d.typeEntry == 'CREDIT' ? 'Vente' : 'Dépense',
                total: '${Formatters.amountFromCents(d.total)} ${d.currency}',
                company: d.companyName ?? '—',
                customer: d.customerName ?? '—',
                accent: accent,
              ),
              const SizedBox(height: 12),
              _ReceiptPreview(text: textBlock, accent: accent),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
      bottomNavigationBar: async.hasValue
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = async.value!;
                          final dir = await getApplicationDocumentsDirectory();
                          final pdfPath = '${dir.path}/recu_${d.id}.pdf';
                          final txtPath = '${dir.path}/recu_${d.id}.txt';
                          final bytes = await ReceiptPdfRenderer(
                            amount: fmtAmount,
                            date: fmtDate,
                          ).render(d);
                          await File(pdfPath).writeAsBytes(bytes, flush: true);
                          final text = ReceiptTextFormatter(
                            amount: fmtAmount,
                            date: fmtDate,
                          ).build(d, width: 32);
                          await File(txtPath).writeAsString(text, flush: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Fichiers enregistrés:\n$pdfPath\n$txtPath',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Télécharger'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final d = async.value!;
                          final temp = await getTemporaryDirectory();
                          final path = '${temp.path}/recu_${d.id}.pdf';
                          final bytes = await ReceiptPdfRenderer(
                            amount: fmtAmount,
                            date: fmtDate,
                          ).render(d);
                          await File(path).writeAsBytes(bytes, flush: true);
                          await Share.shareXFiles([XFile(path)], text: 'Reçu');
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Partager'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _HeaderChips extends StatelessWidget {
  final String date;
  final String type;
  final String total;
  final String company;
  final String customer;
  final Color accent;

  const _HeaderChips({
    required this.date,
    required this.type,
    required this.total,
    required this.company,
    required this.customer,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(date),
          backgroundColor: cs.surfaceContainerLow,
        ),
        Chip(
          avatar: Icon(
            type == 'Vente' ? Icons.north : Icons.south,
            size: 16,
            color: accent,
          ),
          label: Text(type),
          backgroundColor: cs.surfaceContainerLow,
        ),
        Chip(
          avatar: Icon(Icons.payments, size: 16, color: accent),
          label: Text(total),
          backgroundColor: cs.surfaceContainerLow,
        ),
        if (company.trim().isNotEmpty && company != '—')
          Chip(
            avatar: const Icon(Icons.business, size: 16),
            label: Text(company),
            backgroundColor: cs.surfaceContainerLow,
          ),
        if (customer.trim().isNotEmpty && customer != '—')
          Chip(
            avatar: const Icon(Icons.person, size: 16),
            label: Text(customer),
            backgroundColor: cs.surfaceContainerLow,
          ),
      ],
    );
  }
}

class _ReceiptPreview extends StatefulWidget {
  final String text;
  final Color accent;
  const _ReceiptPreview({required this.text, required this.accent});

  @override
  State<_ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<_ReceiptPreview> {
  double fontSize = 12;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    widget.text,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: fontSize,
                      height: 1.22,
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      tooltip: 'Copier',
                      icon: const Icon(Icons.copy_all, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.text),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reçu copié')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.zoom_out),
            Expanded(
              child: Slider(
                value: fontSize,
                min: 10,
                max: 18,
                onChanged: (v) => setState(() => fontSize = v),
              ),
            ),
            const Icon(Icons.zoom_in),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Largeur simulée: 58 mm',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
