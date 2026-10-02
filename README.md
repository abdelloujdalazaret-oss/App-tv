# Player Flow — lecteur IPTV (Flutter / Android)

Application 100 % française. **Aucun contenu ni abonnement fourni** : l'utilisateur ajoute ses propres sources légales (lien M3U ou Xtream Codes).

## Installation (une seule fois)
1. Installer Flutter 3.x (https://docs.flutter.dev/get-started/install) et Android Studio (SDK Android).
2. `flutter doctor` doit être au vert (licences : `flutter doctor --android-licenses`).

## Générer le projet et l'APK
```bash
cd player_flow
./setup.sh                      # crée android/, copie le manifest, icône ronde, splash
flutter build apk --release     # APK : build/app/outputs/flutter-apk/app-release.apk
# APK plus léger par architecture :
flutter build apk --release --split-per-abi
```
Sous Windows (sans bash) : exécuter à la main les commandes de `setup.sh`
(`flutter create --platforms=android --org com.playerflow --project-name player_flow .`,
copier le contenu de `android_overlay/app/` dans `android/app/`, mettre `minSdk = 21`,
puis `flutter pub get`, `dart run flutter_launcher_icons`, `dart run flutter_native_splash:create`).

## Tests
`flutter test` (parseur M3U).

## Utilisation
- Premier lancement : intro (logo + son), puis « Ajouter un abonnement » (M3U ou Xtream, bouton *Coller*, *Tester la connexion*).
- L'abonnement est conservé (stockage chiffré) : l'app s'ouvre ensuite directement sur la dernière liste.
- Onglet **Compte** : changer d'abonnement actif, modifier/supprimer, paramètres, assistance, mentions légales.
- **Paramètres > Réseau** (tout désactivé par défaut) : DNS sécurisé (DoH), proxy, User-Agent, en-têtes, http↔https, délais, bouton *Diagnostiquer*.

## Structure
`lib/app` (thème, routes, état) · `lib/core` (réseau/DoH, stockage, utilitaires) · `lib/models` · `lib/services` (M3U, Xtream, abonnements, réglages) · `lib/features` (intro, home, channels, player, account).

## Dépannage
- **Image dans un petit rectangle / bandes noires** : le lecteur utilise `Positioned.fill(Video(fit: cover))` dans un `Stack`. Le bouton « Ajuster / Remplir » alterne `contain` / `cover`. Si le flux lui-même contient des bandes noires, « Remplir » les rogne.
- **« Votre opérateur peut bloquer ce serveur »** : activer le DNS sécurisé, essayer un proxy ou un VPN, puis *Diagnostiquer*.
- **Chaîne qui ne démarre pas** : essayer un autre User-Agent (ex. `VLC/3.0.18 LibVLC/3.0.18`) ; le lecteur retente 3 fois (2 s, 4 s, 8 s) puis propose « Réessayer ».
- **Erreur de build `minSdk`** : vérifier `minSdk = 21` dans `android/app/build.gradle(.kts)`.
- **Erreur R8 en release** : vérifier que `proguard-rules.pro` est bien référencé ; en dernier recours désactiver `minifyEnabled`.
- **Proxy SOCKS** : appliqué au flux vidéo (mpv) uniquement ; les requêtes playlist/API utilisent un proxy HTTP.
- **Picture-in-picture** : activé côté Android (`supportsPictureInPicture`) ; une bascule dédiée peut être ajoutée avec le paquet `floating`.
