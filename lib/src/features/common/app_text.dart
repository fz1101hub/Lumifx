import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../core/effects/effect.dart';
import '../../core/hue/entertainment/dtls/dtls_client.dart';
import '../../core/hue/hue_exceptions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../bridge/bridge_controller.dart';
import '../effects/playback_controller.dart';

export '../../../l10n/generated/app_localizations.dart';

extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String describeBridgeProblem(AppLocalizations l10n, BridgeProblem problem) =>
    switch (problem) {
      BridgeProblem.storageUnavailable => l10n.bridgeProblemStorageUnavailable,
      BridgeProblem.storageWriteFailed => l10n.bridgeProblemStorageWriteFailed,
      BridgeProblem.linkButtonTimeout => l10n.bridgeProblemLinkButtonTimeout,
      BridgeProblem.unauthorized => l10n.bridgeProblemUnauthorized,
      BridgeProblem.unreachable => l10n.bridgeProblemUnreachable,
      BridgeProblem.certificateMismatch =>
        l10n.bridgeProblemCertificateMismatch,
      BridgeProblem.unsupportedBridge => l10n.bridgeProblemUnsupportedBridge,
      BridgeProblem.bridgeBusy => l10n.bridgeProblemBusy,
      BridgeProblem.other => l10n.bridgeProblemOther,
    };

/// Why an action on the bridge failed, as a sentence. Errors the app knows
/// are translated; anything else falls back to the bridge's own words.
String describeError(AppLocalizations l10n, Object error) => switch (error) {
      UnsupportedBridgeException() => l10n.bridgeProblemUnsupportedBridge,
      CertificateMismatchException() => l10n.bridgeProblemCertificateMismatch,
      UnauthorizedException() => l10n.bridgeProblemUnauthorized,
      BridgeBusyException() => l10n.bridgeProblemBusy,
      StreamingKeyMissingException() => l10n.errorStreamingNeedsPairing,
      EmptyEntertainmentAreaException() => l10n.errorAreaNoLights,
      EntertainmentStoppedException() => l10n.errorStreamTakenOver,
      HueException(:final message) => message,
      DtlsException(:final failure) => switch (failure) {
          DtlsFailure.connectionLost => l10n.errorStreamingConnectionLost,
          DtlsFailure.noAnswer => l10n.errorStreamingNoAnswer,
          DtlsFailure.keyRejected => l10n.errorStreamingKeyRejected,
          DtlsFailure.verificationFailed => l10n.errorStreamingVerification,
          DtlsFailure.rejected => l10n.errorStreamingRejected,
          DtlsFailure.endedByBridge => l10n.errorStreamingEndedByBridge,
          DtlsFailure.closed ||
          DtlsFailure.protocol =>
            l10n.errorStreamingProtocol,
        },
      SocketException() ||
      TimeoutException() ||
      HttpException() ||
      http.ClientException() =>
        l10n.errorNoResponse,
      _ => l10n.errorGeneric,
    };

String describePlaybackNotice(AppLocalizations l10n, PlaybackNotice notice) =>
    switch (notice.kind) {
      PlaybackNoticeKind.bridgeUnreachable => notice.problem == null
          ? l10n.noticeBridgeUnreachable
          : describeBridgeProblem(l10n, notice.problem!),
      PlaybackNoticeKind.onOffOnlyLights =>
        l10n.noticeOnOffOnlyLights(notice.name ?? ''),
      PlaybackNoticeKind.targetGone => l10n.noticeTargetGone,
      PlaybackNoticeKind.startFailed =>
        l10n.noticeCouldNotStart(describeError(l10n, notice.error ?? '')),
      PlaybackNoticeKind.microphoneDenied => l10n.noticeMicrophoneDenied,
      PlaybackNoticeKind.microphoneFailed => l10n.noticeMicrophoneFailed,
      PlaybackNoticeKind.microphoneStopped => l10n.noticeMicrophoneStopped,
      PlaybackNoticeKind.streamEnded => switch (notice.error) {
          HueException() ||
          DtlsException() =>
            describeError(l10n, notice.error!),
          _ => l10n.noticeStreamingStopped,
        },
      PlaybackNoticeKind.sleepTimerDone => l10n.noticeSleepTimerDone,
    };

String describeSlot(AppLocalizations l10n, SlotLabel label) => switch (label) {
      NamedSlot(:final name) => name,
      PreviewLamp(:final number) => l10n.lamp(number),
      UnnamedChannel(:final id) => l10n.channel(id),
    };

