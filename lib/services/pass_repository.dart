import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pass.dart';

/// Persists the wallet's pass collection locally so it survives an app
/// force-kill and relaunch (section 3.3).
///
/// Note on storage choice: pass metadata here (event name, dates, status,
/// a reference token id) is not sensitive on its own — it contains no
/// session credential or raw claim token that would grant access, so
/// SharedPreferences is an appropriate, non-sensitive local cache. The
/// actual credential (the session) lives only in [SecureSessionStore].
class PassRepository {
  static const _passesKey = 'omnipass.passes.v1';

  Future<List<Pass>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_passesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return list
          .map((e) => Pass.fromJson(e as Map<String, Object?>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<Pass> passes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(passes.map((p) => p.toJson()).toList());
    await prefs.setString(_passesKey, raw);
  }
}
