import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../links/app_link.dart';
import '../playlists/playlist.dart';
import 'user_scene.dart';

/// Scenes and playlists packed into a link, to pass to another phone (or
/// keep as a backup): JSON, zlib-compressed, base64url.
class SharedBundle {
  const SharedBundle({this.scenes = const [], this.playlists = const []});

  final List<UserScene> scenes;
  final List<Playlist> playlists;

  bool get isEmpty => scenes.isEmpty && playlists.isEmpty;

  static const _version = 1;

  String encode() {
    final json = jsonEncode({
      'v': _version,
      'scenes': [for (final s in scenes) s.toJson()],
      'playlists': [for (final p in playlists) p.toJson()],
    });
    return base64Url
        .encode(ZLibCodec(level: 9).encode(utf8.encode(json)))
        .replaceAll('=', '');
  }

  /// Null when [data] is not a bundle (truncated link, other app...).
  static SharedBundle? decode(String data) {
    try {
      final padded = data.padRight((data.length + 3) ~/ 4 * 4, '=');
      final json = jsonDecode(
        utf8.decode(ZLibCodec().decode(base64Url.decode(padded))),
      );
      if (json is! Map || json['v'] != _version) {
        return null;
      }
      final scenes = json['scenes'];
      final playlists = json['playlists'];
      final bundle = SharedBundle(
        scenes: [
          if (scenes is List)
            for (final item in scenes)
              if (UserScene.fromJson(item) case final scene?) scene,
        ],
        playlists: [
          if (playlists is List)
            for (final item in playlists)
              if (Playlist.fromJson(item) case final playlist?) playlist,
        ],
      );
      return bundle.isEmpty ? null : bundle;
    } on Object {
      return null;
    }
  }

  /// The link that imports this bundle.
  String get link => AppLink.import(encode());
}

/// Shows [bundle] as a QR code and a link to copy.
Future<void> showShareDialog(BuildContext context, SharedBundle bundle) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ShareDialog(bundle: bundle),
    );

class _ShareDialog extends StatelessWidget {
  const _ShareDialog({required this.bundle});

  final SharedBundle bundle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final link = bundle.link;
    return AlertDialog(
      title: Text(l10n.share),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.shareDescription),
          const SizedBox(height: 16),
          Semantics(
            label: l10n.qrCode,
            image: true,
            excludeSemantics: true,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: link,
                size: 220,
                backgroundColor: Colors.white,
                errorStateBuilder: (context, _) => SizedBox(
                  width: 220,
                  child: Text(
                    l10n.tooLongForQr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
            }
          },
          icon: const Icon(Icons.copy),
          label: Text(l10n.copyLink),
        ),
      ],
    );
  }
}

/// Asks before adding a received bundle, then adds it with fresh ids (so
/// importing twice makes copies instead of overwriting), pointing the
/// playlists at the imported scenes. Returns whether anything was added.
Future<bool> importBundle(BuildContext context, SharedBundle bundle) async {
  final l10n = context.l10n;
  final names = [
    for (final s in bundle.scenes) s.name,
    for (final p in bundle.playlists) p.name,
  ];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importQuestion),
      content: Text(names.join('\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.add),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return false;
  }
  final preferences = AppScope.of(context).preferences;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final ids = <String, String>{};
  for (final (i, scene) in bundle.scenes.indexed) {
    final id = '${UserScene.idPrefix}$stamp-$i';
    ids[scene.id] = id;
    await preferences.saveUserScene(UserScene(
      id: id,
      name: scene.name,
      colors: scene.colors,
      motion: scene.motion,
    ));
  }
  for (final (i, playlist) in bundle.playlists.indexed) {
    await preferences.savePlaylist(Playlist(
      id: 'p$stamp-$i',
      name: playlist.name,
      effectIds: [for (final id in playlist.effectIds) ids[id] ?? id],
      each: playlist.each,
      shuffle: playlist.shuffle,
    ));
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(l10n.imported(bundle.scenes.length, bundle.playlists.length)),
      ));
  }
  return true;
}

/// The bundle for [playlist]: the playlist and the user's scenes it plays.
SharedBundle bundleOfPlaylist(BuildContext context, Playlist playlist) {
  final library = AppScope.of(context).library;
  return SharedBundle(
    scenes: [
      for (final id in playlist.effectIds)
        if (library.userScene(id) case final scene?) scene,
    ],
    playlists: [playlist],
  );
}
