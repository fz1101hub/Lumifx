import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import '../effects/effect_player_screen.dart';
import '../effects/player_route.dart';
import 'playlist.dart';
import 'playlist_editor.dart';

/// The user's playlists: play one, edit one, or make a new one.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final preferences = scope.preferences;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playlists)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PlaylistEditor()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.newPlaylist),
      ),
      body: ListenableBuilder(
        listenable: preferences,
        builder: (context, _) {
          final playlists = preferences.playlists;
          return ListView(
            padding: context.pageInsets(bottom: 96),
            children: [
              Text(l10n.playlistsDescription,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(l10n.noPlaylistsYet),
                ),
              for (final playlist in playlists)
                _PlaylistCard(key: ValueKey(playlist.id), playlist: playlist),
            ],
          );
        },
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, super.key});

  final Playlist playlist;

  Future<void> _play(BuildContext context) async {
    final playback = AppScope.of(context).playback;
    final effects = [
      for (final id in playlist.effectIds)
        if (AppScope.of(context).library.byId(id) case final effect?) effect,
    ];
    if (effects.isEmpty) {
      return;
    }
    if (effects.any((e) => e.hasRapidFlashes) &&
        !await confirmFlashingLights(context)) {
      return;
    }
    await playback.playPlaylist(playlist);
    if (context.mounted) {
      unawaited(openPlayer(context, playback.effect));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = [
      l10n.effectCount(playlist.effectIds.length),
      l10n.playlistEachShort(playlist.each.inMinutes),
      if (playlist.shuffle) l10n.shuffle,
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.queue_music),
        title: Text(playlist.name),
        subtitle: Text(summary),
        trailing: Semantics(
          label: l10n.playPlaylist(playlist.name),
          button: true,
          excludeSemantics: true,
          child: IconButton.filledTonal(
            icon: const Icon(Icons.play_arrow),
            onPressed: playlist.effectIds.isEmpty ? null : () => _play(context),
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaylistEditor(playlist: playlist),
          ),
        ),
      ),
    );
  }
}
