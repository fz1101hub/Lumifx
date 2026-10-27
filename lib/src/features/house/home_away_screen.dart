import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'home_away.dart';

/// Leaving and coming home: home set where the phone is, the last one out
/// switches every light off, the hall lights up on coming home after dark.
class HomeAwayScreen extends StatefulWidget {
  const HomeAwayScreen({this.random, super.key});

  /// Makes the presence sensor's id (tests).
  final math.Random? random;

  @override
  State<HomeAwayScreen> createState() => _HomeAwayScreenState();
}

class _HomeAwayScreenState extends State<HomeAwayScreen> {
  var _busy = false;

  Future<void> _setHere() async {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final client = scope.bridge.client;
    if (client == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await scope.homeAway.requestAccess()) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.homeAwayDenied)));
        return;
      }
      final here = await scope.homeAway.currentLocation();
      if (here == null) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.homeAwayNoLocation)));
        return;
      }
      final random = widget.random ?? math.Random.secure();
      final unique =
          List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join();
      final sensor =
          await client.createPresenceSensor('LumiFX phone', 'lumifx-$unique');
      await scope.preferences.setHomeAway(HomeAwaySettings(
        latitude: here.latitude,
        longitude: here.longitude,
        sensorId: sensor,
      ));
      messenger.showSnackBar(SnackBar(content: Text(l10n.homeAwayIsSet)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.couldNotSaveRoutine(describeError(l10n, error)))));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stop(HomeAwaySettings settings) async {
    final scope = AppScope.of(context);
    await scope.bridge.client?.deletePresenceSensor(settings.sensorId);
    await scope.preferences.setHomeAway(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeAway)),
      body: scope.bridge.client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : ListenableBuilder(
              listenable: preferences,
              builder: (context, _) {
                final settings = preferences.homeAway;
                final rooms = [
                  for (final room
                      in scope.bridge.home?.rooms ?? const <HueGroup>[])
                    if (room.idV1 != null) room,
                ];
                return ListView(
                  padding: context.pageInsets(),
                  children: [
                    Text(l10n.homeAwayDescription,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    if (settings == null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56)),
                        onPressed: _busy || !scope.homeAway.isSupported
                            ? null
                            : _setHere,
                        icon: const Icon(Icons.home_outlined),
                        label: Text(l10n.homeAwaySetHere),
                      )
                    else ...[
                      Row(
                        children: [
                          const Icon(Icons.home, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(l10n.homeAwayIsSet,
                                  style: theme.textTheme.titleMedium)),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.homeAwayOffOnLeave),
                        value: settings.offOnLeave,
                        onChanged: (on) => preferences
                            .setHomeAway(settings.copyWith(offOnLeave: on)),
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.homeAwayHall,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.homeAwayHallNone),
                            selected: settings.hallGroupId == null,
                            onSelected: (_) => preferences.setHomeAway(
                                settings.copyWith(hallGroupId: () => null)),
                          ),
                          for (final room in rooms)
                            ChoiceChip(
                              label: Text(room.name),
                              selected: settings.hallGroupId == room.idV1,
                              onSelected: (_) => preferences.setHomeAway(
                                  settings.copyWith(
                                      hallGroupId: () => room.idV1)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.homeAwayRadius,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final radius in HomeAwaySettings.radiusChoices)
                            ChoiceChip(
                              label: Text(l10n.homeAwayMeters(radius)),
                              selected: settings.radius == radius,
                              onSelected: (_) => preferences.setHomeAway(
                                  settings.copyWith(radius: radius)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _stop(settings),
                          icon: const Icon(Icons.location_off_outlined),
                          label: Text(l10n.homeAwayStop),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
