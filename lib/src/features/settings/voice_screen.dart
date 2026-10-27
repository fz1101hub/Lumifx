import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/speech/speaker.dart';
import '../common/app_text.dart';
import '../common/layout.dart';

/// The voice stories are read with, for the app's language: automatic
/// (the most natural on the phone) or one of the phone's voices. Tapping
/// a voice chooses it and reads a line with it. When the phone has only
/// basic voices, says where to download a better one; the list is looked
/// up again on coming back.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with WidgetsBindingObserver {
  List<SpeechVoice>? _voices;
  String? _language;
  late Speaker _speaker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speaker = AppScope.of(context).speaker;
    final language = speechLanguage(
      Localizations.localeOf(context).languageCode,
    );
    if (language != _language) {
      _language = language;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings, maybe with a new voice.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final language = _language!;
    final voices = await _speaker.voices(language);
    if (mounted && language == _language) {
      setState(() => _voices = voices);
    }
  }

  Future<void> _choose(SpeechVoice? voice) async {
    final scope = AppScope.of(context);
    final sample = context.l10n.storytellerVoiceSample;
    final language = _language!;
    await scope.preferences.setSpeechVoice(language, voice?.id);
    await scope.speaker.stop();
    await scope.speaker.speak(sample, language, style: SpeechStyle.story);
  }

  @override
  void deactivate() {
    unawaited(_speaker.stop());
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = AppScope.of(context).preferences;
    final voices = _voices;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storytellerVoice)),
      body: voices == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: preferences,
              builder: (context, _) {
                final chosenId = preferences.speechVoiceFor(_language!);
                final chosen =
                    voices.where((v) => v.id == chosenId).firstOrNull;
                final best = bestVoice(voices);
                final onlyBasic = voices.every(
                    (v) => v.quality.index < VoiceQuality.enhanced.index);
                return ListView(
                  padding:
                      context.pageInsets(horizontal: 0, top: 12, bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        voices.isEmpty
                            ? l10n.storytellerVoiceNone
                            : l10n.storytellerVoiceHint,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (onlyBasic)
                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.record_voice_over),
                          title: Text(
                            theme.platform == TargetPlatform.iOS
                                ? l10n.storytellerVoiceBetterIos
                                : l10n.storytellerVoiceBetterAndroid,
                          ),
                        ),
                      ),
                    if (voices.isNotEmpty) ...[
                      _VoiceTile(
                        title: l10n.storytellerVoiceAutomatic,
                        subtitle: [
                          l10n.storytellerVoiceAutomaticDescription,
                          if (best != null) best.name,
                        ].join(' · '),
                        selected: chosen == null,
                        onTap: () => _choose(null),
                      ),
                      for (final voice in voices)
                        _VoiceTile(
                          title: voice.name,
                          subtitle: [
                            voiceQualityLabel(l10n, voice.quality),
                            if (voice.needsNetwork) l10n.voiceNeedsInternet,
                          ].join(' · '),
                          selected: voice == chosen,
                          onTap: () => _choose(voice),
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

/// How natural a voice sounds, in words.
String voiceQualityLabel(AppLocalizations l10n, VoiceQuality quality) =>
    switch (quality) {
      VoiceQuality.premium => l10n.voiceQualityPremium,
      VoiceQuality.enhanced => l10n.voiceQualityEnhanced,
      VoiceQuality.basic => l10n.voiceQualityBasic,
      VoiceQuality.novelty => l10n.voiceQualityNovelty,
    };

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.play_circle_outline),
      selected: selected,
      onTap: onTap,
    );
  }
}
