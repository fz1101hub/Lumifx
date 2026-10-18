import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/audio/audio_input.dart';
import '../../core/effects/effect.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/playback_controller.dart';
import '../effects/read_along.dart';
import 'birthday.dart';
import 'blow_detector.dart';

enum _Stage { setup, candles, party }

/// A birthday party: who and how old, then the candles light up on the
/// lamps; blow them out with a tap, or on the phone's microphone, and the
/// room bursts into colour.
class BirthdayScreen extends StatefulWidget {
  const BirthdayScreen({this.playing, super.key});

  /// The party already on the lights, when opened from the mini-player.
  final LightingEffect? playing;

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  late PlaybackController _playback;
  late AudioInput _microphone;
  var _stage = _Stage.setup;
  Birthday? _birthday;
  LightingEffect? _candles;
  LightingEffect? _party;

  @override
  void initState() {
    super.initState();
    final playing = widget.playing;
    final birthday = playing == null ? null : Birthday.of(playing);
    if (playing != null && birthday != null) {
      _birthday = birthday;
      _name.text = birthday.name;
      _age.text = birthday.age == 0 ? '' : '${birthday.age}';
      if (Birthday.isCandles(playing)) {
        _candles = playing;
        _stage = _Stage.candles;
      } else {
        _party = playing;
        _stage = _Stage.party;
      }
    }
  }

  StreamSubscription<Uint8List>? _listening;
  var _starting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _playback = scope.playback;
    _microphone = scope.audioInput;
  }

  @override
  void dispose() {
    unawaited(_stopListening());
    // Unlit candles make no sense without this screen; the party may
    // finish on its own.
    final candles = _candles;
    if (_stage == _Stage.candles &&
        candles != null &&
        _playback.effect.id == candles.id) {
      unawaited(_playback.stop());
    }
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _play(LightingEffect effect) async {
    await _playback.switchEffect(effect);
    if (_playback.status == PlaybackStatus.idle) {
      await _playback.start();
    } else if (_playback.status == PlaybackStatus.paused) {
      await _playback.resume();
    }
  }

  Future<void> _light() async {
    if (_starting) {
      return;
    }
    final l10n = context.l10n;
    final birthday = Birthday(
      name: _name.text,
      age: int.tryParse(_age.text.trim()) ?? 0,
    );
    final candles = birthday.candlesEffect(l10n);
    setState(() {
      _starting = true;
      _birthday = birthday;
      _candles = candles;
    });
    FocusScope.of(context).unfocus();
    await _play(candles);
    if (mounted) {
      setState(() {
        _starting = false;
        _stage = _Stage.candles;
      });
    }
  }

  Future<void> _blow() async {
    final birthday = _birthday;
    if (birthday == null || _stage != _Stage.candles) {
      return;
    }
    final party = birthday.partyEffect(context.l10n);
    setState(() {
      _party = party;
      _stage = _Stage.party;
    });
    unawaited(HapticFeedback.mediumImpact());
    await _stopListening();
    await _play(party);
  }

  Future<void> _listen() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _microphone.requestPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.birthdayMicDenied)));
      return;
    }
    if (!mounted || _stage != _Stage.candles) {
      return;
    }
    try {
      final detector = BlowDetector(sampleRate: _microphone.sampleRate);
      final audio = await _microphone.start();
      if (!mounted || _stage != _Stage.candles) {
        await _microphone.stop();
        return;
      }
      setState(() {
        _listening = audio.listen((pcm) {
          if (detector.add(pcm)) {
            unawaited(_blow());
          }
        });
      });
    } on Object catch (error) {
      debugPrint('Birthday microphone: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.birthdayMicDenied)));
    }
  }

  Future<void> _stopListening() async {
    final listening = _listening;
    if (listening == null) {
      return;
    }
    _listening = null;
    // Not awaited: it may be called from the stream's own listener.
    unawaited(listening.cancel());
    await _microphone.stop();
    if (mounted) {
      setState(() {});
    }
  }

  bool _isPlaying(LightingEffect? effect) =>
      effect != null &&
      _playback.effect.id == effect.id &&
      _playback.player != null &&
      _playback.status != PlaybackStatus.idle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.birthday)),
      body: ListenableBuilder(
        listenable: _playback,
        builder: (context, _) {
          final birthday = _birthday;
          return switch (_stage) {
            _Stage.candles when birthday != null && _isPlaying(_candles) =>
              _candlesView(context, birthday, _candles!),
            _Stage.party when birthday != null =>
              _partyView(context, birthday, _party!),
            _ => _setupView(context),
          };
        },
      ),
    );
  }

  Widget _setupView(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.birthdayDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: Birthday.maxName,
          decoration: InputDecoration(
            labelText: l10n.name,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _age,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            labelText: l10n.birthdayAge,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _starting ? null : _light,
          icon: const Icon(Icons.cake_outlined),
          label: Text(l10n.birthdayLight),
        ),
      ],
    );
  }

  Widget _candlesView(
    BuildContext context,
    Birthday birthday,
    LightingEffect candles,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 12),
        Text(
          birthday.title(l10n),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        _Cake(candles: birthday.candles, lit: true),
        const SizedBox(height: 24),
        ReadAlongCaption(
          effect: candles,
          lines: birthday.narration(candles, l10n),
          player: _playback.player,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: theme.textTheme.titleLarge,
          ),
          onPressed: _blow,
          icon: const Icon(Icons.air),
          label: Text(l10n.birthdayBlow),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _listening == null ? _listen : _stopListening,
          icon: Icon(_listening == null ? Icons.mic_none : Icons.mic),
          label: Text(
            _listening == null
                ? l10n.birthdayBlowOnPhone
                : l10n.birthdayListening,
          ),
        ),
      ],
    );
  }

  Widget _partyView(
    BuildContext context,
    Birthday birthday,
    LightingEffect party,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playing = _isPlaying(party);
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 12),
        Text(
          birthday.title(l10n),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        if (playing) ...[
          _Cake(candles: birthday.candles, lit: false),
          const SizedBox(height: 24),
          ReadAlongCaption(
            effect: party,
            lines: birthday.narration(party, l10n),
            player: _playback.player,
          ),
        ] else ...[
          Icon(Icons.celebration_outlined,
              size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            birthday.age == 0
                ? l10n.birthdayWonderfulDay
                : l10n.birthdayYearsOld(birthday.age),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ],
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _light,
              icon: const Icon(Icons.replay),
              label: Text(l10n.birthdayAgain),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        ),
      ],
    );
  }
}

/// A cake with its candles, lit or blown out.
class _Cake extends StatelessWidget {
  const _Cake({required this.candles, required this.lit});

  final int candles;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              for (var i = 0; i < candles; i++)
                Icon(
                  lit ? Icons.local_fire_department : Icons.air,
                  size: 28,
                  color: lit
                      ? const Color(0xFFFFB347)
                      : theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          Icon(Icons.cake, size: 120, color: theme.colorScheme.primary),
        ],
      ),
    );
  }
}
