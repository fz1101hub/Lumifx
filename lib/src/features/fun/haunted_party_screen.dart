import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_buttons.dart';
import '../../core/hue/hue_house.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import 'haunted_party.dart';

/// A Halloween party: the room glows spooky, and when someone walks past
/// the Hue motion sensor (or a grown-up taps Scare now) the lamps flash
/// and the phone thunders. LumiFX stays open meanwhile.
class HauntedPartyScreen extends StatefulWidget {
  const HauntedPartyScreen({this.motion, this.sensors, super.key});

  /// Motion events instead of the bridge's (tests).
  final Stream<HueMotionEvent> Function()? motion;

  /// Motion sensors instead of the bridge's (tests).
  final List<HueMotionSensor>? sensors;

  @override
  State<HauntedPartyScreen> createState() => _HauntedPartyScreenState();
}

class _HauntedPartyScreenState extends State<HauntedPartyScreen> {
  final _random = math.Random();
  List<HueMotionSensor>? _sensors;
  String? _sensor;
  var _armed = false;
  var _scares = 0;
  DateTime? _lastScare;
  StreamSubscription<HueMotionEvent>? _motion;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSensors();
      // The scare's thunder made ahead, so it strikes with the flash.
      unawaited(AppScope.of(context).playback.prepareSounds(thunder: true));
    });
  }

  @override
  void dispose() {
    unawaited(_motion?.cancel());
    _retry?.cancel();
    super.dispose();
  }

  Future<void> _loadSensors() async {
    final given = widget.sensors;
    final client = AppScope.of(context).bridge.client;
    final sensors = given ??
        (client == null
            ? const <HueMotionSensor>[]
            : await client
                .fetchMotionSensors()
                .catchError((Object _) => <HueMotionSensor>[]));
    if (mounted) {
      setState(() {
        _sensors = sensors;
        _sensor ??= sensors.firstOrNull?.id;
      });
    }
  }

  Future<void> _arm() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    setState(() => _armed = true);
    await playback.switchEffect(HauntedParty.room(l10n.haunted));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
    _listen();
  }

  /// Watches the sensor; a lost connection is tried again shortly.
  void _listen() {
    unawaited(_motion?.cancel());
    _motion = null;
    if (!mounted || !_armed || _sensor == null) {
      return;
    }
    final client = AppScope.of(context).bridge.client;
    final events = widget.motion?.call() ?? client?.motionEvents();
    if (events == null) {
      return;
    }
    void again() {
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 5), _listen);
    }

    _motion = events.listen(
      (event) {
        if (event.motion && event.sensorId == _sensor) {
          unawaited(_scare());
        }
      },
      onError: (Object _) => again(),
      onDone: again,
    );
  }

  Future<void> _disarm() async {
    final playback = AppScope.of(context).playback;
    unawaited(_motion?.cancel());
    _motion = null;
    _retry?.cancel();
    setState(() => _armed = false);
    await playback.stop();
  }

  Future<void> _scare({bool now = false}) async {
    final last = _lastScare;
    if (!now &&
        last != null &&
        DateTime.now().difference(last) < HauntedParty.rest) {
      return;
    }
    final playback = AppScope.of(context).playback;
    _lastScare = DateTime.now();
    setState(() => _scares++);
    unawaited(HapticFeedback.heavyImpact());
    unawaited(playback.thunder());
    playback.flash(const LightColor(1, 1, 1),
        length: const Duration(milliseconds: 400));
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }
    playback.flash(LightColor.fromHex('#7CFF6B'),
        length: const Duration(milliseconds: 1600));
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (!mounted) {
      return;
    }
    // Red eyes in a corner.
    playback.flash(LightColor.fromHex('#FF2D1A'),
        length: const Duration(milliseconds: 1200), at: _random.nextDouble());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sensors = _sensors;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.haunted)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.hauntedDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (sensors == null)
            const Center(child: CircularProgressIndicator())
          else if (sensors.isEmpty)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.sensors_off_outlined),
                title: Text(l10n.hauntedNoSensor),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _sensor,
              decoration: InputDecoration(
                labelText: l10n.hauntedSensor,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final sensor in sensors)
                  DropdownMenuItem(value: sensor.id, child: Text(sensor.name)),
              ],
              onChanged: (id) {
                setState(() => _sensor = id);
                _listen();
              },
            ),
          const SizedBox(height: 24),
          if (_armed) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                sensors?.isNotEmpty == true
                    ? l10n.hauntedArmed
                    : l10n.hauntedScares(_scares),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (sensors?.isNotEmpty == true)
              Text(
                l10n.hauntedScares(_scares),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                backgroundColor: const Color(0xFF3A1D5C),
                foregroundColor: Colors.white,
                textStyle: theme.textTheme.titleLarge,
              ),
              onPressed: () => _scare(now: true),
              icon: const Icon(Icons.flash_on, size: 32),
              label: Text(l10n.hauntedScare),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _disarm,
              icon: const Icon(Icons.stop),
              label: Text(l10n.stop),
            ),
          ] else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: sensors == null ? null : _arm,
              icon: const Icon(Icons.celebration_outlined),
              label: Text(l10n.hauntedArm),
            ),
        ],
      ),
    );
  }
}
