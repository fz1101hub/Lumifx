import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/color/light_color.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/light_frame.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import 'colour_words.dart';
import 'morse.dart';

/// Secret messages: a word typed here is flashed by the lamps in Morse
/// code, the letter being sent lit up on screen.
class MorseScreen extends StatefulWidget {
  const MorseScreen({this.playing, super.key});

  /// The message already on the lights, when opened from the mini-player.
  final LightingEffect? playing;

  @override
  State<MorseScreen> createState() => _MorseScreenState();
}

class _MorseScreenState extends State<MorseScreen> {
  late final (MorseMessage, String)? _playing =
      widget.playing == null ? null : MorseMessage.of(widget.playing!);
  late final _text = TextEditingController(text: _playing?.$1.text ?? 'SOS');
  late String _color = _playing?.$2 ?? _colors.first.hex;
  late MorseMessage? _message = _playing?.$1;
  late LightingEffect? _effect = widget.playing;

  static const _colors = [
    LearnColour.white, LearnColour.red, LearnColour.green, //
    LearnColour.blue, LearnColour.yellow, LearnColour.purple,
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = MorseMessage(_text.text);
    if (message.isEmpty) {
      return;
    }
    final playback = AppScope.of(context).playback;
    final effect = message.effect(context.l10n.morse, _color);
    setState(() {
      _message = message;
      _effect = effect;
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
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.morse)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final effect = _effect;
          final message = _message;
          final player = playback.player;
          final sending = effect != null &&
              message != null &&
              player != null &&
              playback.effect.id == effect.id &&
              playback.status != PlaybackStatus.idle;
          return ListView(
            padding: context.pageInsets(),
            children: [
              Text(l10n.morseDescription, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                maxLength: MorseMessage.maxLength,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.morseMessage,
                  helperText: l10n.morseOnlyLetters,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final colour in _colors)
                    ChoiceChip(
                      avatar: CircleAvatar(
                          backgroundColor:
                              LightColor.fromHex(colour.hex).toColor()),
                      label: Text(colour
                          .word(Localizations.localeOf(context).languageCode)),
                      showCheckmark: false,
                      selected: _color == colour.hex,
                      onSelected: (_) => setState(() => _color = colour.hex),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed:
                    MorseMessage(_text.text).isEmpty || sending ? null : _send,
                icon: const Icon(Icons.flare),
                label: Text(l10n.morseSend),
              ),
              const SizedBox(height: 24),
              if (sending)
                StreamBuilder<List<LightFrame>>(
                  stream: player.frames,
                  builder: (context, _) =>
                      _Sending(message: message, player: player.position),
                )
              else if (message != null)
                _Sending(message: message, player: null),
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.morseAlphabet),
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final MapEntry(key: char, value: code)
                          in morseCode.entries)
                        SizedBox(
                          width: 88,
                          child: Text(
                            '${char.toUpperCase()}  $code',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ]),
                          ),
                        ),
                    ],
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

/// The message as letters, the one being sent highlighted with its code.
class _Sending extends StatelessWidget {
  const _Sending({required this.message, required this.player});

  final MorseMessage message;

  /// How far the message is; null when it is not being sent.
  final Duration? player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = player;
    final current = position == null ? null : message.letterAt(position);
    final letter = current == null ? null : message.letters[current];
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            for (final (i, char) in message.letters.indexed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: i == current
                      ? theme.colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(char, style: theme.textTheme.displaySmall),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            letter == null || letter == ' '
                ? message.code
                : '$letter  ${morseCode[letter.toLowerCase()]}',
            textAlign: TextAlign.center,
            style: letter == null
                ? theme.textTheme.titleMedium
                : theme.textTheme.displaySmall,
          ),
        ),
      ],
    );
  }
}
