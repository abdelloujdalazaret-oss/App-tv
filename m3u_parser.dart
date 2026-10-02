import '../models/channel.dart';

/// Parseur M3U tolérant : BOM, guillemets simples/doubles, #EXTGRP,
/// #EXTVLCOPT http-user-agent, attributs tvg-*.
class M3uParser {
  static final _attrDouble = RegExp(r'([\w-]+)="([^"]*)"');
  static final _attrSingle = RegExp(r"([\w-]+)='([^']*)'");

  static List<Channel> parse(String raw) {
    final text = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    final out = <Channel>[];
    Map<String, String> attrs = {};
    String? name, extGrp, ua;
    var hasInf = false;

    for (final lineRaw in text.split(RegExp(r'\r?\n'))) {
      final line = lineRaw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        attrs = {};
        var end = 0;
        for (final m in _attrDouble.allMatches(line)) {
          attrs[m.group(1)!.toLowerCase()] = m.group(2)!;
          if (m.end > end) end = m.end;
        }
        for (final m in _attrSingle.allMatches(line)) {
          attrs.putIfAbsent(m.group(1)!.toLowerCase(), () => m.group(2)!);
          if (m.end > end) end = m.end;
        }
        // La virgule du titre se trouve APRÈS le dernier attribut.
        final comma = line.indexOf(',', end);
        name = comma >= 0 ? line.substring(comma + 1).trim() : null;
        hasInf = true;
      } else if (line.startsWith('#EXTGRP:')) {
        extGrp = line.substring(8).trim();
      } else if (line.toUpperCase().startsWith('#EXTVLCOPT:')) {
        final opt = line.substring(11);
        final i = opt.indexOf('=');
        if (i > 0 && opt.substring(0, i).toLowerCase() == 'http-user-agent') {
          ua = opt.substring(i + 1).trim();
        }
      } else if (line.startsWith('#')) {
        continue;
      } else if (line.contains('://')) {
        var title = (name ?? '').replaceAll('"', '').trim();
        if (title.isEmpty) title = attrs['tvg-name'] ?? '';
        if (title.isEmpty) title = hasInf ? 'Sans nom' : line;
        final lower = line.toLowerCase();
        final type = lower.contains('/movie/')
            ? ChannelType.movie
            : lower.contains('/series/')
                ? ChannelType.series
                : ChannelType.live;
        final group = (attrs['group-title']?.trim().isNotEmpty ?? false)
            ? attrs['group-title']!.trim()
            : (extGrp?.isNotEmpty ?? false)
                ? extGrp!
                : 'Sans catégorie';
        final logo = attrs['tvg-logo'];
        out.add(Channel(
          id: line,
          name: title,
          url: line,
          group: group,
          type: type,
          logo: (logo == null || logo.isEmpty) ? null : logo,
          tvgId: attrs['tvg-id'],
          userAgent: ua,
        ));
        attrs = {};
        name = null;
        extGrp = null;
        ua = null;
        hasInf = false;
      }
    }
    return out;
  }
}

/// Fonction de premier niveau, utilisable avec compute() (Isolate).
List<Channel> parseM3uIsolate(String text) => M3uParser.parse(text);
