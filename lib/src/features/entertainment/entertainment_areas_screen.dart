import 'package:flutter/material.dart';

import '../../app_scope.dart';
import 'entertainment_area_editor.dart';

/// Lists the bridge's entertainment areas and lets the user add or edit
/// them without leaving LumiFX.
class EntertainmentAreasScreen extends StatelessWidget {
  const EntertainmentAreasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bridge = AppScope.of(context).bridge;
    return ListenableBuilder(
      listenable: bridge,
      builder: (context, _) {
        final home = bridge.isConnected ? bridge.home : null;
        return Scaffold(
          appBar: AppBar(title: const Text('Entertainment areas')),
          floatingActionButton: home != null
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const EntertainmentAreaEditor(),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('New area'),
                )
              : null,
          body: Builder(
            builder: (context) {
              if (home == null) {
                return const Center(child: Text('No bridge connected.'));
              }
              final areas = home.entertainmentAreas;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Text(
                    'Entertainment areas let LumiFX stream fast effects, music '
                    'sync included, to up to $maxLightsPerArea lights at once.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (areas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No areas yet. Create one to get started.'),
                    ),
                  for (final area in areas)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bolt),
                        title: Text(area.name),
                        subtitle: Text(
                          '${area.channels.length} '
                          '${area.channels.length == 1 ? 'channel' : 'channels'}'
                          '${area.isStreaming ? ' · in use' : ''}',
                        ),
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
