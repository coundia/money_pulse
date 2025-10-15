// Widget: MediaAttachmentsPicker with lost-data recovery on Android
// Restores picked files if Android kills & restarts the Activity under memory pressure.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

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

  String get _dupeKey =>
      '${name.toLowerCase()}::${size ?? bytes?.length ?? 0}::${mimeType ?? ''}';
}

class MediaAttachmentsPicker extends StatefulWidget {
  final List<PickedAttachment> initial;
  final ValueChanged<List<PickedAttachment>> onChanged;
  final ValueChanged<String>? onError;
  final bool loggingEnabled;
  final String logTag;
  final bool allowPdf; // (non utilisé ici, on reste image-only)

  const MediaAttachmentsPicker({
    super.key,
    this.initial = const [],
    required this.onChanged,
    this.onError,
    this.loggingEnabled = true,
    this.logTag = 'MediaAttachmentsPicker',
    this.allowPdf = true,
  });

  @override
  State<MediaAttachmentsPicker> createState() => _MediaAttachmentsPickerState();
}

class _MediaAttachmentsPickerState extends State<MediaAttachmentsPicker>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();

  late List<PickedAttachment> _items = [...widget.initial];
  bool _busy = false;

  void _log(String msg, {Object? error, StackTrace? st}) {
    if (!widget.loggingEnabled) return;
    final p = '[${widget.logTag}]';
    // ignore: avoid_print
    print('$p $msg');
    if (error != null) print('$p ❌ $error');
    if (st != null) print('$p stack:\n$st');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Au démarrage du widget, tente de récupérer d’éventuels médias perdus
    // si l’Activity a été recréée par Android pendant la sélection.
    if (!kIsWeb && Platform.isAndroid) {
      // microtask pour laisser la frame s'installer
      Future.microtask(_recoverLostDataIfAny);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MediaAttachmentsPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.initial, widget.initial)) {
      _log('didUpdateWidget → reset from initial (${widget.initial.length})');
      _items = [...widget.initial];
    }
  }

  // ✅ Si l’app revient en foreground après un kill/restart, on retente une récup.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed &&
        !kIsWeb &&
        Platform.isAndroid &&
        !_busy) {
      _recoverLostDataIfAny();
    }
  }

  Future<void> _recoverLostDataIfAny() async {
    try {
      final LostDataResponse resp = await _picker.retrieveLostData();
      if (resp.isEmpty) return;

      final List<XFile> recovered =
          resp.files ?? (resp.file != null ? [resp.file!] : <XFile>[]);

      if (recovered.isEmpty) {
        if (resp.exception != null) {
          _log('retrieveLostData error: ${resp.exception}');
          _notifyError('Récupération interrompue (${resp.exception?.code}).');
        }
        return;
      }

      _log('retrieveLostData → ${recovered.length} fichier(s) retrouvé(s)');
      final attachments = await _xfilesToAttachments(recovered);
      _mergeAndNotify(attachments);
    } catch (e, st) {
      _log('retrieveLostData failed', error: e, st: st);
    }
  }

  Future<List<PickedAttachment>> _xfilesToAttachments(List<XFile> files) async {
    final out = <PickedAttachment>[];
    for (final xf in files) {
      final path = xf.path;
      final name = path.split(Platform.pathSeparator).last;
      final mime = lookupMimeType(path) ?? 'image/*';
      Uint8List? bytes;
      try {
        bytes = await xf.readAsBytes();
      } catch (_) {}
      out.add(
        PickedAttachment(
          name: name,
          path: path,
          bytes: bytes,
          size: bytes?.length,
          mimeType: mime,
          readStream: null,
        ),
      );
    }
    return out;
  }

  Future<void> _openChooser() async {
    if (_busy) return;
    final picks = <_PickAction>[
      const _PickAction(
        _PickChoice.images,
        Icons.photo_library_outlined,
        'Choisir des photos',
        'Depuis la galerie',
      ),
      // (PDF désactivé ici pour rester 100% image_picker et éviter tout Intent externe)
    ];

    final choice = await showModalBottomSheet<_PickChoice>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in picks)
              ListTile(
                leading: Icon(a.icon),
                title: Text(a.title),
                subtitle: Text(a.subtitle),
                onTap: () => Navigator.pop(ctx, a.choice),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null) return;
    if (choice == _PickChoice.images) {
      await _pickImagesInApp();
    }
  }

  Future<void> _pickImagesInApp() async {
    await _withBusyGuard(() async {
      try {
        _log('Starting in-app image picker');
        final files = await _picker.pickMultiImage(
          imageQuality: null,
          maxWidth: null,
          maxHeight: null,
        );
        if (files.isEmpty) {
          _log('Image picker cancelled');
          return;
        }
        final attachments = await _xfilesToAttachments(files);
        _mergeAndNotify(attachments);
      } on PlatformException catch (e, st) {
        final msg = _platformErrorToMessage(e);
        _notifyError(msg);
        _log('PlatformException(images): $msg', error: e, st: st);
      } catch (e, st) {
        _notifyError('Erreur inattendue: $e');
        _log('Unhandled(images)', error: e, st: st);
      }
    });
  }

  String _platformErrorToMessage(PlatformException e) {
    final code = (e.code.isEmpty ? 'unknown' : e.code).toLowerCase();
    if (code.contains('read') || code.contains('permission')) {
      return 'Accès refusé au stockage/photothèque.';
    }
    if (code.contains('not_found') || code.contains('file')) {
      return 'Fichier introuvable ou inaccessible.';
    }
    if (code.contains('size') || code.contains('too_large')) {
      return 'Fichier trop volumineux.';
    }
    return 'Erreur sélection (${e.code}).';
  }

  void _mergeAndNotify(List<PickedAttachment> added) {
    final existingKeys = _items.map((e) => e._dupeKey).toSet();
    final uniques = added
        .where((a) => !existingKeys.contains(a._dupeKey))
        .toList();
    final newCount = uniques.length;
    if (newCount > 0) {
      _items = [..._items, ...uniques];
      widget.onChanged(_items);
    }
    _log('Merged +$newCount, total=${_items.length}');
    if (newCount == 0 && added.isNotEmpty) {
      _notifyError('Aucun nouveau fichier ajouté (doublons).');
    }
  }

  Future<void> _withBusyGuard(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    _log('Busy start');
    try {
      await fn();
    } finally {
      _log('Busy end');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notifyError(String msg) {
    widget.onError?.call(msg);
    _log('Error: $msg');
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _removeAt(int i) {
    if (i < 0 || i >= _items.length) return;
    final removed = _items[i].name;
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
    _log('Removed index=$i name=$removed now=${_items.length}');
  }

  Widget _thumb(PickedAttachment p) {
    final t = (p.mimeType ?? '');
    if (t.startsWith('image/')) {
      if (!kIsWeb && Platform.isAndroid && (p.path ?? '').isNotEmpty) {
        final file = File(p.path!);
        if (file.existsSync()) {
          return Image.file(file, fit: BoxFit.cover, gaplessPlayback: true);
        }
      }
      if (p.bytes != null && p.bytes!.isNotEmpty) {
        return Image.memory(p.bytes!, fit: BoxFit.cover, gaplessPlayback: true);
      }
      return const Icon(Icons.broken_image_outlined, size: 32);
    }
    return const Icon(Icons.insert_drive_file_outlined, size: 36);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile(PickedAttachment p, int index) {
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(child: _thumb(p)),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Material(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _removeAt(index),
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
              onPressed: _busy ? null : _openChooser,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file_outlined),
              label: Text(_busy ? 'Chargement…' : 'Ajouter (photos)'),
            ),
            if (_items.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text('${_items.length} élément(s)'),
              ),
            if (_items.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        _log('Clear all attachments');
                        setState(() => _items = []);
                        widget.onChanged(_items);
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Tout effacer'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Text(
            'Aucun fichier sélectionné',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (_items.isNotEmpty)
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cross = w < 420 ? 3 : (w < 720 ? 4 : 6);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _items.length,
                itemBuilder: (_, i) => tile(_items[i], i),
              );
            },
          ),
      ],
    );
  }
}

enum _PickChoice { images }

class _PickAction {
  final _PickChoice choice;
  final IconData icon;
  final String title;
  final String subtitle;
  const _PickAction(this.choice, this.icon, this.title, this.subtitle);
}
