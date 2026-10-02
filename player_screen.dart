import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app/theme.dart';
import '../../core/network/net_client.dart';
import '../../models/channel.dart';
import '../../services/network_settings.dart';

/// Lecteur plein écran.
/// IMPORTANT : la vidéo est dans un Positioned.fill d'un Stack, sans Column,
/// Expanded, AspectRatio ni SafeArea → aucune bande noire ni petit rectangle.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.playlist, required this.index});
  final List<Channel> playlist;
  final int index;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Un seul Player pour tout le zapping (pas de recréation).
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  final List<StreamSubscription> _subs = [];
  late NetworkSettings _settings;

  late int _i = widget.index;
  BoxFit _fit = BoxFit.cover; // cover = « Remplir », contain = « Ajuster »
  bool _show = true;
  bool _buffering = true;
  bool _playing = false;
  String? _error;
  int _retry = 0;
  double _vol = 100;
  Tracks _tracks = const Tracks();
  Timer? _hideTimer;
  Timer? _retryTimer;

  Channel get _ch => widget.playlist[_i];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WakelockPlus.enable();
    _settings = context.read<NetworkSettings>();

    _subs.addAll([
      _player.stream.error.listen(_onError),
      _player.stream.buffering.listen((b) {
        if (!mounted) return;
        setState(() => _buffering = b);
        if (!b && _playing) _retry = 0;
      }),
      _player.stream.playing.listen((p) {
        if (!mounted) return;
        setState(() => _playing = p);
      }),
      _player.stream.tracks.listen((t) {
        if (mounted) setState(() => _tracks = t);
      }),
    ]);
    _start();
    _scheduleHide();
  }

  Future<void> _start() async {
    final p = _player.platform;
    if (p is NativePlayer) {
      await p.setProperty('user-agent', _settings.userAgent);
      await p.setProperty('network-timeout', '${_settings.timeoutSec}');
      final proxy = _settings.mpvProxy;
      if (proxy != null) await p.setProperty('http-proxy', proxy);
    }
    await _open();
  }

  Future<void> _open() async {
    if (!mounted) return;
    setState(() {
      _error = null;
      _buffering = true;
    });
    final headers = <String, String>{..._settings.headerMap};
    if (_ch.userAgent != null) headers['User-Agent'] = _ch.userAgent!;
    await _player.open(Media(_ch.url, httpHeaders: headers));
  }

  void _onError(String e) {
    if (!mounted || e.trim().isEmpty) return;
    if (_retry < 3) {
      _retry++;
      setState(() => _buffering = true);
      _retryTimer?.cancel();
      // Reconnexion automatique : 2 s, 4 s, 8 s (backoff)
      _retryTimer = Timer(Duration(seconds: 1 << _retry), _open);
    } else {
      setState(() {
        _buffering = false;
        _error = 'Impossible de lire ce flux.\n$kBlockedHint';
      });
    }
  }

  void _retryNow() {
    _retry = 0;
    _open();
  }

  void _go(int d) {
    final n = widget.playlist.length;
    if (n < 2) return;
    _retryTimer?.cancel();
    _retry = 0;
    setState(() => _i = (_i + d + n) % n);
    _open();
    _scheduleHide();
  }

  void _toggle() {
    setState(() => _show = !_show);
    if (_show) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _show = false);
    });
  }

  void _pickTrack<T>(String title, List<T> tracks, T current, String Function(T) label,
      void Function(T) onPick) {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.field,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          for (final t in tracks)
            ListTile(
              title: Text(label(t)),
              trailing: t == current ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () {
                onPick(t);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    ).whenComplete(_scheduleHide);
  }

  String _lbl(String id, String? title, String? lang) {
    if (id == 'auto') return 'Automatique';
    if (id == 'no') return 'Désactivés';
    return [title, lang].where((e) => e != null && e.isNotEmpty).join(' · ').ifEmpty('Piste $id');
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _retryTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    WakelockPlus.disable();
    // Restaure l'interface et l'orientation libre hors du lecteur.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Vidéo plein écran
          Positioned.fill(
            child: Video(
              controller: _video,
              fit: _fit,
              fill: Colors.black,
              controls: NoVideoControls,
            ),
          ),
          // 2) Zone tactile (affiche/masque les contrôles)
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toggle),
          ),
          if (_buffering && _error == null)
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          if (_error != null)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _retryNow,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer')),
                ]),
              ),
            ),
          // 3) Barre supérieure en superposition
          Positioned(
            top: 0, left: 0, right: 0,
            child: _overlay(
              top: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad.left + 8, pad.top + 4, pad.right + 8, 12),
                child: Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).maybePop()),
                  Expanded(
                      child: Text(_ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  IconButton(
                      tooltip: 'Précédent',
                      icon: const Icon(Icons.skip_previous),
                      onPressed: () => _go(-1)),
                  IconButton(
                      tooltip: 'Suivant',
                      icon: const Icon(Icons.skip_next),
                      onPressed: () => _go(1)),
                  TextButton.icon(
                    onPressed: () {
                      setState(() =>
                          _fit = _fit == BoxFit.cover ? BoxFit.contain : BoxFit.cover);
                      _scheduleHide();
                    },
                    icon: Icon(_fit == BoxFit.cover ? Icons.fit_screen : Icons.fullscreen),
                    label: Text(_fit == BoxFit.cover ? 'Ajuster' : 'Remplir'),
                  ),
                ]),
              ),
            ),
          ),
          // 4) Barre de contrôle en bas
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _overlay(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad.left + 12, 12, pad.right + 12, pad.bottom + 8),
                child: Row(children: [
                  IconButton(
                    iconSize: 34,
                    icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
                    onPressed: () {
                      _player.playOrPause();
                      _scheduleHide();
                    },
                  ),
                  const Icon(Icons.volume_up, size: 20),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      value: _vol,
                      min: 0,
                      max: 100,
                      onChanged: (v) {
                        setState(() => _vol = v);
                        _player.setVolume(v);
                      },
                      onChangeEnd: (_) => _scheduleHide(),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Piste audio',
                    icon: const Icon(Icons.audiotrack),
                    onPressed: () => _pickTrack<AudioTrack>(
                        'Piste audio',
                        _tracks.audio,
                        _player.state.track.audio,
                        (t) => _lbl(t.id, t.title, t.language),
                        _player.setAudioTrack),
                  ),
                  IconButton(
                    tooltip: 'Sous-titres',
                    icon: const Icon(Icons.subtitles),
                    onPressed: () => _pickTrack<SubtitleTrack>(
                        'Sous-titres',
                        _tracks.subtitle,
                        _player.state.track.subtitle,
                        (t) => _lbl(t.id, t.title, t.language),
                        _player.setSubtitleTrack),
                  ),
                  if (_tracks.video.length > 2)
                    IconButton(
                      tooltip: 'Qualité',
                      icon: const Icon(Icons.hd),
                      onPressed: () => _pickTrack<VideoTrack>(
                          'Qualité',
                          _tracks.video,
                          _player.state.track.video,
                          (t) => _lbl(t.id, t.title, t.language),
                          _player.setVideoTrack),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlay({required bool top, required Widget child}) => IgnorePointer(
        ignoring: !_show,
        child: AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: const [Colors.black87, Colors.transparent],
              ),
            ),
            child: child,
          ),
        ),
      );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
