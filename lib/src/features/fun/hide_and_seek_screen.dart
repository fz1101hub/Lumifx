import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/light_color_ui.dart';
import '../effects/playback_controller.dart';
import '../effects/read_aloud.dart';
import 'hide_and_seek.dart';

/// Hide and seek: the voice counts aloud, second by second, while the
/// lamps dim; then "Ready or not, here I come!" and the search.
class HideAndSeekScreen extends StatefulWidget {
  const HideAndSeekScreen({super.key});

  @override
  State<HideAndSeekScreen> createState() => _HideAndSeekScreenState();
}

class _HideAndSeekScreenState extends State<HideAndSeekScreen> {
  var _count = 20;

  /// The last number said (the count + 1 once "here I come" is said).
  int? _said;

  Future<void> _start() async {
    final playback = AppScope.of(context).playback;
    _said = null;
    playback.setSleepTimer(null);
    await playback
        .switchEffect(HideAndSeek.effect(context.l10n.hideSeek, _count));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    } else if (playback.status == PlaybackStatus.paused) {
      await playback.resume();
    }
  }

  Future<void> _found() async {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    _say(l10n.hideSeekWellDone);
    await playback.switchEffect(HideAndSeek.found(l10n.hideSeek));
    if (playback.status == PlaybackStatus.idle) {
      await playback.start();
    }
  }

  void _say(String text) {
    final scope = AppScope.of(context);
    if (!scope.preferences.soundOn) {
      return;
    }
    final language =
        speechLanguage(Localizations.localeOf(context).languageCode);
    unawaited(() async {
      await scope.speaker.stop();
      await scope.speaker.speak(text, language);
    }());
  }

  /// Says each number as its second starts (a moment early, as the voice
  /// takes that long to begin), then "here I come" with the flash.
  void _countAloud(int count, Duration position) {
    final ahead = position + ReadAloud.speechLead;
    final number = ahead.inSeconds + 1;
    final next = number > count ? count + 1 : number;
    if (_said == next) {
      return;
    }
    _said = next;
    final l10n = context.l10n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _say(next > count ? l10n.hideSeekReady : '$next');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playback = AppScope.of(context).playback;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hideSeek)),
      body: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final count = HideAndSeek.countOf(playback.effect);
          final player = playback.player;
          if (count != null &&
              player != null &&
              playback.status != PlaybackStatus.idle) {
            return StreamBuilder<List<LightFrame>>(
              stream: player.frames,
              builder: (context, _) {
                _countAloud(count, player.position);
                return _running(context, count);
              },
            );
          }
          return _setup(context);
        },
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: context.pageInsets(),
      children: [
        Text(l10n.hideSeekDescription, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Text(l10n.hideSeekCount, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final seconds in HideAndSeek.countChoices)
              ChoiceChip(
                label: Text('$seconds'),
                selected: _count == seconds,
                onSelected: (_) => setState(() => _count = seconds),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: _start,
          icon: const Icon(Icons.visibility_off_outlined),
          label: Text(l10n.hideSeekStart),
        ),
      ],
    );
  }

  Widget _running(BuildContext context, int count) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final playback = AppScope.of(context).playback;
    final player = playback.player!;
    final seconds = player.position.inSeconds;
    final counting = seconds < count;
    final frame = player.currentFrames.firstOrNull;
    return ListView(
      padding: context.pageInsets(),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: frame?.toDisplayColor() ?? Colors.black,
              border: Border.all(color: theme.colorScheme.outline),
            ),
            alignment: Alignment.center,
            child: counting
                ? Text('${seconds + 1}',
                    style: theme.textTheme.displayLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700))
                : const Icon(Icons.search, size: 88, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            counting ? l10n.hideSeekCounting : l10n.hideSeekReady,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (!counting) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _found,
            icon: const Icon(Icons.celebration_outlined),
            label: Text(l10n.hideSeekFoundAll),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: playback.stop,
            icon: const Icon(Icons.stop),
            label: Text(l10n.stop),
          ),
        ),
      ],
    );
  }
}
