import 'package:flutter/material.dart';

import 'bridge_controller.dart';

/// Asks before forgetting the bridge, then forgets it. Returns true when it
/// was forgotten.
Future<bool> confirmForgetBridge(
  BuildContext context,
  BridgeController bridge,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Forget this bridge?'),
      content: const Text(
        'You will need to press the link button again to reconnect.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Forget'),
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
