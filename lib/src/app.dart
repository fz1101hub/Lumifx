import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'app_scope.dart';
import 'core/audio/audio_input.dart';
import 'core/hue/hue_discovery.dart';
import 'features/bridge/bridge_controller.dart';
import 'features/home/home_screen.dart';
import 'features/library/preferences_controller.dart';
import 'features/shortcuts/app_shortcuts.dart';
import 'features/shortcuts/shortcuts_bridge.dart';

class LumiFxApp extends StatefulWidget {
  const LumiFxApp({
    required this.bridge,
    required this.discovery,
    required this.preferences,
    required this.audioInput,
    this.shortcuts = const NoShortcuts(),
    this.locale,
    super.key,
  });

  final BridgeController bridge;
  final BridgeDiscovery discovery;
  final PreferencesController preferences;
  final AudioInput audioInput;

  /// Home-screen shortcuts to the favourite effects.
  final AppShortcuts shortcuts;

  /// Forces a language; null follows the device (tests pass one).
  final Locale? locale;

  @override
  State<LumiFxApp> createState() => _LumiFxAppState();
}

class _LumiFxAppState extends State<LumiFxApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      bridge: widget.bridge,
      discovery: widget.discovery,
      preferences: widget.preferences,
      audioInput: widget.audioInput,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: widget.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7CFF6B),
          useMaterial3: true,
        ),
        builder: (context, child) => ShortcutsBridge(
          shortcuts: widget.shortcuts,
          preferences: widget.preferences,
          navigatorKey: _navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
