// Service that provides a persistent per-installation ID stored locally.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class InstallationIdService {
  static const _kKey = 'installation_id';
  static const _uuid = Uuid();

  Future<String> getId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await prefs.setString(_kKey, id);
    return id;
  }
}
