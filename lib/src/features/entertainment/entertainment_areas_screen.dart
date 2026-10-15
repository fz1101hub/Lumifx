import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import 'entertainment_area_editor.dart';

/// Lists the bridge's entertainment areas and lets the user add or edit
/// them without leaving LumiFX.
class EntertainmentAreasScreen extends StatelessWidget {
  const EntertainmentAreasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) {
        final home = bridge.isConnected ? bridge.home : null;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.entertainmentAreas)),
          floatingActionButton: home != null
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const EntertainmentAreaEditor(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newArea),
                )
              : null,
          body: Builder(
            builder: (context) {
              if (home == null) {
                return Center(child: Text(l10n.noBridgeConnected));
              }
              final areas = home.entertainmentAreas;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Text(
                    l10n.entertainmentAreasDescription(maxLightsPerArea),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (areas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(l10n.noAreasYet),
                    ),
                  for (final area in areas)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bolt),
                        title: Text(area.name),
                        subtitle: Text([
                          l10n.channelCount(area.channels.length),
                          if (area.isStreaming) l10n.inUse,
                        ].join(' · ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => EntertainmentAreaEditor(area: area),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
