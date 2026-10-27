import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_health.dart';
import '../common/app_text.dart';
import '../common/layout.dart';

/// The light health check: lamps the bridge cannot reach, weak radio
/// links and firmware ready to install, each with what to do.
class LightHealthScreen extends StatefulWidget {
  const LightHealthScreen({super.key});

  static String issueName(AppLocalizations l10n, LightIssue issue) =>
      switch (issue) {
        LightIssue.unreachable => l10n.lightIssueUnreachable,
        LightIssue.weakSignal => l10n.lightIssueWeakSignal,
        LightIssue.updateReady => l10n.lightIssueUpdate,
      };

  static String advice(AppLocalizations l10n, LightIssue issue) =>
      switch (issue) {
        LightIssue.unreachable => l10n.lightIssueUnreachableAdvice,
        LightIssue.weakSignal => l10n.lightIssueWeakSignalAdvice,
        LightIssue.updateReady => l10n.lightIssueUpdateAdvice,
      };

  @override
  State<LightHealthScreen> createState() => _LightHealthScreenState();
}

class _LightHealthScreenState extends State<LightHealthScreen> {
  HueHealthReport? _report;
  Object? _error;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    final client = AppScope.of(context).bridge.client;
    if (client == null) {
      return;
    }
    try {
      final report = await client.fetchHealth();
      if (mounted) {
        setState(() {
          _report = report;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final client = AppScope.of(context).bridge.client;
    final report = _report;
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.lightHealth)),
      body: client == null
          ? Center(child: Text(l10n.noBridgeConnected))
          : RefreshIndicator(
              onRefresh: _check,
              child: ListView(
                padding: context.pageInsets(),
                children: [
                  Text(l10n.lightHealthDescription,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  if (error != null)
                    Text(l10n.lightHealthFailed(describeError(l10n, error)),
                        style: TextStyle(color: theme.colorScheme.error))
                  else if (report == null)
                    const LinearProgressIndicator()
                  else ...[
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          Icon(
                            report.problems == 0
                                ? Icons.check_circle_outline
                                : Icons.build_circle_outlined,
                            color: report.problems == 0
                                ? Colors.green
                                : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              report.problems == 0
                                  ? l10n
                                      .lightHealthAllFine(report.lights.length)
                                  : l10n.lightHealthProblems(report.problems),
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (report.bridgeUpdateReady)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.system_update_alt),
                          title: Text(l10n.lightHealthBridgeUpdate),
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (final light in report.lights) _LightCard(light),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard(this.light);

  final HueLightHealth light;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final worst = light.worst;
    final detail = [
      if (light.model case final model? when model.isNotEmpty) model,
      if (light.firmware case final firmware? when firmware.isNotEmpty)
        firmware,
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (worst) {
                    null => Icons.lightbulb_outline,
                    LightIssue.unreachable => Icons.portable_wifi_off,
                    LightIssue.weakSignal => Icons.network_check,
                    LightIssue.updateReady => Icons.system_update_alt,
                  },
                  color: switch (worst) {
                    null => Colors.green,
                    LightIssue.unreachable => theme.colorScheme.error,
                    _ => Colors.orange,
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(light.name, style: theme.textTheme.titleMedium),
                ),
                Text(
                  worst == null
                      ? l10n.lightHealthFine
                      : LightHealthScreen.issueName(l10n, worst),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(detail, style: theme.textTheme.bodySmall),
              ),
            ],
            for (final issue in LightIssue.values)
              if (light.issues.contains(issue)) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    light.issues.length > 1
                        ? '${LightHealthScreen.issueName(l10n, issue)}: '
                            '${LightHealthScreen.advice(l10n, issue)}'
                        : LightHealthScreen.advice(l10n, issue),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
