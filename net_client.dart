import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../services/network_settings.dart';

class NetException implements Exception {
  NetException(this.message);
  final String message;
  @override
  String toString() => message;
}

const kBlockedHint =
    'Votre opérateur peut bloquer ce serveur. Essayez un DNS sécurisé, un proxy ou un VPN.';

/// Client HTTP avec DoH, proxy, User-Agent, en-têtes, redirections,
/// essai http↔https et réessais avec backoff.
class NetClient {
  NetClient(this.s);
  final NetworkSettings s;
  static final Map<String, String> _dohCache = {};

  HttpClient _client() {
    final c = HttpClient()
      ..connectionTimeout = Duration(seconds: s.timeoutSec)
      ..userAgent = s.userAgent
      ..autoUncompress = true
      // Les serveurs IPTV utilisent souvent des certificats auto-signés.
      ..badCertificateCallback = (_, __, ___) => true;
    final proxy = s.httpProxy;
    if (proxy != null) c.findProxy = (_) => 'PROXY $proxy';
    c.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;
      var target = host;
      if (proxyHost == null && s.dohEnabled) {
        target = await resolveDoh(host) ?? host; // repli sur le DNS système
      }
      return Socket.startConnect(target, port);
    };
    return c;
  }

  /// Résout [host] via DoH (JSON). Retourne null en cas d'échec.
  Future<String?> resolveDoh(String host) async {
    if (InternetAddress.tryParse(host) != null) return null;
    final key = '${s.dohEndpoint}|$host';
    if (_dohCache.containsKey(key)) return _dohCache[key];
    final base = s.dohEndpoint;
    if (base.isEmpty) return null;
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final sep = base.contains('?') ? '&' : '?';
      final req = await c.getUrl(Uri.parse('$base${sep}name=$host&type=A'));
      req.headers.set('accept', 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 6));
      final body = await res.transform(utf8.decoder).join();
      final answers = (jsonDecode(body)['Answer'] as List?)
          ?.where((a) => a['type'] == 1)
          .toList();
      if (answers != null && answers.isNotEmpty) {
        final ip = answers.first['data'] as String;
        _dohCache[key] = ip;
        return ip;
      }
    } catch (_) {
      // on retombe sur le DNS système
    } finally {
      c.close(force: true);
    }
    return null;
  }

  Future<String> _fetch(Uri uri, Map<String, String>? headers) async {
    final c = _client();
    try {
      final req = await c.getUrl(uri);
      req.followRedirects = true;
      req.maxRedirects = 8;
      s.headerMap.forEach(req.headers.set);
      headers?.forEach(req.headers.set);
      final res = await req.close().timeout(Duration(seconds: s.timeoutSec * 3));
      if (res.statusCode >= 400) throw HttpException('HTTP ${res.statusCode}');
      return await res
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
    } finally {
      c.close(force: true);
    }
  }

  /// Code HTTP seul (utilisé par le diagnostic).
  Future<int> status(String url) async {
    final c = _client();
    try {
      final req = await c.getUrl(Uri.parse(url));
      final res = await req.close().timeout(Duration(seconds: s.timeoutSec));
      await res.drain<void>();
      return res.statusCode;
    } finally {
      c.close(force: true);
    }
  }

  Future<String> getText(String url, {Map<String, String>? headers}) async {
    final u = Uri.parse(url);
    final candidates = <Uri>[u];
    if (s.autoScheme && (u.scheme == 'http' || u.scheme == 'https')) {
      candidates.add(u.replace(scheme: u.scheme == 'https' ? 'http' : 'https'));
    }
    Object? last;
    for (final cand in candidates) {
      for (var attempt = 0; attempt <= s.retries; attempt++) {
        try {
          return await _fetch(cand, headers);
        } on HttpException catch (e) {
          last = e;
          // 401/403/404 : inutile de réessayer la même URL
          if (e.message.contains('HTTP 4')) break;
        } catch (e) {
          last = e;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    }
    final detail = last is HttpException && last.message.contains('HTTP 4')
        ? 'Le serveur a refusé la requête (${last.message}). Vérifiez vos identifiants.'
        : 'Connexion impossible. $kBlockedHint';
    throw NetException(detail);
  }
}
