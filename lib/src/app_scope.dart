import 'package:flutter/widgets.dart';

import 'core/hue/hue_discovery.dart';
import 'features/bridge/bridge_controller.dart';

/// App-wide services, provided at the root of the widget tree.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.bridge,
    required this.discovery,
    required super.child,
    super.key,
  });

  final BridgeController bridge;
  final BridgeDiscovery discovery;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      bridge != oldWidget.bridge || discovery != oldWidget.discovery;
}
