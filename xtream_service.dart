import 'package:flutter/foundation.dart';
import '../core/network/net_client.dart';
import '../core/parsers/json_isolate.dart';
import '../models/category.dart';
import '../models/channel.dart';
import '../models/subscription.dart';

/// Accès à player_api.php (Xtream Codes) + repli get.php.
class XtreamService {
  XtreamService(this.sub, this.net);
  final Subscription sub;
  final NetClient net;

  String get base => sub.xtreamBase;
  String get m3uUrl => Uri.parse('$base/get.php').replace(queryParameters: {
        'username': sub.username,
        'password': sub.password,
        'type': 'm3u_plus',
        'output': 'ts',
      }).toString();

  String _api([String? action, Map<String, String>? extra]) =>
      Uri.parse('$base/player_api.php').replace(queryParameters: {
        'username': sub.username,
        'password': sub.password,
        if (action != null) 'action': action,
        ...?extra,
      }).toString();

  Future<dynamic> _json(String url) async =>
      compute(decodeJsonIsolate, await net.getText(url));

  /// Vérifie les identifiants ; retourne un court résumé.
  Future<String> authenticate() async {
    final j = await _json(_api());
    final info = (j is Map) ? j['user_info'] : null;
    if (info is! Map || '${info['auth']}' != '1') {
      throw NetException('Identifiants refusés par le serveur.');
    }
    final status = info['status'] ?? 'Active';
    return 'Compte $status';
  }

  Future<List<Category>> categories(String kind) async {
    final j = await _json(_api('get_${kind}_categories'));
    if (j is! List) return [];
    return j
        .map((e) => Category('${e['category_id']}', '${e['category_name']}'))
        .toList();
  }

  Future<List<Channel>> channels(ChannelType t) async {
    final kind = t == ChannelType.live ? 'live' : t == ChannelType.movie ? 'vod' : 'series';
    final cats = {for (final c in await categories(kind)) c.id: c.name};
    final j = await _json(_api(t == ChannelType.live
        ? 'get_live_streams'
        : t == ChannelType.movie
            ? 'get_vod_streams'
            : 'get_series'));
    if (j is! List) return [];
    final u = Uri.encodeComponent(sub.username), p = Uri.encodeComponent(sub.password);
    final out = <Channel>[];
    for (final e in j) {
      if (e is! Map) continue;
      final group = cats['${e['category_id']}'] ?? 'Sans catégorie';
      final name = '${e['name'] ?? ''}';
      if (t == ChannelType.series) {
        final sid = int.tryParse('${e['series_id']}');
        if (sid == null) continue;
        out.add(Channel(
            id: 'series_$sid', name: name, url: '', group: group, type: t,
            logo: _s(e['cover']), seriesId: sid));
      } else if (t == ChannelType.movie) {
        final ext = _s(e['container_extension']) ?? 'mp4';
        out.add(Channel(
            id: 'vod_${e['stream_id']}', name: name, group: group, type: t,
            url: '$base/movie/$u/$p/${e['stream_id']}.$ext', logo: _s(e['stream_icon'])));
      } else {
        out.add(Channel(
            id: 'live_${e['stream_id']}', name: name, group: group, type: t,
            url: '$base/live/$u/$p/${e['stream_id']}.ts',
            logo: _s(e['stream_icon']), tvgId: _s(e['epg_channel_id'])));
      }
    }
    return out;
  }

  Future<List<Channel>> episodes(int seriesId) async {
    final j = await _json(_api('get_series_info', {'series_id': '$seriesId'}));
    final out = <Channel>[];
    final eps = (j is Map) ? j['episodes'] : null;
    final u = Uri.encodeComponent(sub.username), p = Uri.encodeComponent(sub.password);
    void add(dynamic season, dynamic e) {
      if (e is! Map) return;
      final ext = _s(e['container_extension']) ?? 'mp4';
      out.add(Channel(
        id: 'ep_${e['id']}',
        name: 'S$season · É${e['episode_num']} - ${e['title'] ?? ''}',
        url: '$base/series/$u/$p/${e['id']}.$ext',
        group: 'Saison $season',
        type: ChannelType.series,
      ));
    }

    if (eps is Map) {
      eps.forEach((season, list) {
        if (list is List) for (final e in list) add(season, e);
      });
    } else if (eps is List) {
      for (var i = 0; i < eps.length; i++) {
        final l = eps[i];
        if (l is List) for (final e in l) add(i + 1, e);
      }
    }
    return out;
  }

  String? _s(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }
}
