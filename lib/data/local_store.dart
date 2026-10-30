import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around shared_preferences: one JSON blob for the whole app
/// state. shared_preferences is the only storage plugin in the project because
/// it ships first-party implementations for all five target platforms.
class LocalStore {
  LocalStore._(this._prefs);

  static const _key = 'centsgo.state.v1';
  final SharedPreferences _prefs;

  static Future<LocalStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore._(prefs);
  }

  Map<String, dynamic> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    await _prefs.setString(_key, jsonEncode(data));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
