import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart' as ipa;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mime/mime.dart';

class PickedAttachment {
  final String name;
  final String? path; // chemin fichier local (Android/iOS)
  final Uint8List? bytes; // utile sur Web
  final String? mimeType; // ex: image/jpeg
  final int? size; // en octets
  final String hash; // md5 pour dédoublonner

  const PickedAttachment({
    required this.name,
    this.path,
    this.bytes,
    this.mimeType,
    this.size,
    required this.hash,
  });
}

class MediaAttachmentsPicker extends StatefulWidget {
  final List<PickedAttachment> initial;
  final ValueChanged<List<PickedAttachment>> onChanged;
  final ValueChanged<String>? onError;
  final bool loggingEnabled;
  final String logTag;

  /// Limites
  final int maxCount; // nombre max de fichiers
  final int maxBytes; // taille max d'un fichier

  const MediaAttachmentsPicker({
    super.key,
    this.initial = const [],
    required this.onChanged,
    this.onError,
    this.loggingEnabled = true,
    this.logTag = 'MediaAttachmentsPicker',
    this.maxCount = 20,
    this.maxBytes = 15 * 1024 * 1024, // 15 MB
  });

  @override
  State<MediaAttachmentsPicker> createState() => _MediaAttachmentsPickerState();
}

class _MediaAttachmentsPickerState extends State<MediaAttachmentsPicker>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  late List<PickedAttachment> _items = [...widget.initial];
  bool _busy = false;

  void _log(String m) {
    if (widget.loggingEnabled) debugPrint('[${widget.logTag}] $m');
  }

  @override
  void initState() {
    super.initState();

    // Forcer le Android Photo Picker (plus stable)
    if (!kIsWeb && Platform.isAndroid) {
      ImagePickerPlatform.instance = ipa.ImagePickerAndroid()
        ..useAndroidPhotoPicker = true;
    }

    WidgetsBinding.instance.addObserver(this);

    // Récupération des sélections perdues (Android)
    if (!kIsWeb && Platform.isAndroid) {
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
      _items = [...widget.initial];
    }
  }

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
      final resp = await _picker.retrieveLostData();
      if (resp.isEmpty) return;
      final recovered =
          resp.files ??
          (resp.file != null ? <XFile>[resp.file!] : const <XFile>[]);
      if (recovered.isEmpty) return;
      final atts = await _xfilesToAttachments(recovered);
      _mergeAndNotify(atts);
    } catch (e) {
      _log('retrieveLostData failed: $e');
    }
  }

  Future<List<PickedAttachment>> _xfilesToAttachments(List<XFile> files) async {
    final out = <PickedAttachment>[];
    for (final xf in files) {
      final path = xf.path;
      final name = _basename(path);
      // Mime doit être image/*
      final mime = lookupMimeType(path) ?? 'application/octet-stream';

      Uint8List? bytes;
      int size = 0;
      try {
        if (kIsWeb) {
          bytes = await xf.readAsBytes();
          size = bytes.length;
        } else {
          size = await xf.length();
        }
      } catch (_) {}

      final hash = await _hashFor(path: path, bytes: bytes);
      out.add(
        PickedAttachment(
          name: name,
          path: kIsWeb ? null : path,
          bytes: kIsWeb ? bytes : null,
          size: size,
          mimeType: mime,
          hash: hash,
        ),
      );
    }
    return out;
  }

  Future<String> _hashFor({String? path, Uint8List? bytes}) async {
    try {
      if (bytes != null) {
        return md5.convert(bytes).toString();
      }
      if (path != null && !kIsWeb) {
        final f = File(path);
        if (f.existsSync()) {
          final digest = await md5.bind(f.openRead()).first;
          return digest.toString();
        }
      }
    } catch (_) {}
    // Fallback
    final t = DateTime.now().microsecondsSinceEpoch.toString();
    return md5.convert(Uint8List.fromList(t.codeUnits)).toString();
  }

  String _basename(String p) {
    if (p.isEmpty) return p;
    final sep = p.contains('/') ? '/' : '\\';
    final parts = p.split(sep);
    return parts.isEmpty ? p : parts.last;
  }

  bool _isAllowedImage(String? mime) =>
      mime != null && mime.toLowerCase().startsWith('image/');

  String? _validate(PickedAttachment a) {
    if (!_isAllowedImage(a.mimeType))
      return 'Type non autorisé (image uniquement)';
    if (a.size != null && a.size! > widget.maxBytes) {
      return 'Fichier trop volumineux (${a.name})';
    }
    return null;
  }

  void _mergeAndNotify(List<PickedAttachment> added) {
    final existing = _items.map((e) => e.hash).toSet();

    // On ne garde que les images valides et non dupliquées
    final uniques = <PickedAttachment>[];
    for (final a in added) {
      if (existing.contains(a.hash)) continue;
      final err = _validate(a);
      if (err != null) {
        _notifyError(err);
        continue;
      }
      uniques.add(a);
    }

    if (uniques.isEmpty) {
      _notifyError('Aucun nouveau fichier ajouté');
      return;
    }

    final total = _items.length + uniques.length;
    if (total > widget.maxCount) {
      _notifyError('Limite atteinte ($total/${widget.maxCount})');
      return;
    }

    _items = [..._items, ...uniques];
    widget.onChanged(_items);
    _log('Merged +${uniques.length}, total=${_items.length}');
  }

  void _notifyError(String msg) {
    widget.onError?.call(msg);
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _withBusy(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Galerie uniquement (multi-images)
  Future<void> _pickGallery() async {
    await _withBusy(() async {
      final files = await _picker.pickMultiImage(
        imageQuality: null,
        maxWidth: null,
        maxHeight: null,
      );
      if (files.isEmpty) return;
      final atts = await _xfilesToAttachments(files);
      _mergeAndNotify(atts);
    });
  }

  void _removeAt(int i) {
    if (i < 0 || i >= _items.length) return;
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
    _log('Removed index=$i, now=${_items.length}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _pickGallery,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(_busy ? 'Chargement…' : 'Images'),
            ),
            if (_items.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text('${_items.length} image(s)'),
              ),
            if (_items.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _items = []);
                        widget.onChanged(_items);
                        _log('Clear all attachments');
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Tout effacer'),
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
                itemBuilder: (_, i) {
                  final p = _items[i];
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Center(child: _imageThumb(p)),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Material(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _removeAt(i),
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
                },
              );
            },
          ),
      ],
    );
  }

  Widget _imageThumb(PickedAttachment p) {
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
}
