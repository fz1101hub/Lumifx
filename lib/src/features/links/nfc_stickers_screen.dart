import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/nfc/nfc_writer.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'ready_links.dart';

/// NFC stickers that start an effect when the phone touches them: written
/// here on Android, through the Shortcuts app on iPhone.
class NfcStickersScreen extends StatefulWidget {
  const NfcStickersScreen({super.key});

  @override
  State<NfcStickersScreen> createState() => _NfcStickersScreenState();
}

class _NfcStickersScreenState extends State<NfcStickersScreen> {
  late final AppLifecycleListener _lifecycle;
  bool? _available;
  var _enabled = false;

  @override
  void initState() {
    super.initState();
    // Back from the NFC settings: switched on, perhaps.
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) {
      return;
    }
    final nfc = AppScope.of(context).nfc;
    final available = await nfc.isAvailable();
    final enabled = available && await nfc.isEnabled();
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _write(String link) async {
    final l10n = context.l10n;
    final nfc = AppScope.of(context).nfc;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var waiting = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.nfc, size: 48),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.nfcHoldSticker, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(onPressed: nfc.cancel, child: Text(l10n.cancel)),
        ],
      ),
    ).whenComplete(() => waiting = false));
    final result = await nfc.write(link);
    if (waiting) {
      navigator.pop();
    }
    final message = switch (result) {
      NfcWriteResult.written => l10n.nfcWritten,
      NfcWriteResult.readOnly => l10n.nfcReadOnly,
      NfcWriteResult.tooSmall => l10n.nfcTooSmall,
      NfcWriteResult.notNdef => l10n.nfcNotNdef,
      NfcWriteResult.unavailable => l10n.nfcOff,
      NfcWriteResult.failed => l10n.nfcFailed,
      NfcWriteResult.cancelled => null,
    };
    if (result == NfcWriteResult.written) {
      unawaited(HapticFeedback.mediumImpact());
    }
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    if (result == NfcWriteResult.unavailable) {
      await _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final available = _available;
    final canWrite = available == true && _enabled;
    final iPhone = theme.platform == TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nfcStickers)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.nfcStickersDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (available == true && !_enabled)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.nfc),
                title: Text(l10n.nfcOff),
                trailing: TextButton(
                  onPressed: scope.nfc.openSettings,
                  child: Text(l10n.nfcOpenSettings),
                ),
              ),
            ),
          if (available == false)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iPhone ? Icons.shortcut : Icons.info_outline),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                          iPhone ? l10n.nfcShortcuts : l10n.nfcUnavailable),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final (title, link) in readyLinks(scope, l10n))
            Card(
              child: ListTile(
                title: Text(title),
                subtitle: SelectableText(link),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.copyLink,
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                                SnackBar(content: Text(l10n.linkCopied)));
                        }
                      },
                    ),
                    if (canWrite)
                      IconButton.filledTonal(
                        tooltip: l10n.nfcWrite,
                        icon: const Icon(Icons.nfc),
                        onPressed: () => _write(link),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
