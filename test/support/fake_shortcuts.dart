import 'package:lumifx/src/features/shortcuts/app_shortcuts.dart';

/// Records the published shortcuts and lets a test tap one.
class FakeShortcuts implements AppShortcuts {
  List<ShortcutSpec> items = const [];
  void Function(String id)? _onLaunch;

  @override
  Future<void> initialize(void Function(String id) onLaunch) async =>
      _onLaunch = onLaunch;

  @override
  Future<void> setShortcuts(List<ShortcutSpec> shortcuts) async =>
      items = shortcuts;

  void launch(String id) => _onLaunch!(id);
}
