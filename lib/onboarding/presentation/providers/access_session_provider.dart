// Riverpod session provider to persist access grant and a helper to require access via right-drawer flow.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/access_grant.dart';
import '../flow/start_access_flow.dart';

final accessSessionProvider =
    StateNotifierProvider<AccessSessionNotifier, AccessGrant?>(
      (ref) => AccessSessionNotifier(),
    );

class AccessSessionNotifier extends StateNotifier<AccessGrant?> {
  AccessSessionNotifier() : super(null);

  static const _kEmail = 'access_session_email';
  static const _kToken = 'access_session_token';
  static const _kGrantedAt = 'access_session_granted_at';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    if (token == null || token.isEmpty) {
      state = null;
      return;
    }
    final email = prefs.getString(_kEmail) ?? '';
    final at =
        DateTime.tryParse(prefs.getString(_kGrantedAt) ?? '') ?? DateTime.now();
    state = AccessGrant(email: email, token: token, grantedAt: at);
  }

  Future<void> save(AccessGrant grant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmail, grant.email);
    await prefs.setString(_kToken, grant.token);
    await prefs.setString(_kGrantedAt, grant.grantedAt.toIso8601String());
    state = grant;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    await prefs.remove(_kToken);
    await prefs.remove(_kGrantedAt);
    state = null;
  }
}

Future<bool> requireAccess(
  BuildContext context,
  WidgetRef ref, {
  String? prefillEmail,
}) async {
  final current = ref.read(accessSessionProvider);
  if (current != null) return true;
  final grant = await startAccessFlow(context, ref, prefillEmail: prefillEmail);
  if (grant == null) return false;
  await ref.read(accessSessionProvider.notifier).save(grant);
  return true;
}
