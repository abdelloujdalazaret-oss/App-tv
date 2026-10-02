enum ChannelType { live, movie, series }

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.url,
    required this.group,
    required this.type,
    this.logo,
    this.tvgId,
    this.userAgent,
    this.seriesId,
  });

  final String id;
  final String name;
  final String url;
  final String group;
  final ChannelType type;
  final String? logo;
  final String? tvgId;
  final String? userAgent;
  final int? seriesId; // Xtream : identifiant de série (épisodes chargés à la demande)

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'group': group,
        'type': type.name,
        'logo': logo,
        'tvgId': tvgId,
        'ua': userAgent,
        'seriesId': seriesId,
      };

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        url: j['url'] as String? ?? '',
        group: j['group'] as String? ?? '',
        type: ChannelType.values.firstWhere((t) => t.name == j['type'],
            orElse: () => ChannelType.live),
        logo: j['logo'] as String?,
        tvgId: j['tvgId'] as String?,
        userAgent: j['ua'] as String?,
        seriesId: j['seriesId'] as int?,
      );
}
