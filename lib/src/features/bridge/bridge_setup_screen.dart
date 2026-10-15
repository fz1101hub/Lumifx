import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';
import 'bridge_controller.dart';

/// Finds a bridge on the network and pairs with it.
class BridgeSetupScreen extends StatefulWidget {
  const BridgeSetupScreen({super.key});

  @override
  State<BridgeSetupScreen> createState() => _BridgeSetupScreenState();
}

class _BridgeSetupScreenState extends State<BridgeSetupScreen> {
  final _bridges = <HueBridgeInfo>[];
  StreamSubscription<HueBridgeInfo>? _search;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    _search?.cancel();
    super.dispose();
  }

  void _startSearch() {
    _search?.cancel();
    setState(() {
      _bridges.clear();
      _searching = true;
    });
    _search = AppScope.of(context).discovery.discover().listen(
      (bridge) => setState(() => _bridges.add(bridge)),
      onDone: () {
        if (mounted) {
          setState(() => _searching = false);
        }
      },
    );
  }

  Future<void> _pair(HueBridgeInfo bridge) async {
    final controller = AppScope.of(context).bridge;
    final paired = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PairingDialog(controller: controller, bridge: bridge),
    );
    if (paired == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _enterAddress() async {
    final controller = AppScope.of(context).bridge;
    final host = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualAddressDialog(),
    );
    if (host == null || host.isEmpty || !mounted) {
      return;
    }
    try {
      final bridge = await controller.probe(host);
      if (mounted) {
        await _pair(bridge);
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.noBridgeAt(host))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.connectYourBridge)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.sameWifiHint, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(l10n.bridgesFound, style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_searching)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: l10n.searchAgain,
                  onPressed: _startSearch,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_bridges.isEmpty && !_searching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noBridgeFoundYet),
            ),
          for (final bridge in _bridges)
            Card(
              child: ListTile(
                leading: const Icon(Icons.router_outlined),
                title: Text(bridge.displayName),
                subtitle: Text(bridge.host),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pair(bridge),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _enterAddress,
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.enterIpAddress),
          ),
        ],
      ),
    );
  }
}

class _PairingDialog extends StatefulWidget {
  const _PairingDialog({required this.controller, required this.bridge});

  final BridgeController controller;
  final HueBridgeInfo bridge;

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  static const _timeout = Duration(seconds: 30);

  late final Timer _ticker;
  int _secondsLeft = _timeout.inSeconds;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      }
    });
    _run();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    final paired =
        await widget.controller.pair(widget.bridge, timeout: _timeout);
    if (!mounted) {
      return;
    }
    if (paired) {
      Navigator.of(context).pop(true);
    } else {
      _ticker.cancel();
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_failed) {
      final problem = widget.controller.problem;
      return AlertDialog(
        title: Text(l10n.notPaired),
        content: Text(problem == null
            ? l10n.pairingCancelled
            : describeBridgeProblem(l10n, problem)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.close),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l10n.pressLinkButton),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_outlined, size: 56),
          const SizedBox(height: 16),
          Text(l10n.pressLinkButtonDescription),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _secondsLeft / _timeout.inSeconds),
          const SizedBox(height: 8),
          Text(l10n.secondsShort(_secondsLeft)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.controller.cancelPairing();
            Navigator.of(context).pop(false);
          },
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ManualAddressDialog extends StatefulWidget {
  const _ManualAddressDialog();

  @override
  State<_ManualAddressDialog> createState() => _ManualAddressDialogState();
}

class _ManualAddressDialogState extends State<_ManualAddressDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.bridgeIpAddress),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: '192.168.1.20'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.connect),
        ),
      ],
    );
  }
}
