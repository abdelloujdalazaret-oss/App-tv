import 'package:flutter_test/flutter_test.dart';
import 'package:player_flow/models/channel.dart';
import 'package:player_flow/services/m3u_parser.dart';

void main() {
  test('parse attributs tvg-* et group-title', () {
    const m3u = '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="bein7" tvg-name="BEIN 7" tvg-logo="http://x/l.png" group-title="Sport, FR",BEIN SPORTS 7\n'
        'http://srv/live/u/p/1.ts\n';
    final r = M3uParser.parse(m3u);
    expect(r.length, 1);
    expect(r.first.name, 'BEIN SPORTS 7');
    expect(r.first.group, 'Sport, FR'); // virgule dans le groupe tolérée
    expect(r.first.logo, 'http://x/l.png');
    expect(r.first.tvgId, 'bein7');
    expect(r.first.type, ChannelType.live);
  });

  test('BOM, #EXTGRP et #EXTVLCOPT user-agent', () {
    const m3u = '\uFEFF#EXTM3U\n'
        '#EXTINF:-1,Chaîne A\n#EXTGRP:Infos\n#EXTVLCOPT:http-user-agent=MonAgent/1.0\n'
        'https://srv/a.m3u8\n';
    final r = M3uParser.parse(m3u);
    expect(r.first.group, 'Infos');
    expect(r.first.userAgent, 'MonAgent/1.0');
    expect(r.first.name, 'Chaîne A');
  });

  test('détection films / séries par URL et guillemets simples', () {
    const m3u = "#EXTINF:-1 group-title='Films',Film 1\nhttp://s/movie/u/p/10.mp4\n"
        '#EXTINF:-1 group-title="Séries",Ep 1\nhttp://s/series/u/p/20.mkv\r\n';
    final r = M3uParser.parse(m3u);
    expect(r[0].type, ChannelType.movie);
    expect(r[0].group, 'Films');
    expect(r[1].type, ChannelType.series);
  });

  test('entrée sans nom ni catégorie', () {
    final r = M3uParser.parse('#EXTINF:-1,\nhttp://s/x.ts\n');
    expect(r.first.group, 'Sans catégorie');
    expect(r.first.name, isNotEmpty);
  });
}