/// Translated names and descriptions of the built-in effects. The effect
/// definitions keep their English text as the fallback.
extension EffectText on AppLocalizations {
  String effectName(LightingEffect effect) => switch (effect.id) {
        'fireplace' => effectNameFireplace,
        'ocean' => effectNameOcean,
        'aurora' => effectNameAurora,
        'sunset' => effectNameSunset,
        'thunderstorm' => effectNameThunderstorm,
        'disco' => effectNameDisco,
        'emerald_trickster' => effectNameEmeraldTrickster,
        'sleeping_dragon' => effectNameSleepingDragon,
        'mischievous_ghost' => effectNameMischievousGhost,
        'haunted_manor' => effectNameHauntedManor,
        'enchanted_fairy' => effectNameEnchantedFairy,
        'goblin_mine' => effectNameGoblinMine,
        'christmas_elves' => effectNameChristmasElves,
        'hidden_treasure' => effectNameHiddenTreasure,
        'krakens_cove' => effectNameKrakensCove,
        'meteor_shower' => effectNameMeteorShower,
        'dinosaur_valley' => effectNameDinosaurValley,
        'deep_sea_glow' => effectNameDeepSeaGlow,
        'beat_pulse' => effectNameBeatPulse,
        'party_chase' => effectNamePartyChase,
        'spectrum' => effectNameSpectrum,
        'mood_glow' => effectNameMoodGlow,
        'pumpkin_patch' => effectNamePumpkinPatch,
        'witches_cauldron' => effectNameWitchesCauldron,
        'vampires_castle' => effectNameVampiresCastle,
        'trick_or_treat' => effectNameTrickOrTreat,
        'santas_workshop' => effectNameSantasWorkshop,
        'silent_snowfall' => effectNameSilentSnowfall,
        'candlelight_carol' => effectNameCandlelightCarol,
        _ => effect.name,
      };

  String effectDescription(LightingEffect effect) => switch (effect.id) {
        'fireplace' => effectDescriptionFireplace,
        'ocean' => effectDescriptionOcean,
        'aurora' => effectDescriptionAurora,
        'sunset' => effectDescriptionSunset,
        'thunderstorm' => effectDescriptionThunderstorm,
        'disco' => effectDescriptionDisco,
        'emerald_trickster' => effectDescriptionEmeraldTrickster,
        'sleeping_dragon' => effectDescriptionSleepingDragon,
        'mischievous_ghost' => effectDescriptionMischievousGhost,
        'haunted_manor' => effectDescriptionHauntedManor,
        'enchanted_fairy' => effectDescriptionEnchantedFairy,
        'goblin_mine' => effectDescriptionGoblinMine,
        'christmas_elves' => effectDescriptionChristmasElves,
        'hidden_treasure' => effectDescriptionHiddenTreasure,
        'krakens_cove' => effectDescriptionKrakensCove,
        'meteor_shower' => effectDescriptionMeteorShower,
        'dinosaur_valley' => effectDescriptionDinosaurValley,
        'deep_sea_glow' => effectDescriptionDeepSeaGlow,
        'beat_pulse' => effectDescriptionBeatPulse,
        'party_chase' => effectDescriptionPartyChase,
        'spectrum' => effectDescriptionSpectrum,
        'mood_glow' => effectDescriptionMoodGlow,
        'pumpkin_patch' => effectDescriptionPumpkinPatch,
        'witches_cauldron' => effectDescriptionWitchesCauldron,
        'vampires_castle' => effectDescriptionVampiresCastle,
        'trick_or_treat' => effectDescriptionTrickOrTreat,
        'santas_workshop' => effectDescriptionSantasWorkshop,
        'silent_snowfall' => effectDescriptionSilentSnowfall,
        'candlelight_carol' => effectDescriptionCandlelightCarol,
        _ => effect.description,
      };

  String variantName(EffectVariant variant) => switch (variant.id) {
        'blue_flame' => variantBlueFlame,
        'emerald_embers' => variantEmeraldEmbers,
        'lagoon' => variantLagoon,
        'deep_purple' => variantDeepPurple,
        'rose_gold' => variantRoseGold,
        'ice' => variantIce,
        'desert' => variantDesert,
        'lavender' => variantLavender,
        'sea_storm' => variantSeaStorm,
        'sand_storm' => variantSandStorm,
        'neon' => variantNeon,
        'pastel' => variantPastel,
        _ => variant.name,
      };

  String? collectionName(LightingEffect effect) => switch (effect.collection) {
        null => null,
        'Relax' => collectionRelax,
        'Nature' => collectionNature,
        'Party' => collectionParty,
        'Magic & Fantasy' => collectionMagicFantasy,
        'Haunted' => collectionHaunted,
        'Halloween' => collectionHalloween,
        'Christmas Stories' => collectionChristmas,
        'Adventure' => collectionAdventure,
        'Pirates' => collectionPirates,
        'Space Adventures' => collectionSpace,
        'Dinosaurs' => collectionDinosaurs,
        'Underwater' => collectionUnderwater,
        'Music Sync' => collectionMusicSync,
        final other => other,
      };
}
