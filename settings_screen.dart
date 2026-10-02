import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/network/diagnostics.dart';
import '../../services/network_settings.dart';

/// Paramètres > Réseau et Assistance (tout est désactivé par défaut).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _diagnose(BuildContext context) async {
    final app = context.read<AppState>();
    final st = context.read<NetworkSettings>();
    final sub = app.active;
    final url = sub == null
        ? 'https://www.google.com'
        : (sub.type.name == 'm3u' ? sub.url : sub.xtreamBase);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnostic réseau'),
        content: FutureBuilder<List<DiagStep>>(
          future: Diagnostics.run(st, url),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                  height: 80, child: Center(child: CircularProgressIndicator()));
            }
            final steps = snap.data!;
            final failed = steps.any((s) => !s.ok);
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final s in steps)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(s.ok ? Icons.check_circle : Icons.cancel,
                      color: s.ok ? Colors.greenAccent : Colors.redAccent),
                  title: Text(s.label),
                  subtitle: Text(s.detail),
                ),
              if (failed)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Votre opérateur peut bloquer ce serveur. Essayez un DNS sécurisé, un proxy ou un VPN.',
                      style: TextStyle(color: Colors.amber)),
                ),
            ]);
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<NetworkSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _h('DNS sécurisé (DoH)'),
        SwitchListTile(
          title: const Text('Activer le DNS sécurisé'),
          subtitle: const Text('Résout les noms d\'hôte via DoH, repli sur le DNS système.'),
          value: s.dohEnabled,
          onChanged: (v) => s.setBool('doh', v),
        ),
        if (s.dohEnabled) ...[
          DropdownButtonFormField<String>(
            value: s.dohProvider,
            decoration: const InputDecoration(labelText: 'Fournisseur'),
            items: const [
              DropdownMenuItem(value: 'cloudflare', child: Text('Cloudflare 1.1.1.1')),
              DropdownMenuItem(value: 'google', child: Text('Google 8.8.8.8')),
              DropdownMenuItem(value: 'quad9', child: Text('Quad9')),
              DropdownMenuItem(value: 'custom', child: Text('Personnalisé')),
            ],
            onChanged: (v) => s.setString('doh_provider', v ?? 'cloudflare'),
          ),
          if (s.dohProvider == 'custom') ...[
            const SizedBox(height: 12),
            _field('URL DoH (format JSON)', s.dohCustom, (v) => s.setString('doh_custom', v),
                hint: 'https://dns.exemple.com/dns-query'),
          ],
        ],
        const SizedBox(height: 16),
        _h('Proxy'),
        SwitchListTile(
          title: const Text('Activer le proxy'),
          subtitle: const Text('HTTP pour les requêtes ; HTTP/SOCKS pour le flux (mpv).'),
          value: s.proxyEnabled,
          onChanged: (v) => s.setBool('proxy', v),
        ),
        if (s.proxyEnabled)
          _field('Adresse du proxy', s.proxyUrl, (v) => s.setString('proxy_url', v),
              hint: 'hôte:port ou socks5://hôte:port'),
        const SizedBox(height: 16),
        _h('Requêtes'),
        _field('User-Agent', s.userAgent, (v) => s.setString('ua', v.isEmpty ? AppConst.defaultUserAgent : v)),
        const SizedBox(height: 12),
        _field('En-têtes personnalisés (un par ligne, Nom: valeur)', s.headersText,
            (v) => s.setString('headers', v), lines: 3),
        SwitchListTile(
          title: const Text('Essai automatique http ↔ https'),
          value: s.autoScheme,
          onChanged: (v) => s.setBool('auto_scheme', v),
        ),
        ListTile(
          title: Text('Délai d\'attente : ${s.timeoutSec} s'),
          subtitle: Slider(
              value: s.timeoutSec.toDouble(), min: 5, max: 60, divisions: 11,
              onChanged: (v) => s.setInt('timeout', v.round())),
        ),
        ListTile(
          title: Text('Réessais : ${s.retries}'),
          subtitle: Slider(
              value: s.retries.toDouble(), min: 0, max: 5, divisions: 5,
              onChanged: (v) => s.setInt('retries', v.round())),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _diagnose(context),
          icon: const Icon(Icons.network_check),
          label: const Text('Diagnostiquer'),
        ),
        const SizedBox(height: 24),
        _h('Assistance'),
        _field('E-mail d\'assistance', s.supportEmail, (v) => s.setString('support_email', v.trim()),
            keyboard: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _field('Numéro WhatsApp (avec indicatif)', s.supportWhatsapp,
            (v) => s.setString('support_wa', v.trim()), keyboard: TextInputType.phone),
      ]),
    );
  }

  Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t.toUpperCase(),
          style: const TextStyle(color: AppColors.accent, fontSize: 12, letterSpacing: 1)));

  Widget _field(String label, String value, ValueChanged<String> onChanged,
          {String? hint, int lines = 1, TextInputType? keyboard}) =>
      TextFormField(
        initialValue: value,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: onChanged,
      );
}
