import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app/app_state.dart';
import 'app/constants.dart';
import 'app/routes.dart';
import 'app/theme.dart';
import 'services/network_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // initialise libmpv
  final settings = await NetworkSettings.load();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<NetworkSettings>.value(value: settings),
      ChangeNotifierProvider<AppState>(create: (_) => AppState(settings)),
    ],
    child: const PlayerFlowApp(),
  ));
}

class PlayerFlowApp extends StatelessWidget {
  const PlayerFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConst.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: Routes.intro,
      routes: Routes.table,
    );
  }
}
