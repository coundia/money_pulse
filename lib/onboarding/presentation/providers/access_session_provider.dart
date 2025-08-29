/* Riverpod session provider to persist access grant with email, token, username and phone, plus a helper to require access via right-drawer flow. */
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
  static const _kUsername = 'access_session_username';
  static const _kPhone = 'access_session_phone';
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

    final usernameRaw = prefs.getString(_kUsername);
    final phoneRaw = prefs.getString(_kPhone);

    final username = _normalizeUsername(usernameRaw) ?? _deriveUsername(email);
    final phone = _normalizePhone(phoneRaw);

    state = AccessGrant(
      email: email,
      token: token,
      grantedAt: at,
      username: username,
      phone: phone,
    );
  }

  Future<void> save(AccessGrant grant) async {
    final prefs = await SharedPreferences.getInstance();
    final username =
        _normalizeUsername(grant.username) ?? _deriveUsername(grant.email);
    final phone = _normalizePhone(grant.phone);

    await prefs.setString(_kEmail, grant.email);
    await prefs.setString(_kUsername, username);
    if (phone != null) {
      await prefs.setString(_kPhone, phone);
    } else {
      await prefs.remove(_kPhone);
    }
    await prefs.setString(_kToken, grant.token);
    await prefs.setString(_kGrantedAt, grant.grantedAt.toIso8601String());

    state = grant.copyWith(username: username, phone: phone);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    await prefs.remove(_kUsername);
    await prefs.remove(_kPhone);
    await prefs.remove(_kToken);
    await prefs.remove(_kGrantedAt);
    state = null;
  }

  String _deriveUsername(String email) {
    final i = email.indexOf('@');
    final raw = i > 0 ? email.substring(0, i) : email;
    return raw.trim().toLowerCase();
  }

  String? _normalizeUsername(String? u) {
    final v = u?.trim().toLowerCase() ?? '';
    return v.isEmpty ? null : v;
  }

  String? _normalizePhone(String? p) {
    final raw = p?.trim() ?? '';
    if (raw.isEmpty) return null;
    final digitsPlus = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsPlus.startsWith('00')) return '+${digitsPlus.substring(2)}';
    if (!digitsPlus.startsWith('+') && digitsPlus.length >= 9) {
      return '+$digitsPlus';
    }
    return digitsPlus;
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
