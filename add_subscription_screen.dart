import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../models/subscription.dart';

/// Ajout / modification : lien M3U ou Xtream Codes, avec test de connexion.
class AddSubscriptionScreen extends StatefulWidget {
  const AddSubscriptionScreen({super.key, this.existing});
  final Subscription? existing;
  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _form = GlobalKey<FormState>();
  late SubType _type = widget.existing?.type ?? SubType.m3u;
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _url = TextEditingController(text: widget.existing?.url);
  late final _server = TextEditingController(text: widget.existing?.server);
  late final _user = TextEditingController(text: widget.existing?.username);
  late final _pass = TextEditingController(text: widget.existing?.password);
  bool _busy = false;
  bool _showPass = false;
  String? _result;
  bool _resultOk = false;

  @override
  void dispose() {
    for (final c in [_name, _url, _server, _user, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _paste(TextEditingController c) async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) setState(() => c.text = d!.text!.trim());
  }

  Subscription _build() {
    final host = Uri.tryParse(_type == SubType.m3u ? _url.text.trim() : 'http://${_server.text.trim()}')?.host ?? '';
    final app = context.read<AppState>();
    return Subscription(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isNotEmpty
          ? _name.text.trim()
          : (host.isNotEmpty ? host : 'Abonnement ${app.subs.length + 1}'),
      type: _type,
      url: _url.text.trim(),
      server: _server.text.trim(),
      username: _user.text.trim(),
      password: _pass.text.trim(),
    );
  }

  Future<bool> _test(Subscription s) async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final msg = await context.read<AppState>().testConnection(s);
      if (!mounted) return false;
      setState(() {
        _result = msg;
        _resultOk = true;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _result = '$e';
        _resultOk = false;
      });
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = _build();
    final ok = await _test(s);
    if (!ok) {
      final force = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connexion échouée'),
          content: Text('${_result ?? ''}\n\nEnregistrer quand même ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Corriger')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      );
      if (force != true) return;
    }
    if (!mounted) return;
    final app = context.read<AppState>();
    final first = app.subs.isEmpty;
    await app.upsert(s);
    if (!mounted) return;
    if (first && widget.existing == null) {
      Navigator.of(context).pushReplacementNamed(Routes.home);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? 'Ajouter un abonnement' : 'Modifier l\'abonnement')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedButton<SubType>(
            segments: const [
              ButtonSegment(value: SubType.m3u, label: Text('Lien M3U'), icon: Icon(Icons.link)),
              ButtonSegment(value: SubType.xtream, label: Text('Xtream Codes'), icon: Icon(Icons.dns)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _result = null;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom (facultatif)')),
          const SizedBox(height: 12),
          if (_type == SubType.m3u)
            TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Lien M3U',
                hintText: 'http://…',
                suffixIcon: TextButton(onPressed: () => _paste(_url), child: const Text('Coller')),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                return ((t.startsWith('http://') || t.startsWith('https://')) && t.length > 10)
                    ? null
                    : 'Entrez un lien valide (http:// ou https://)';
              },
            )
          else ...[
            TextFormField(
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Serveur',
                hintText: 'http://exemple.com:8080',
                suffixIcon: TextButton(onPressed: () => _paste(_server), child: const Text('Coller')),
              ),
              validator: _req,
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'Identifiant'),
                validator: _req),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                suffixIcon: IconButton(
                    icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPass = !_showPass)),
              ),
              validator: _req,
            ),
          ],
          const SizedBox(height: 16),
          if (_result != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_resultOk ? Colors.green : Colors.redAccent).withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_result!),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    if (_form.currentState!.validate()) _test(_build());
                  },
            icon: const Icon(Icons.network_check),
            label: const Text('Tester la connexion'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Player Flow ne fournit aucun contenu ni abonnement. Ajoutez uniquement vos propres sources légales.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
