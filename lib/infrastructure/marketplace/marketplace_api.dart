import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class MarketplaceApi {
  /// Envoie le produit (JSON dans le champ 'product') + fichiers (clé 'files')
  static Future<http.StreamedResponse> uploadProduct({
    required Uri baseUri,
    required Map<String, dynamic> productJson,
    required List<File> files,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = baseUri.resolve('/api/v1/marketplace');

    final req = http.MultipartRequest('POST', uri)
      ..headers['accept'] = 'application/json'
      ..fields['product'] = jsonEncode(productJson);

    for (final f in files) {
      if (!await f.exists()) continue;
      final path = f.path;
      final mime = lookupMimeType(path) ?? 'application/octet-stream';
      final mediaType = mime.split('/');
      req.files.add(
        await http.MultipartFile.fromPath(
          'files',
          path,
          // contentType: MediaType(mediaType[0], mediaType[1]),
          filename: path.split(Platform.pathSeparator).last,
        ),
      );
    }

    final client = http.Client();
    try {
      final res = await client.send(req).timeout(timeout);
      return res;
    } finally {
      client.close();
    }
  }
}

/// Petit helper pour http.MediaType sans dépendance 'http_parser'
class MediaType {
  final String type;
  final String subtype;
  const MediaType(this.type, this.subtype);

  @override
  String toString() => '$type/$subtype';
}
