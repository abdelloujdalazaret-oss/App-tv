import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/channel.dart';

/// Listes de chaînes (favoris, récents) stockées en JSON.
class JsonPrefs {
  static Future<List<Channel>> loadChannels(String key) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveChannels(String key, List<Channel> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(list.map((c) => c.toJson()).toList()));
  }
}
