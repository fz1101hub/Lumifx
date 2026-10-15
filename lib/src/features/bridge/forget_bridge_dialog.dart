import 'package:flutter/material.dart';

import '../common/app_text.dart';
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
