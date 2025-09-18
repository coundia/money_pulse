// Small widget to pick image files with preview; supports iOS large files via readStream.
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PickedAttachment {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final String? mimeType;
  final int? size;
  final Stream<List<int>>? readStream;

  const PickedAttachment({
    required this.name,
    this.path,
    this.bytes,
    this.mimeType,
    this.size,
    this.readStream,
  });
}

class AttachmentsPicker extends StatefulWidget {
  final List<PickedAttachment> initial;
  final ValueChanged<List<PickedAttachment>> onChanged;

  const AttachmentsPicker({
    super.key,
    this.initial = const [],
    required this.onChanged,
  });

  @override
  State<AttachmentsPicker> createState() => _AttachmentsPickerState();
}

class _AttachmentsPickerState extends State<AttachmentsPicker> {
  late List<PickedAttachment> _items = [...widget.initial];
  bool _temporarilyDisabled = false;

  Future<void> _pick() async {
    if (_temporarilyDisabled) return;
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true, // small/medium files
        withReadStream: true, // large files (iOS iCloud / HEIC)
      );
      if (res == null) return;

      final added = res.files.map((f) {
        final mime = (f.extension == null || f.extension!.isEmpty)
            ? null
            : 'image/${f.extension}';
        return PickedAttachment(
          name: f.name,
          path: f.path,
          bytes: f.bytes,
          size: f.size,
          mimeType: mime,
          readStream: f.readStream,
        );
      }).toList();

      setState(() => _items = [..._items, ...added]);
      widget.onChanged(_items);
    } on MissingPluginException catch (_) {
      setState(() => _temporarilyDisabled = true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Sélecteur indisponible. Faites un build iOS complet (pod install) puis relancez.',
          ),
        ),
      );
    } on PlatformException catch (e) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Erreur sélection: ${e.code}')));
    } catch (e) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _removeAt(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile(PickedAttachment p) {
      final preview = p.bytes != null
          ? Image.memory(p.bytes!, fit: BoxFit.cover)
          : const Icon(Icons.image_outlined, size: 32);
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(child: preview),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _removeAt(_items.indexOf(p)),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _temporarilyDisabled ? null : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _temporarilyDisabled
                    ? 'Indisponible (relancer build)'
                    : 'Ajouter des images',
              ),
            ),
            if (_items.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text('${_items.length} sélectionnée(s)'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Text(
            'Aucune image sélectionnée',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (_items.isNotEmpty)
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cross = w < 420
                  ? 3
                  : w < 720
                  ? 4
                  : 6;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _items.length,
                itemBuilder: (_, i) => tile(_items[i]),
              );
            },
          ),
      ],
    );
  }
}
