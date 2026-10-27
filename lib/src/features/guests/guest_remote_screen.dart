import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../learn/colour_words.dart';
import 'guest_remote.dart';

/// The remote for guests: a QR code for a page on the home Wi-Fi where
/// they pick a colour or a calm effect; it works while this is open.
class GuestRemoteScreen extends StatefulWidget {
  const GuestRemoteScreen({this.address, super.key});

  /// Where to serve instead of the phone's Wi-Fi address (tests).
  final InternetAddress? address;

  /// How many calm effects the guests see.
  static const maxEffects = 12;

  @override
  State<GuestRemoteScreen> createState() => _GuestRemoteScreenState();
}

class _GuestRemoteScreenState extends State<GuestRemoteScreen> {
  GuestRemote? _remote;
  Uri? _link;
  var _noWifi = false;
  var _started = false;
  final _picked = <String>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_start());
    }
  }

  @override
  void dispose() {
    unawaited(_remote?.stop());
    super.dispose();
  }

  List<LightingEffect> get _effects => [
        for (final effect
            in AppScope.of(context).library.ofKind(EffectKind.scene))
          if (!effect.hasRapidFlashes) effect,
      ].take(GuestRemoteScreen.maxEffects).toList();

  Future<void> _start() async {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final remote = GuestRemote(
      effects: [
        for (final effect in _effects)
          (id: effect.id, name: l10n.effectName(effect)),
      ],
      colors: [
        for (final colour in LearnColour.values)
          (hex: colour.hex, name: _capitalised(colour.word(language))),
      ],
      text: GuestPageText(
        title: l10n.guestPageTitle,
        colours: l10n.guestPageColours,
        effects: l10n.guestPageEffects,
        stop: l10n.stop,
        done: l10n.guestPageDone,
        wrongCode: l10n.guestPageWrongCode,
        language: language,
      ),
      onPick: (pick) => unawaited(_play(pick)),
    );
    final address = widget.address ?? await GuestRemote.lanAddress();
    if (!mounted) {
      return;
    }
    if (address == null) {
      setState(() => _noWifi = true);
      return;
    }
    try {
      final link = await remote.start(address);
      if (!mounted) {
        await remote.stop();
        return;
      }
      setState(() {
        _remote = remote;
        _link = link;
      });
    } on Object catch (error) {
      debugPrint('Guest remote: $error');
      if (mounted) {
        setState(() => _noWifi = true);
      }
    }
  }

  static String _capitalised(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  Future<void> _play(GuestPick pick) async {
    if (!mounted) {
      return;
    }
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final playback = scope.playback;
    final language = Localizations.localeOf(context).languageCode;
    if (pick.stop) {
      setState(() => _picked.insert(0, l10n.stop));
      await playback.stop();
      return;
    }
    final LightingEffect? effect;
    final String name;
    if (pick.color case final hex?) {
      final colour = LearnColour.values.firstWhere((c) => c.hex == hex);
      name = _capitalised(colour.word(language));
      effect = colour.effect(name);
    } else {
      effect = scope.library.byId(pick.effectId!);
      name = effect == null ? '' : l10n.effectName(effect);
    }
    if (effect == null) {
      return;
    }
    setState(() {
      _picked.insert(0, name);
      if (_picked.length > 5) {
        _picked.removeLast();
      }
    });
    await playback.switchEffect(effect);
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final link = _link;
    final remote = _remote;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.guestRemote)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.guestRemoteDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (_noWifi)
            Text(l10n.guestRemoteNoWifi,
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge)
          else if (link == null || remote == null)
            const LinearProgressIndicator()
          else ...[
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 220,
                  child: QrImageView(
                    data: link.toString(),
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.guestRemoteCode(remote.code),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            SelectableText('${link.host}:${link.port}',
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          for (final name in _picked)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.guestRemotePicked(name)),
            ),
        ],
      ),
    );
  }
}
