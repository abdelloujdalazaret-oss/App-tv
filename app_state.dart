import 'package:flutter/foundation.dart';
import '../core/network/net_client.dart';
import '../models/channel.dart';
import '../models/subscription.dart';
import '../services/m3u_parser.dart';
import '../services/network_settings.dart';
import '../services/subscription_store.dart';
import '../services/xtream_service.dart';

/// État global : abonnements, contenu chargé, favoris, récents.
class AppState extends ChangeNotifier {
  AppState(this.settings);
  final NetworkSettings settings;
  final SubscriptionStore _store = SubscriptionStore();
  NetClient get net => NetClient(settings);

  List<Subscription> subs = [];
  String? activeId;
  bool ready = false;
  bool loading = false;
  String? error;
  int version = 0; // incrémenté à chaque changement de contenu
  final Map<ChannelType, List<Channel>> items = {
    for (final t in ChannelType.values) t: <Channel>[]
  };
  final Set<ChannelType> _loaded = {};
  List<Channel> favorites = [];
  List<Channel> recents = [];
  bool _initDone = false;

  Subscription? get active {
    for (final s in subs) {
      if (s.id == activeId) return s;
    }
    return null;
  }

  Future<void> init() async {
    if (_initDone) return;
    _initDone = true;
    subs = await _store.load();
    activeId = await _store.activeId();
    if (active == null && subs.isNotEmpty) {
      activeId = subs.first.id;
      await _store.setActive(activeId);
    }
    await _loadLocalLists();
    ready = true;
    notifyListeners();
  }

  Future<void> _loadLocalLists() async {
    favorites = activeId == null ? [] : await _store.loadChannels('fav_$activeId');
    recents = activeId == null ? [] : await _store.loadChannels('rec_$activeId');
  }

  // ---- Abonnements -------------------------------------------------------
  Future<void> upsert(Subscription s) async {
    final i = subs.indexWhere((e) => e.id == s.id);
    i >= 0 ? subs[i] = s : subs.add(s);
    await _store.save(subs);
    if (activeId == null || i < 0 && subs.length == 1) {
      await select(s.id);
    } else if (s.id == activeId) {
      await select(s.id, force: true);
    }
    notifyListeners();
  }

  Future<void> select(String id, {bool force = false}) async {
    if (id == activeId && !force) return;
    activeId = id;
    await _store.setActive(id);
    _loaded.clear();
    for (final t in ChannelType.values) {
      items[t] = [];
    }
    error = null;
    await _loadLocalLists();
    version++;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    subs.removeWhere((s) => s.id == id);
    await _store.save(subs);
    if (id == activeId) {
      activeId = null;
      if (subs.isNotEmpty) {
        await select(subs.first.id, force: true);
      } else {
        await _store.setActive(null);
        _loaded.clear();
        for (final t in ChannelType.values) {
          items[t] = [];
        }
        favorites = [];
        recents = [];
        version++;
      }
    }
    notifyListeners();
  }

  /// Teste la connexion ; lance NetException en cas d'échec.
  Future<String> testConnection(Subscription s) async {
    if (s.type == SubType.m3u) {
      final text = await net.getText(s.url);
      final n = (await compute(parseM3uIsolate, text)).length;
      if (n == 0) throw NetException('Le lien répond mais ne contient aucune chaîne M3U.');
      return 'Connexion réussie : $n éléments trouvés.';
    }
    final info = await XtreamService(s, net).authenticate();
    return 'Connexion réussie. $info';
  }

  // ---- Contenu -----------------------------------------------------------
  Future<void> loadType(ChannelType t, {bool force = false}) async {
    final sub = active;
    if (sub == null) return;
    if (!force && _loaded.contains(t)) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (sub.type == SubType.m3u) {
        if (force || _loaded.isEmpty) {
          final text = await net.getText(sub.url);
          _splitM3u(await compute(parseM3uIsolate, text));
        }
      } else {
        final x = XtreamService(sub, net);
        try {
          items[t] = await x.channels(t);
          _loaded.add(t);
        } catch (_) {
          // Repli sur get.php si player_api.php échoue
          final text = await net.getText(x.m3uUrl);
          _splitM3u(await compute(parseM3uIsolate, text));
        }
      }
    } on NetException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Erreur de chargement : $e';
    }
    loading = false;
    version++;
    notifyListeners();
  }

  void _splitM3u(List<Channel> all) {
    for (final k in ChannelType.values) {
      items[k] = all.where((c) => c.type == k).toList();
    }
    _loaded.addAll(ChannelType.values);
  }

  // ---- Favoris / récents -------------------------------------------------
  bool isFav(Channel c) => favorites.any((f) => f.id == c.id);

  Future<void> toggleFav(Channel c) async {
    isFav(c) ? favorites.removeWhere((f) => f.id == c.id) : favorites.insert(0, c);
    notifyListeners();
    await _store.saveChannels('fav_$activeId', favorites);
  }

  Future<void> addRecent(Channel c) async {
    recents.removeWhere((r) => r.id == c.id);
    recents.insert(0, c);
    if (recents.length > 30) recents = recents.sublist(0, 30);
    await _store.saveChannels('rec_$activeId', recents);
  }

  Future<void> clearRecents() async {
    recents = [];
    notifyListeners();
    await _store.saveChannels('rec_$activeId', recents);
  }
}
