import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../app/constants.dart';
import '../../app/routes.dart';

/// Intro 2–3 s : logo animé (fade + scale) avec son de démarrage.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<double> _scale =
      Tween(begin: .7, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _c.forward();
    _run();
  }

  Future<void> _run() async {
    final app = context.read<AppState>();
    unawaited(_playSound());
    await Future.wait([app.init(), Future<void>.delayed(AppConst.introDuration)]);
    if (!mounted) return;
    // Aucun abonnement → « Ajouter un abonnement », sinon accueil (dernière liste).
    Navigator.of(context)
        .pushReplacementNamed(app.subs.isEmpty ? Routes.add : Routes.home);
  }

  Future<void> _playSound() async {
    try {
      await _audio.play(AssetSource('sounds/intro.mp3'));
    } catch (_) {/* le son est facultatif */}
  }

  @override
  void dispose() {
    _c.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/images/logo.png', width: 170, height: 170),
              ),
              const SizedBox(height: 20),
              const Text(AppConst.appName,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ]),
          ),
        ),
      ),
    );
  }
}
