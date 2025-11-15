/* Waitlist repository implementation using SharedPreferences. */
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jaayko/domain/waitlist/entities/waitlist_entry.dart';
import 'package:jaayko/domain/waitlist/repositories/waitlist_repository.dart';

class WaitlistRepositoryPrefs implements WaitlistRepository {
  static const _kKey = 'waitlist.entry.v1';

  @override
  Future<void> save(WaitlistEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, entry.toJson());
  }

  @override
  Future<WaitlistEntry?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kKey);
    if (s == null || s.isEmpty) return null;
    try {
      return WaitlistEntry.fromJson(s);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
