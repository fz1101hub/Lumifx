import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../effects/playback_controller.dart';
import 'bridge_controller.dart';

/// Asks before forgetting the bridge, then forgets it. Returns true when it
/// was forgotten.
Future<bool> confirmForgetBridge(
  BuildContext context,
  BridgeController bridge,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.forgetBridgeQuestion),
      content: Text(l10n.forgetBridgeDescription),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.forget),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return false;
  }
  await bridge.forget();
  return true;
}

/// Uses the other bridge [bridgeId] instead; an effect playing on this
/// one stops first, so nothing is left running on the old lights.
Future<void> switchBridge(
  BuildContext context,
  BridgeController bridge,
  String bridgeId,
) async {
  final playback = AppScope.of(context).playback;
  if (playback.status != PlaybackStatus.idle) {
    await playback.stop();
  }
  await bridge.switchTo(bridgeId);
}
