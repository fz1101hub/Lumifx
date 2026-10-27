import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../common/app_text.dart';
import '../links/app_link.dart';
import '../playlists/playlist.dart';
import 'user_scene.dart';
import 'user_story.dart';

/// Scenes, stories and playlists packed into a link, to pass to another
/// phone (or keep as a backup): JSON, zlib-compressed, base64url.
class SharedBundle {
  const SharedBundle({
    this.scenes = const [],
    this.stories = const [],
    this.playlists = const [],
  });

  final List<UserScene> scenes;
  final List<UserStory> stories;
  final List<Playlist> playlists;

  bool get isEmpty => scenes.isEmpty && stories.isEmpty && playlists.isEmpty;

  int get length => scenes.length + stories.length + playlists.length;

  static const _version = 1;

  /// Limits for what a link may hold: generous for anything a person makes,
  /// small enough that a hostile link cannot exhaust memory (a deflate
  /// stream can expand a thousandfold) or flood the library.
  static const maxLinkData = 128 * 1024;
  static const maxJsonBytes = 2 * 1024 * 1024;
  static const maxScenes = 200;
  static const maxStories = 100;
  static const maxPlaylists = 100;

  String encode() {
    final json = jsonEncode({
      'v': _version,
      'scenes': [for (final s in scenes) s.toJson()],
      if (stories.isNotEmpty) 'stories': [for (final s in stories) s.toJson()],
      'playlists': [for (final p in playlists) p.toJson()],
    });
    return base64Url
        .encode(ZLibCodec(level: 9).encode(utf8.encode(json)))
        .replaceAll('=', '');
  }

  /// Null when [data] is not a bundle (truncated link, other app...).
  static SharedBundle? decode(String data) {
    if (data.length > maxLinkData) {
      return null;
    }
    try {
      final padded = data.padRight((data.length + 3) ~/ 4 * 4, '=');
      final json = jsonDecode(
        utf8.decode(_inflate(base64Url.decode(padded), maxJsonBytes)),
      );
      if (json is! Map || json['v'] != _version) {
        return null;
      }
      final scenes = json['scenes'];
      final stories = json['stories'];
      final playlists = json['playlists'];
      final bundle = SharedBundle(
        scenes: [
          if (scenes is List)
            for (final item in scenes.take(maxScenes))
              if (UserScene.fromJson(item) case final scene?) scene,
        ],
        stories: [
          if (stories is List)
            for (final item in stories.take(maxStories))
              if (UserStory.fromJson(item) case final story?) story,
        ],
        playlists: [
          if (playlists is List)
            for (final item in playlists.take(maxPlaylists))
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

  /// Inflates [compressed], giving up as soon as the output passes [limit].
  static List<int> _inflate(List<int> compressed, int limit) {
    final output = _LimitedSink(limit);
    ZLibDecoder().startChunkedConversion(output)
      ..add(compressed)
      ..close();
    return output.bytes.takeBytes();
  }
}

class _LimitedSink implements Sink<List<int>> {
  _LimitedSink(this.limit);

  final int limit;
  final bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (bytes.length + chunk.length > limit) {
      throw const FormatException('Shared data too large');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}

/// Shows [bundle] as a QR code and a link to copy.
Future<void> showShareDialog(BuildContext context, SharedBundle bundle) =>
    showDialog<void>(
      context: context,
      builder: (_) => ShareDialog(link: bundle.link),
    );

/// A link as a QR code and a button to copy it.
class ShareDialog extends StatelessWidget {
  const ShareDialog({required this.link, this.title, super.key});

  final String link;

  /// The dialog's title; "Share" otherwise.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(title ?? l10n.share),
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
              // A fixed size: the dialog measures its content, which the
              // QR code's layout builder cannot answer by itself.
              child: SizedBox.square(
                dimension: 220,
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, _) => Center(
                    child: Text(
                      l10n.tooLongForQr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black),
                    ),
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
/// playlists at the imported scenes and stories. Returns whether anything was added.
Future<bool> importBundle(BuildContext context, SharedBundle bundle) async {
  final l10n = context.l10n;
  final names = [
    for (final s in bundle.scenes) s.name,
    for (final s in bundle.stories) s.name,
    for (final p in bundle.playlists) p.name,
  ];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importQuestion),
      scrollable: true,
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
  final scenes = [
    for (final (i, scene) in bundle.scenes.indexed)
      UserScene(
        id: ids[scene.id] = '${UserScene.idPrefix}$stamp-$i',
        name: scene.name,
        colors: scene.colors,
        motion: scene.motion,
      ),
  ];
  final stories = [
    for (final (i, story) in bundle.stories.indexed)
      UserStory(
        id: ids[story.id] = '${UserStory.idPrefix}$stamp-$i',
        name: story.name,
        colors: story.colors,
        motion: story.motion,
        length: story.length,
        moments: story.moments,
      ),
  ];
  // One write for everything, however much the link holds.
  await preferences.addAll(
    scenes: scenes,
    stories: stories,
    playlists: [
      for (final (i, playlist) in bundle.playlists.indexed)
        Playlist(
          id: 'p$stamp-$i',
          name: playlist.name,
          effectIds: [for (final id in playlist.effectIds) ids[id] ?? id],
          each: playlist.each,
          shuffle: playlist.shuffle,
        ),
    ],
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.importedItems(bundle.length)),
      ));
  }
  return true;
}

/// The bundle for [playlist]: the playlist and the user's scenes and
/// stories it plays.
SharedBundle bundleOfPlaylist(BuildContext context, Playlist playlist) {
  final library = AppScope.of(context).library;
  return SharedBundle(
    scenes: [
      for (final id in playlist.effectIds)
        if (library.userScene(id) case final scene?) scene,
    ],
    stories: [
      for (final id in playlist.effectIds)
        if (library.userStory(id) case final story?) story,
    ],
    playlists: [playlist],
  );
}
