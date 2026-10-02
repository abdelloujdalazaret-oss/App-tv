import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/debounce.dart';
import '../../models/channel.dart';
import '../../services/xtream_service.dart';
import '../player/player_screen.dart';
import 'channel_tile.dart';

/// Colonne GAUCHE : catégories. Colonne DROITE : chaînes de la catégorie.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> with SingleTickerProviderStateMixin {
  static const _types = [ChannelType.live, ChannelType.movie, ChannelType.series];
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _deb = Debouncer(const Duration(milliseconds: 250));
  final _search = TextEditingController();
  String _query = '';
  String _cat = 'all';
  bool _grid = false;
  String? _sub;

  List<Channel> _cache = const [];
  String _cacheKey = '';
  List<String> _cats = const [];
  String _catsKey = '';

  ChannelType get _type => _types[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _cat = 'all');
        context.read<AppState>().loadType(_type);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _deb.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Channel> _filtered(AppState app) {
    final key =
        '${app.version}|${app.favorites.length}|${app.recents.length}|${_type.index}|$_cat|$_query|${app.activeId}';
    if (key == _cacheKey) return _cache;
    Iterable<Channel> list;
    if (_cat == 'fav') {
      list = app.favorites.where((c) => c.type == _type);
    } else if (_cat == 'recent') {
      list = app.recents.where((c) => c.type == _type);
    } else {
      list = app.items[_type]!;
      if (_cat != 'all') list = list.where((c) => c.group == _cat);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q));
    }
    _cacheKey = key;
    return _cache = list.toList();
  }

  List<String> _categories(AppState app) {
    final key = '${app.version}|${_type.index}|${app.activeId}';
    if (key == _catsKey) return _cats;
    final seen = <String>{};
    for (final c in app.items[_type]!) {
      seen.add(c.group);
    }
    _catsKey = key;
    return _cats = seen.toList();
  }

  void _open(AppState app, List<Channel> list, int i) {
    final c = list[i];
    if (c.type == ChannelType.series && c.seriesId != null) {
      _episodes(app, c);
      return;
    }
    app.addRecent(c);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PlayerScreen(playlist: list, index: i)));
  }

  void _episodes(AppState app, Channel serie) {
    final sub = app.active;
    if (sub == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.field,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (_, scroll) => FutureBuilder<List<Channel>>(
          future: XtreamService(sub, app.net).episodes(serie.seriesId!),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final eps = snap.data ?? const <Channel>[];
            if (snap.hasError || eps.isEmpty) {
              return const Center(child: Text('Aucun épisode disponible.'));
            }
            return ListView.builder(
              controller: scroll,
              itemCount: eps.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(eps[i].name),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlayerScreen(playlist: eps, index: i)));
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.active == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.playlist_add, size: 56, color: Colors.white38),
          const SizedBox(height: 12),
          const Text('Aucun abonnement'),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.add),
              child: const Text('Ajouter un abonnement')),
        ]),
      );
    }

    // Changement d'abonnement actif → rechargement.
    if (_sub != app.activeId) {
      _sub = app.activeId;
      _cat = 'all';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppState>().loadType(_type);
      });
    }

    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final side = landscape ? 220.0 : 130.0;
    final list = _filtered(app);
    final cats = _categories(app);

    return SafeArea(
      child: Column(children: [
        TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Direct'),
          Tab(text: 'Films'),
          Tab(text: 'Séries'),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Rechercher…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          }),
                ),
                onChanged: (v) => _deb.run(() {
                  if (mounted) setState(() => _query = v.trim());
                }),
              ),
            ),
            IconButton(
              tooltip: _grid ? 'Afficher en liste' : 'Afficher en grille',
              icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => _grid = !_grid),
            ),
            IconButton(
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
              onPressed: () => app.loadType(_type, force: true),
            ),
          ]),
        ),
        Expanded(
          child: Row(children: [
            SizedBox(width: side, child: _catColumn(app, cats)),
            const VerticalDivider(width: 1),
            Expanded(child: _content(app, list)),
          ]),
        ),
      ]),
    );
  }

  Widget _catColumn(AppState app, List<String> cats) {
    final entries = <MapEntry<String, String>>[
      const MapEntry('all', 'Toutes'),
      const MapEntry('fav', '♥ Favoris'),
      const MapEntry('recent', 'Récents'),
      ...cats.map((c) => MapEntry(c, c)),
    ];
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        final sel = _cat == e.key;
        return InkWell(
          onTap: () => setState(() => _cat = e.key),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? AppColors.accent.withOpacity(.2) : null,
              borderRadius: BorderRadius.circular(12),
              border: sel ? Border.all(color: AppColors.accent) : null,
            ),
            child: Text(e.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel ? AppColors.accent : null)),
          ),
        );
      },
    );
  }

  Widget _content(AppState app, List<Channel> list) {
    if (app.loading && app.items[_type]!.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (app.error != null && app.items[_type]!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 44, color: Colors.white38),
            const SizedBox(height: 12),
            Text(app.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => app.loadType(_type, force: true), child: const Text('Réessayer')),
            TextButton(
                onPressed: () => Navigator.pushNamed(context, Routes.settings),
                child: const Text('Paramètres réseau')),
          ]),
        ),
      );
    }
    if (list.isEmpty) return const Center(child: Text('Aucun élément'));

    Widget tile(int i) => ChannelTile(
          channel: list[i],
          grid: _grid,
          favorite: app.isFav(list[i]),
          onTap: () => _open(app, list, i),
          onFav: () => app.toggleFav(list[i]),
        );

    return _grid
        ? GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: .95),
            itemCount: list.length,
            itemBuilder: (_, i) => tile(i),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => tile(i),
          );
  }
}
