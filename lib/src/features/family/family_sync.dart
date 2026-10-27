import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../library/preferences_controller.dart';
import '../library/user_scene.dart';
import '../library/user_story.dart';
import '../playlists/playlist.dart';
import '../routines/child.dart';

/// What the family keeps the same on every phone: the scenes, stories
/// and playlists made, the favourites and the children's profiles.
class FamilyBundle {
  const FamilyBundle({
    this.scenes = const [],
    this.stories = const [],
    this.playlists = const [],
    this.favorites = const [],
    this.children = const [],
  });

  /// What this phone holds now.
  factory FamilyBundle.of(PreferencesController preferences) => FamilyBundle(
        scenes: preferences.userScenes,
        stories: preferences.userStories,
        playlists: preferences.playlists,
        favorites: preferences.favorites,
        children: preferences.children,
      );

  final List<UserScene> scenes;
  final List<UserStory> stories;
  final List<Playlist> playlists;
  final List<String> favorites;
  final List<Child> children;

  /// Makes this what [preferences] hold.
  Future<void> applyTo(PreferencesController preferences) =>
      preferences.replaceFamily(
        scenes: scenes,
        stories: stories,
        playlists: playlists,
        favorites: favorites,
        children: children,
      );

  /// Merges [theirs] into [preferences]; how many things changed.
  static Future<int> mergeInto(
      PreferencesController preferences, FamilyBundle theirs) async {
    final (:merged, :changes) = merge(FamilyBundle.of(preferences), theirs);
    if (changes > 0) {
      await merged.applyTo(preferences);
    }
    return changes;
  }

  static const _version = 1;
  static const maxBytes = 4 * 1024 * 1024;

  Map<String, Object?> toJson() => {
        'v': _version,
        'scenes': [for (final s in scenes) s.toJson()],
        'stories': [for (final s in stories) s.toJson()],
        'playlists': [for (final p in playlists) p.toJson()],
        'favorites': favorites,
        'children': [for (final c in children) c.toJson()],
      };

  static FamilyBundle? fromJson(Object? json) {
    if (json is! Map || json['v'] != _version) {
      return null;
    }
    List<Object?> list(String key) =>
        json[key] is List ? json[key] as List : const [];
    return FamilyBundle(
      scenes: [
        for (final item in list('scenes').take(200))
          if (UserScene.fromJson(item) case final scene?) scene,
      ],
      stories: [
        for (final item in list('stories').take(100))
          if (UserStory.fromJson(item) case final story?) story,
      ],
      playlists: [
        for (final item in list('playlists').take(100))
          if (Playlist.fromJson(item) case final playlist?) playlist,
      ],
      favorites: [
        for (final item in list('favorites').take(200))
          if (item is String && item.length <= 120) item,
      ],
      children: [
        for (final item in list('children').take(Child.maxChildren))
          if (Child.fromJson(item) case final child?) child,
      ],
    );
  }

  /// Both phones' things together. An item both have, but not alike, is
  /// settled the same way on both phones (the one whose data sorts last),
  /// so after one exchange they hold the same.
  static ({FamilyBundle merged, int changes}) merge(
      FamilyBundle mine, FamilyBundle theirs) {
    var changes = 0;
    List<T> byId<T>(
        List<T> a, List<T> b, String Function(T) id, Object? Function(T) json,
        {int? most}) {
      final result = <String, T>{for (final item in a) id(item): item};
      for (final item in b) {
        final key = id(item);
        final current = result[key];
        if (current == null) {
          result[key] = item;
          changes++;
        } else {
          final ours = jsonEncode(json(current));
          final other = jsonEncode(json(item));
          if (ours != other && other.compareTo(ours) > 0) {
            result[key] = item;
            changes++;
          }
        }
      }
      final values = result.values.toList();
      return most == null ? values : values.take(most).toList();
    }

    final favorites = [...mine.favorites];
    for (final id in theirs.favorites) {
      if (!favorites.contains(id)) {
        favorites.add(id);
        changes++;
      }
    }
    final merged = FamilyBundle(
      scenes: byId(mine.scenes, theirs.scenes, (s) => s.id, (s) => s.toJson()),
      stories:
          byId(mine.stories, theirs.stories, (s) => s.id, (s) => s.toJson()),
      playlists: byId(
          mine.playlists, theirs.playlists, (p) => p.id, (p) => p.toJson()),
      favorites: favorites,
      children: byId(
          mine.children, theirs.children, (c) => c.id, (c) => c.toJson(),
          most: Child.maxChildren),
    );
    return (merged: merged, changes: changes);
  }
}

