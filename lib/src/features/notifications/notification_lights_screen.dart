import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/notification_lights_platform.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import 'notification_lights.dart';

/// Chosen apps flash the lights in their colour when they post a
/// notification (Android).
class NotificationLightsScreen extends StatefulWidget {
  const NotificationLightsScreen({super.key});

  @override
  State<NotificationLightsScreen> createState() =>
      _NotificationLightsScreenState();
}

class _NotificationLightsScreenState extends State<NotificationLightsScreen> {
  late final AppLifecycleListener _lifecycle;
  bool? _access;

  @override
  void initState() {
    super.initState();
    // Back from Android's settings: allowed, perhaps.
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) {
      return;
    }
    final access = await AppScope.of(context).notificationLights.hasAccess();
    if (mounted) {
      setState(() => _access = access);
    }
  }

  Future<void> _save(NotificationLightsSettings settings) =>
      AppScope.of(context).preferences.setNotificationLights(settings);

  Future<String?> _pickColor(String app, String current) => showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.notificationLightsColor(app)),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final hex in NotificationLightsSettings.colors)
                _ColorDot(
                  hex: hex,
                  size: 48,
                  selected: hex == current,
                  onTap: () => Navigator.of(context).pop(hex),
                ),
            ],
          ),
        ),
      );

  Future<void> _addApp() async {
    final platform = AppScope.of(context).notificationLights;
    final apps = await platform.apps();
    if (!mounted) {
      return;
    }
    final app = await showModalBottomSheet<InstalledApp>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AppPicker(apps: apps),
    );
    if (app == null || !mounted) {
      return;
    }
    final settings = AppScope.of(context).preferences.notificationLights;
    final used = {for (final r in settings.rules) r.color};
    final color = await _pickColor(
      app.label,
      NotificationLightsSettings.colors.firstWhere((c) => !used.contains(c),
          orElse: () => NotificationLightsSettings.colors.first),
    );
    if (color == null || !mounted) {
      return;
    }
    await _save(settings
        .withRule(NotificationRule(
            package: app.package, label: app.label, color: color))
        .copyWith(enabled: true));
  }

  Future<void> _pickTime(bool from) async {
    final settings = AppScope.of(context).preferences.notificationLights;
    final minutes = from ? settings.quietFrom : settings.quietTo;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (time == null || !mounted) {
      return;
    }
    final picked = time.hour * 60 + time.minute;
    await _save(from
        ? settings.copyWith(quietFrom: picked)
        : settings.copyWith(quietTo: picked));
  }

  Future<void> _test(NotificationRule rule) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await AppScope.of(context).notificationLights.test(xyOf(rule.color));
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.notificationLightsTestFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationLights)),
      body: ListenableBuilder(
        listenable: Listenable.merge([scope.preferences, scope.bridge]),
        builder: (context, _) {
          final settings = scope.preferences.notificationLights;
          final home = scope.bridge.home;
          final target =
              home == null ? null : notificationTarget(settings, home);
          String time(int minutes) => localizations.formatTimeOfDay(
              TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.notificationLightsDescription,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.notificationLightsPrivacy,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_access == false)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.notificationLightsAccess),
                    trailing: TextButton(
                      onPressed: scope.notificationLights.openAccessSettings,
                      child: Text(l10n.notificationLightsAllow),
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.notificationLightsOn),
                value: settings.enabled,
                onChanged: (on) => _save(settings.copyWith(enabled: on)),
              ),
              if (home != null && home.groups.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: target?.id,
                  decoration: InputDecoration(
                    labelText: l10n.notificationLightsRoom,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final group in home.groups)
                      DropdownMenuItem(
                          value: group.id, child: Text(group.name)),
                  ],
                  onChanged: (id) => _save(settings.copyWith(target: id)),
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.notificationLightsApps,
                  style: theme.textTheme.titleMedium),
              if (settings.rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.notificationLightsNoApps,
                      style: theme.textTheme.bodyMedium),
                ),
              for (final rule in settings.rules)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _ColorDot(
                    hex: rule.color,
                    size: 32,
                    selected: false,
                    onTap: null,
                  ),
                  title: Text(rule.label),
                  onTap: () async {
                    final color = await _pickColor(rule.label, rule.color);
                    if (color != null) {
                      await _save(settings.withRule(rule.withColor(color)));
                    }
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.notificationLightsTest,
                        icon: const Icon(Icons.flash_on_outlined),
                        onPressed: settings.enabled && _access == true
                            ? () => _test(rule)
                            : null,
                      ),
                      IconButton(
                        tooltip: l10n.notificationLightsRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _save(settings.withoutRule(rule.package)),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: settings.rules.length <
                          NotificationLightsSettings.maxRules
                      ? _addApp
                      : null,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.notificationLightsAddApp),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.bedtime_outlined),
                title: Text(l10n.notificationLightsQuiet),
                subtitle: Text(l10n.notificationLightsQuietSubtitle),
                value: settings.quiet,
                onChanged: (on) => _save(settings.copyWith(quiet: on)),
              ),
              if (settings.quiet)
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.notificationLightsFrom),
                        subtitle: Text(time(settings.quietFrom)),
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.notificationLightsTo),
                        subtitle: Text(time(settings.quietTo)),
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The phone's apps, to choose one, with a search.
class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.apps});

  final List<InstalledApp> apps;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _query.trim().toLowerCase();
    final apps = [
      for (final app in widget.apps)
        if (query.isEmpty || app.label.toLowerCase().contains(query)) app,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.notificationLightsSearch,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.apps),
                title: Text(apps[index].label),
                onTap: () => Navigator.of(context).pop(apps[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = NotificationLightsSettings.colorNames[hex]
        ?.word(Localizations.localeOf(context).languageCode);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: name ?? hex,
      excludeSemantics: true,
      child: _dot(theme),
    );
  }

  Widget _dot(ThemeData theme) {
    return Material(
      color: LightColor.fromHex(hex).toColor(),
      shape: CircleBorder(
        side: BorderSide(
          color: selected
              ? theme.colorScheme.onSurface
              : theme.colorScheme.outlineVariant,
          width: selected ? 4 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}
