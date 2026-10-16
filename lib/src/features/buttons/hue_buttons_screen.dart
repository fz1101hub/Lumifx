import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/hue/hue_buttons.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../library/preferences_controller.dart';

/// Every Hue switch and smart button on the bridge, each button with what
/// LumiFX does when it is pressed.
class HueButtonsScreen extends StatefulWidget {
  const HueButtonsScreen({super.key});

  @override
  State<HueButtonsScreen> createState() => _HueButtonsScreenState();
}

class _HueButtonsScreenState extends State<HueButtonsScreen> {
  List<HueButtonDevice>? _devices;
  Object? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final client = AppScope.of(context).bridge.client;
    if (client == null) {
      return;
    }
    try {
      final devices = await client.fetchButtonDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final devices = _devices;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hueButtons)),
      body: scope.bridge.client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : ListenableBuilder(
              listenable: scope.preferences,
              builder: (context, _) => RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: context.pageInsets(),
                  children: [
                    Text(l10n.hueButtonsDescription,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Text(
                        l10n.couldNotLoadButtons(describeError(l10n, _error!)),
                        style: TextStyle(color: theme.colorScheme.error),
                      )
                    else if (devices == null)
                      const Center(child: CircularProgressIndicator())
                    else if (devices.isEmpty)
                      Text(l10n.noHueButtons),
                    for (final device in devices ?? const <HueButtonDevice>[])
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(device.name,
                                  style: theme.textTheme.titleMedium),
                              for (final button in device.buttons)
                                _ButtonRow(
                                  key: ValueKey(button.id),
                                  button: button,
                                  single: device.buttons.length == 1,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.button,
    required this.single,
    super.key,
  });

  final HueButton button;

  /// A smart button: no number to show.
  final bool single;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    final library = scope.library;
    final effects = [
      for (final kind in EffectKind.values) ...library.ofKind(kind),
    ];
    final current = preferences.buttonActions[button.id];
    // An action whose effect was deleted shows as nothing.
    final known = current == null ||
        current == PreferencesController.buttonStop ||
        current == PreferencesController.buttonBedtime ||
        effects.any((e) => e.id == current);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('${button.id}-$current'),
        initialValue: known ? current : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText:
              single ? l10n.hueButtons : l10n.hueButtonNumber(button.number),
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text(l10n.buttonActionNone)),
          DropdownMenuItem(
            value: PreferencesController.buttonStop,
            child: Text(l10n.buttonActionStop),
          ),
          DropdownMenuItem(
            value: PreferencesController.buttonBedtime,
            child: Text(l10n.bedtime),
          ),
          for (final effect in effects)
            DropdownMenuItem(
              value: effect.id,
              child: Text(
                l10n.effectName(effect),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (action) => preferences.setButtonAction(button.id, action),
      ),
    );
  }
}
