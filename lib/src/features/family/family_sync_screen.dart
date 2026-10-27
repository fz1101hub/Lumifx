import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../guests/guest_remote.dart';
import '../links/app_link.dart';
import 'family_sync.dart';

/// Joins the phone sharing at [host]:[port] and merges both ways; shows
/// how it went.
Future<bool> joinFamily(
    BuildContext context, String host, int port, String code) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final preferences = AppScope.of(context).preferences;
  try {
    final theirs =
        await FamilySync.join(host, port, code, FamilyBundle.of(preferences));
    final changes = await FamilyBundle.mergeInto(preferences, theirs);
    messenger
        .showSnackBar(SnackBar(content: Text(l10n.familySyncDone(changes))));
    return true;
  } on Object catch (error) {
    debugPrint('Family sync: $error');
    messenger.showSnackBar(SnackBar(content: Text(l10n.familySyncFailed)));
    return false;
  }
}

/// Family in sync: this phone shares (a QR code with its address and a
/// code) while the screen is open, or joins another phone sharing.
class FamilySyncScreen extends StatefulWidget {
  const FamilySyncScreen({this.address, super.key});

  /// Where to share instead of the phone's Wi-Fi address (tests).
  final InternetAddress? address;

  @override
  State<FamilySyncScreen> createState() => _FamilySyncScreenState();
}

class _FamilySyncScreenState extends State<FamilySyncScreen> {
  FamilySyncHost? _host;
  InternetAddress? _address;
  var _noWifi = false;
  var _started = false;
  final _joinAddress = TextEditingController();
  final _joinCode = TextEditingController();
  var _joining = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_share());
    }
  }

  @override
  void dispose() {
    unawaited(_host?.stop());
    _joinAddress.dispose();
    _joinCode.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final preferences = AppScope.of(context).preferences;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final host = FamilySyncHost(
      mine: () => FamilyBundle.of(preferences),
      onJoined: (theirs) async {
        final changes = await FamilyBundle.mergeInto(preferences, theirs);
        messenger.showSnackBar(
            SnackBar(content: Text(l10n.familySyncDone(changes))));
      },
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
      await host.start(address);
      if (!mounted) {
        await host.stop();
        return;
      }
      setState(() {
        _host = host;
        _address = address;
      });
    } on Object catch (error) {
      debugPrint('Family sync: $error');
      if (mounted) {
        setState(() => _noWifi = true);
      }
    }
  }

  Future<void> _join() async {
    final [host, port, ...] = [..._joinAddress.text.trim().split(':'), '', ''];
    final number = int.tryParse(port);
    final code = _joinCode.text.trim();
    if (host.isEmpty || number == null || code.isEmpty) {
      return;
    }
    setState(() => _joining = true);
    await joinFamily(context, host, number, code);
    if (mounted) {
      setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final host = _host;
    final address = _address;
    final port = host?.port;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familySync)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.familySyncDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (_noWifi)
            Text(l10n.familySyncNoWifi,
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge)
          else if (host == null || address == null || port == null)
            const LinearProgressIndicator()
          else ...[
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 220,
                  child: QrImageView(
                    data: AppLink.sync(address.address, port, host.code),
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.guestRemoteCode(host.code),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            SelectableText('${address.address}:$port',
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 32),
          Text(l10n.familySyncJoinTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _joinAddress,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.familySyncAddress,
              hintText: '192.168.1.20:40123',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _joinCode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: l10n.familySyncCodeField,
              border: const OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            onPressed: _joining ? null : _join,
            icon: const Icon(Icons.sync),
            label: Text(l10n.familySyncJoin),
          ),
        ],
      ),
    );
  }
}
