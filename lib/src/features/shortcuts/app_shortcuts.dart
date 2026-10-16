import 'package:quick_actions/quick_actions.dart';

/// A home-screen shortcut: an Android app shortcut (long-press the icon)
/// or an iOS quick action.
class ShortcutSpec {
  const ShortcutSpec({required this.id, required this.title});

  final String id;
  final String title;
}

/// The platform's home-screen shortcuts, behind an interface so tests can
/// fake them.
abstract interface class AppShortcuts {
  /// Starts listening. [onLaunch] gets the id of the shortcut that was
  /// tapped, including the one the app was launched with.
  Future<void> initialize(void Function(String id) onLaunch);

  /// Replaces the shortcuts shown on the home screen.
  Future<void> setShortcuts(List<ShortcutSpec> shortcuts);
}

/// Shortcuts through the `quick_actions` plugin. Platforms without
/// shortcuts (and tests without a platform) are silently ignored.
class QuickActionsShortcuts implements AppShortcuts {
  const QuickActionsShortcuts();

  static const _quickActions = QuickActions();

  @override
  Future<void> initialize(void Function(String id) onLaunch) async {
    try {
      await _quickActions.initialize(onLaunch);
    } on Object {
      // No shortcut support here.
    }
  }

  @override
  Future<void> setShortcuts(List<ShortcutSpec> shortcuts) async {
    try {
      await _quickActions.setShortcutItems([
        for (final shortcut in shortcuts)
          ShortcutItem(type: shortcut.id, localizedTitle: shortcut.title),
      ]);
    } on Object {
      // No shortcut support here.
    }
  }
}

class NoShortcuts implements AppShortcuts {
  const NoShortcuts();

  @override
  Future<void> initialize(void Function(String id) onLaunch) async {}

  @override
  Future<void> setShortcuts(List<ShortcutSpec> shortcuts) async {}
}
