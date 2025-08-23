// Riverpod providers to expose a persistent installation ID.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/shared/services/installation_id_service.dart';

final installationIdServiceProvider = Provider<InstallationIdService>((ref) {
  return InstallationIdService();
});

final installationIdProvider = FutureProvider<String>((ref) async {
  final svc = ref.read(installationIdServiceProvider);
  return svc.getId();
});
