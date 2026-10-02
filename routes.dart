import 'package:flutter/material.dart';
import '../features/account/add_subscription_screen.dart';
import '../features/account/settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/intro/intro_screen.dart';

class Routes {
  static const intro = '/';
  static const home = '/home';
  static const add = '/add';
  static const settings = '/settings';

  static final Map<String, WidgetBuilder> table = {
    intro: (_) => const IntroScreen(),
    home: (_) => const HomeScreen(),
    add: (_) => const AddSubscriptionScreen(),
    settings: (_) => const SettingsScreen(),
  };
}
