// Local store for last order form payload using SharedPreferences. Provides load/save helpers.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OrderLocalStore {
  static const _kKey = 'mp.marketplace.last_order';

  Future<Map<String, dynamic>?> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, json.encode(data));
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
  }
}
