/* Providers exposing the connected username and phone derived from the persisted access session. */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/presentation/providers/access_session_provider.dart';

final connectedUsernameProvider = Provider<String?>((ref) {
  final grant = ref.watch(accessSessionProvider);
  if (grant == null) return null;
  final u = (grant.username == null || grant.username!.trim().isEmpty)
      ? _emailLocalPart(grant.email)
      : grant.username!.trim().toLowerCase();
  return u.isEmpty ? null : u;
});

final connectedPhoneProvider = Provider<String?>((ref) {
  final grant = ref.watch(accessSessionProvider);
  final p = grant?.phone?.trim();
  return (p == null || p.isEmpty) ? null : p;
});

String _emailLocalPart(String email) {
  final i = email.indexOf('@');
  final raw = i > 0 ? email.substring(0, i) : email;
  return raw.trim().toLowerCase();
}
