enum SubType { m3u, xtream }

class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.type,
    this.url = '',
    this.server = '',
    this.username = '',
    this.password = '',
  });

  final String id;
  String name;
  SubType type;
  String url; // M3U
  String server; // Xtream
  String username;
  String password;

  String get typeLabel => type == SubType.m3u ? 'Lien M3U' : 'Xtream Codes';

  /// Adresse Xtream normalisée (http:// ajouté, pas de « / » final).
  String get xtreamBase {
    var s = server.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String get host {
    try {
      return Uri.parse(type == SubType.m3u ? url : xtreamBase).host;
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'url': url,
        'server': server,
        'username': username,
        'password': password,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: j['type'] == 'xtream' ? SubType.xtream : SubType.m3u,
        url: j['url'] as String? ?? '',
        server: j['server'] as String? ?? '',
        username: j['username'] as String? ?? '',
        password: j['password'] as String? ?? '',
      );
}
