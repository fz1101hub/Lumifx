import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'core/hue/hue_discovery.dart';
import 'features/bridge/bridge_controller.dart';
import 'features/home/home_screen.dart';
import 'features/library/preferences_controller.dart';

class LumiFxApp extends StatelessWidget {
  const LumiFxApp({
    required this.bridge,
    required this.discovery,
    required this.preferences,
    super.key,
  });

  final BridgeController bridge;
  final BridgeDiscovery discovery;
  final PreferencesController preferences;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      bridge: bridge,
      discovery: discovery,
      preferences: preferences,
      child: MaterialApp(
        title: 'LumiFX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7CFF6B),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
