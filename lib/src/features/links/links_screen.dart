import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../common/layout.dart';
import 'app_link.dart';

/// Explains `lumifx://` links and offers ready-made ones to copy into
/// Siri Shortcuts or an Android automation.
class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final preferences = scope.preferences;
    final library = scope.library;
    final room = scope.playback.group?.name;
    final favorites = [
      for (final id in preferences.favorites.isNotEmpty
          ? preferences.favorites
          : const ['fireplace', 'aurora'])
        if (library.byId(id) case final effect?) effect,
    ];
    final links = [
      for (final effect in favorites)
        (l10n.linkPlay(l10n.effectName(effect)), AppLink.play(effect.id)),
      if (room != null && favorites.isNotEmpty)
        (
          l10n.linkPlayIn(l10n.effectName(favorites.first), room),
          AppLink.play(favorites.first.id, room: room),
        ),
      for (final playlist in preferences.playlists)
        // By id: a name may hold a "/" or change later.
        (l10n.linkPlaylist(playlist.name), AppLink.playlist(playlist.id)),
      (l10n.linkStop, AppLink.stop),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.linksTitle)),
      body: ListView(
        padding: context.pageInsets(),
        children: [
          Text(l10n.linksDescription, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          for (final (title, link) in links)
            Card(
              child: ListTile(
                title: Text(title),
                subtitle: SelectableText(link),
                trailing: IconButton(
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
              ),
            ),
          const SizedBox(height: 8),
          Text(l10n.linksNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