/// The exchange between two phones on the home Wi-Fi, over a plain socket:
/// `LUMIFX-SYNC/1 <code> <length>` and the joining phone's things, then
/// `OK <length>` and the sharing phone's. Both then merge.
abstract final class FamilySync {
  static const _hello = 'LUMIFX-SYNC/1';
  static const timeout = Duration(seconds: 10);

  static String newCode([math.Random? random]) {
    final r = random ?? math.Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// Joins the phone sharing at [host]:[port] with [code]: sends [mine],
  /// returns theirs.
  static Future<FamilyBundle> join(
      String host, int port, String code, FamilyBundle mine) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      final body = utf8.encode(jsonEncode(mine.toJson()));
      socket.add(utf8.encode('$_hello $code ${body.length}\n'));
      socket.add(body);
      await socket.flush();
      final reader = _Reader(socket);
      final header = await reader.line().timeout(timeout);
      final words = header.split(' ');
      final length =
          words.length == 2 && words[0] == 'OK' ? int.tryParse(words[1]) : null;
      if (length == null || length < 0 || length > FamilyBundle.maxBytes) {
        throw const FamilySyncException('refused');
      }
      final theirs = FamilyBundle.fromJson(
          jsonDecode(utf8.decode(await reader.bytes(length).timeout(timeout))));
      if (theirs == null) {
        throw const FamilySyncException('unreadable');
      }
      return theirs;
    } finally {
      socket.destroy();
    }
  }
}

class FamilySyncException implements Exception {
  const FamilySyncException(this.reason);

  final String reason;

  @override
  String toString() => 'FamilySyncException: $reason';
}

/// A phone sharing its things: it answers one joining phone at a time,
/// with the right code, until stopped.
class FamilySyncHost {
  FamilySyncHost({
    required this.mine,
    required this.onJoined,
    String? code,
  }) : code = code ?? FamilySync.newCode();

  /// This phone's things now.
  final FamilyBundle Function() mine;

  /// The things of a phone that joined.
  final void Function(FamilyBundle theirs) onJoined;
  final String code;

  ServerSocket? _server;

  int? get port => _server?.port;

  Future<void> start(InternetAddress address) async {
    await stop();
    final server = await ServerSocket.bind(address, 0);
    _server = server;
    server.listen((socket) => unawaited(_serve(socket)), onError: (_) {});
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close();
  }

  Future<void> _serve(Socket socket) async {
    try {
      final reader = _Reader(socket);
      final words =
          (await reader.line().timeout(FamilySync.timeout)).split(' ');
      final length =
          words.length == 3 && words[0] == FamilySync._hello && words[1] == code
              ? int.tryParse(words[2])
              : null;
      if (length == null || length < 0 || length > FamilyBundle.maxBytes) {
        return;
      }
      final theirs = FamilyBundle.fromJson(jsonDecode(
          utf8.decode(await reader.bytes(length).timeout(FamilySync.timeout))));
      if (theirs == null) {
        return;
      }
      final body = utf8.encode(jsonEncode(mine().toJson()));
      socket.add(utf8.encode('OK ${body.length}\n'));
      socket.add(body);
      await socket.flush();
      onJoined(theirs);
    } on Object {
      // A stranger or a dropped connection: nothing changes.
    } finally {
      socket.destroy();
    }
  }
}

/// Reads a line, then a number of bytes, from a socket.
class _Reader {
  _Reader(Stream<Uint8List> stream) {
    _subscription = stream.listen((chunk) {
      _buffer.addAll(chunk);
      _check();
    }, onDone: () {
      _done = true;
      _check();
    }, onError: (Object _) {
      _done = true;
      _check();
    });
  }

  late final StreamSubscription<Uint8List> _subscription;
  final _buffer = <int>[];
  var _done = false;
  bool Function()? _waiting;

  void _check() {
    if (_waiting?.call() ?? false) {
      _waiting = null;
    }
  }

  Future<String> line() {
    final done = Completer<String>();
    _waiting = () {
      final end = _buffer.indexOf(10);
      if (end >= 0) {
        final text = utf8.decode(_buffer.sublist(0, end));
        _buffer.removeRange(0, end + 1);
        done.complete(text);
        return true;
      }
      if (_done || _buffer.length > 200) {
        done.completeError(const FamilySyncException('no line'));
        return true;
      }
      return false;
    };
    _check();
    return done.future;
  }

  Future<List<int>> bytes(int count) {
    final done = Completer<List<int>>();
    _waiting = () {
      if (_buffer.length >= count) {
        final data = _buffer.sublist(0, count);
        _buffer.removeRange(0, count);
        unawaited(_subscription.cancel());
        done.complete(data);
        return true;
      }
      if (_done) {
        done.completeError(const FamilySyncException('cut short'));
        return true;
      }
      return false;
    };
    _check();
    return done.future;
  }
}
