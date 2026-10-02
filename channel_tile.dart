import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/channel.dart';

class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    required this.grid,
    required this.favorite,
    required this.onTap,
    required this.onFav,
  });
  final Channel channel;
  final bool grid, favorite;
  final VoidCallback onTap, onFav;

  Widget _logo(double size) {
    final url = channel.logo;
    final fallback = Icon(Icons.tv, size: size * .6, color: Colors.white38);
    if (url == null || url.isEmpty) return Center(child: fallback);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      width: size,
      height: size,
      errorWidget: (_, __, ___) => Center(child: fallback),
      placeholder: (_, __) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heart = IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onFav,
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_border,
          color: favorite ? Colors.redAccent : Colors.white54, size: 20),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(8),
        child: grid
            ? Column(children: [
                Expanded(child: _logo(80)),
                Row(children: [
                  Expanded(
                      child: Text(channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))),
                  heart,
                ]),
              ])
            : Row(children: [
                SizedBox(width: 48, height: 48, child: _logo(48)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                heart,
              ]),
      ),
    );
  }
}
