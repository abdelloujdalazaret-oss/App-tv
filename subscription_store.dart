import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/storage/json_prefs.dart';
import '../models/channel.dart';
import '../models/subscription.dart';

/// Abonnements dans le stockage sécurisé ; abonnement actif conservé.
class SubscriptionStore {
  static const _kSubs = 'subs';
  static const _kActive = 'active_sub';
  final _secure = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  Future<List<Subscription>> load() async {
    try {
      final raw = await _secure.read(key: _kSubs);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Subscription> subs) =>
      _secure.write(key: _kSubs, value: jsonEncode(subs.map((s) => s.toJson()).toList()));

  Future<String?> activeId() async =>
      (await SharedPreferences.getInstance()).getString(_kActive);

  Future<void> setActive(String? id) async {
    final p = await SharedPreferences.getInstance();
    id == null ? await p.remove(_kActive) : await p.setString(_kActive, id);
  }

  Future<List<Channel>> loadChannels(String key) => JsonPrefs.loadChannels(key);
  Future<void> saveChannels(String key, List<Channel> l) => JsonPrefs.saveChannels(key, l);
}
