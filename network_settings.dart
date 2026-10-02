import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants.dart';

/// Paramètres réseau et assistance. Tout est désactivé par défaut.
class NetworkSettings extends ChangeNotifier {
  NetworkSettings._(this._p);
  final SharedPreferences _p;

  static Future<NetworkSettings> load() async =>
      NetworkSettings._(await SharedPreferences.getInstance());

  bool get dohEnabled => _p.getBool('doh') ?? false;
  String get dohProvider => _p.getString('doh_provider') ?? 'cloudflare';
  String get dohCustom => _p.getString('doh_custom') ?? '';
  bool get proxyEnabled => _p.getBool('proxy') ?? false;
  String get proxyUrl => _p.getString('proxy_url') ?? '';
  String get userAgent => _p.getString('ua') ?? AppConst.defaultUserAgent;
  String get headersText => _p.getString('headers') ?? '';
  bool get autoScheme => _p.getBool('auto_scheme') ?? false;
  int get timeoutSec => _p.getInt('timeout') ?? 15;
  int get retries => _p.getInt('retries') ?? 2;
  String get supportEmail => _p.getString('support_email') ?? '';
  String get supportWhatsapp => _p.getString('support_wa') ?? '';

  Future<void> setBool(String k, bool v) async {
    await _p.setBool(k, v);
    notifyListeners();
  }

  Future<void> setString(String k, String v) async {
    await _p.setString(k, v);
    notifyListeners();
  }

  Future<void> setInt(String k, int v) async {
    await _p.setInt(k, v);
    notifyListeners();
  }

  /// URL du serveur DoH (format JSON) selon le fournisseur choisi.
  String get dohEndpoint {
    switch (dohProvider) {
      case 'google':
        return 'https://8.8.8.8/resolve';
      case 'quad9':
        return 'https://9.9.9.9:5053/dns-query';
      case 'custom':
        return dohCustom.trim();
      default:
        return 'https://1.1.1.1/dns-query';
    }
  }

  /// Proxy HTTP « hôte:port » (les proxys SOCKS ne sont appliqués qu'à mpv).
  String? get httpProxy {
    if (!proxyEnabled || proxyUrl.trim().isEmpty) return null;
    final u = proxyUrl.trim();
    if (u.startsWith('socks')) return null;
    return u.replaceFirst(RegExp(r'^https?://'), '');
  }

  /// Valeur pour la propriété mpv « http-proxy ».
  String? get mpvProxy {
    if (!proxyEnabled || proxyUrl.trim().isEmpty) return null;
    final u = proxyUrl.trim();
    return u.contains('://') ? u : 'http://$u';
  }

  Map<String, String> get headerMap {
    final m = <String, String>{};
    for (final l in headersText.split('\n')) {
      final i = l.indexOf(':');
      if (i > 0) m[l.substring(0, i).trim()] = l.substring(i + 1).trim();
    }
    return m;
  }
}
