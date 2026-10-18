import '../../app_scope.dart';
import '../common/app_text.dart';
import 'app_link.dart';

/// Ready-made links, each with what it does: the favourite effects, one
/// in the room playing now, the playlists, bedtime and stop.
List<(String, String)> readyLinks(AppScope scope, AppLocalizations l10n) {
  final preferences = scope.preferences;
  final library = scope.library;
  final room = scope.playback.group?.name;
  final favorites = [
    for (final id in preferences.favorites.isNotEmpty
        ? preferences.favorites
        : const ['fireplace', 'aurora'])
      if (library.byId(id) case final effect?) effect,
  ];
  return [
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
    (l10n.linkBedtime, AppLink.bedtime),
    (l10n.linkStop, AppLink.stop),
  ];
}
