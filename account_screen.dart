import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/app_state.dart';
import '../../app/constants.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/subscription.dart';
import '../../services/network_settings.dart';
import 'add_subscription_screen.dart';
import 'legal_screen.dart';

/// Onglet « Compte » : abonnements, réseau, assistance, mentions légales.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _delete(BuildContext context, Subscription s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'abonnement ?'),
        content: Text('« ${s.name} » sera supprimé de cet appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && context.mounted) context.read<AppState>().remove(s.id);
  }

  void _support(BuildContext context) {
    final st = context.read<NetworkSettings>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.field,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (st.supportEmail.isEmpty && st.supportWhatsapp.isEmpty)
              const Text('Aucun contact configuré.\nRenseignez-les dans Paramètres > Assistance.',
                  textAlign: TextAlign.center),
            if (st.supportEmail.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(st.supportEmail),
                onTap: () => launchUrl(Uri.parse('mailto:${st.supportEmail}'),
                    mode: LaunchMode.externalApplication),
              ),
            if (st.supportWhatsapp.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: Text('WhatsApp ${st.supportWhatsapp}'),
                onTap: () => launchUrl(
                    Uri.parse('https://wa.me/${st.supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '')}'),
                    mode: LaunchMode.externalApplication),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Compte', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _title('Abonnements'),
        if (app.subs.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun abonnement enregistré.', style: TextStyle(color: Colors.white60))),
        for (final s in app.subs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: cardDecoration(selected: s.id == app.activeId),
            child: ListTile(
              onTap: () => app.select(s.id),
              leading: Icon(s.id == app.activeId ? Icons.check_circle : Icons.circle_outlined,
                  color: s.id == app.activeId ? AppColors.accent : Colors.white54),
              title: Text(s.name),
              subtitle: Text('${s.typeLabel} • ${s.host} • ${s.id == app.activeId ? 'Actif' : 'Inactif'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AddSubscriptionScreen(existing: s)));
                  } else {
                    _delete(context, s);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'del', child: Text('Supprimer')),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, Routes.add),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un abonnement'),
        ),
        const SizedBox(height: 24),
        _title('Application'),
        _tile(Icons.settings_ethernet, 'Paramètres', 'Réseau, DNS, proxy, assistance',
            () => Navigator.pushNamed(context, Routes.settings)),
        _tile(Icons.support_agent, 'Assistance', 'E-mail / WhatsApp', () => _support(context)),
        _tile(Icons.privacy_tip_outlined, 'Politique de confidentialité', null,
            () => _legal(context, LegalKind.privacy)),
        _tile(Icons.description_outlined, 'Conditions d\'utilisation', null,
            () => _legal(context, LegalKind.terms)),
        _tile(Icons.info_outline, 'À propos', null, () => _legal(context, LegalKind.about)),
        _tile(Icons.numbers, 'Version', AppConst.version, null),
      ]),
    );
  }

  void _legal(BuildContext c, LegalKind k) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => LegalScreen(kind: k)));

  Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t.toUpperCase(),
          style: const TextStyle(color: AppColors.accent, fontSize: 12, letterSpacing: 1)));

  Widget _tile(IconData i, String t, String? sub, VoidCallback? onTap) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: cardDecoration(),
        child: ListTile(
            leading: Icon(i), title: Text(t), subtitle: sub == null ? null : Text(sub), onTap: onTap),
      );
}
