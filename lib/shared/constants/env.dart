import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Variable globale (surchargable via --dart-define).
/// BASE_URI (ex: https://cloud.megastore.sn ou http://127.0.0.1:8095)
class Env {
  static const String BASE_URI = String.fromEnvironment(
    'BASE_URI',
    defaultValue: 'https://cloud.megastore.sn',
    // defaultValue: 'http://127.0.0.1:8095',
  );
}

/// (Optionnel) Provider pour l’injection et l’override en tests.
final baseUriProvider = Provider<String>((_) => Env.BASE_URI);
