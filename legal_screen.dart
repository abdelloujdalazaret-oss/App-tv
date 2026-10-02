import 'package:flutter/material.dart';
import '../../app/constants.dart';

enum LegalKind { privacy, terms, about }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final LegalKind kind;

  static const _privacy = '''
Player Flow ne collecte aucune donnée personnelle sur ses propres serveurs.

• Vos abonnements (liens M3U, identifiants Xtream) sont enregistrés uniquement sur votre appareil, dans un stockage chiffré.
• Vos favoris et votre historique récent restent sur votre appareil.
• Lorsque vous lisez une source, l'application se connecte directement au serveur que VOUS avez renseigné. Ce serveur peut enregistrer votre adresse IP selon sa propre politique.
• Si vous activez un DNS sécurisé (DoH), les noms de domaine sont résolus auprès du fournisseur que vous choisissez (Cloudflare, Google, Quad9 ou personnalisé).
• Aucune publicité, aucun traceur.

Vous pouvez supprimer vos données à tout moment en supprimant vos abonnements ou en désinstallant l'application.''';

  static const _terms = '''
1. Player Flow est un lecteur multimédia. L'application ne fournit, n'héberge et ne vend AUCUN contenu, chaîne ou abonnement.

2. Vous ajoutez vos propres sources (liens M3U, comptes Xtream). Vous êtes seul responsable de la légalité de ces sources et de votre droit d'y accéder.

3. Il est interdit d'utiliser l'application pour accéder à des contenus dont vous ne détenez pas les droits.

4. L'application est fournie « en l'état », sans garantie de disponibilité ou de compatibilité avec tous les serveurs.

5. L'éditeur décline toute responsabilité quant aux contenus lus via l'application.''';

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (kind) {
      LegalKind.privacy => ('Politique de confidentialité', _privacy),
      LegalKind.terms => ('Conditions d\'utilisation', _terms),
      LegalKind.about => (
          'À propos',
          '${AppConst.appName} — version ${AppConst.version}\n\nLecteur IPTV pour Android.\n\nL\'application ne fournit aucun contenu ni abonnement : l\'utilisateur ajoute ses propres sources légales.'
        ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(body, style: const TextStyle(height: 1.5)),
      ),
    );
  }
}
