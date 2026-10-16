import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/effects/effect.dart';
import 'package:lumifx/src/core/effects/effect_event.dart';
import 'package:lumifx/src/core/effects/engine/effect_renderer.dart';
import 'package:lumifx/src/features/library/effect_library.dart';
import 'package:lumifx/src/features/library/preferences_controller.dart';
import 'package:lumifx/src/features/library/sharing.dart';
import 'package:lumifx/src/features/library/user_scene.dart';
import 'package:lumifx/src/features/library/user_story.dart';
import 'package:lumifx/src/features/playlists/playlist.dart';

void main() {
  final story = UserStory(
    id: 'story:1',
    name: 'The lost star',
    colors: const ['#000033', '#112266', '#3355AA'],
    motion: SceneMotion.calm,
    length: 40,
    moments: const [
      StoryMoment(
        at: 38,
        kind: StoryMomentKind.footsteps,
        words: 'Who is there?',
      ),
      StoryMoment(at: 0, kind: StoryMomentKind.wordsOnly, words: 'Once…'),
      StoryMoment(at: 8, kind: StoryMomentKind.spark, color: '#FFD84D'),
      StoryMoment(at: 20, kind: StoryMomentKind.darkness),
      StoryMoment(at: 25, kind: StoryMomentKind.lightning),
    ],
  );

  test('a story of your own plays its background and its moments', () {
    expect(story.moments.map((m) => m.at), [0, 8, 20, 25, 38],
        reason: 'kept in time order');
    final effect = story.toEffect();
    expect(effect.kind, EffectKind.story);
    expect(effect.cycleLength, const Duration(seconds: 40));
    expect(effect.isLooping, isTrue);
    final [background, spark, dark, lightning, steps] = effect.events;
    expect(background.type, EffectEventTypes.ambientPalette);
    expect(background.duration, const Duration(seconds: 40));
    expect(background.parameters['palette'], story.colors);
    expect(spark.type, EffectEventTypes.magicFlash);
    expect(spark.at, const Duration(seconds: 8));
    expect(spark.parameters['color'], '#FFD84D');
    expect(dark.type, EffectEventTypes.dim);
    expect(lightning.type, EffectEventTypes.lightning);
    expect(
        lightning.parameters['color'], StoryMomentKind.lightning.defaultColor);
    expect(effect.hasRapidFlashes, isTrue, reason: 'lightning warns first');
    // The last steps are cut at the end of the story, not past it.
    expect(steps.type, EffectEventTypes.footsteps);
    expect(steps.end, const Duration(seconds: 40));
    // Words only change nothing on the lights.
    expect(effect.events, hasLength(5));
    expect(story.narration, [(0, 'Once…'), (38, 'Who is there?')]);

    // And it renders on any number of lights.
    final renderer = EffectRenderer(effect, slotCount: 3, seed: 1);
    for (var s = 0; s < 45; s++) {
      expect(renderer.render(Duration(seconds: s)), hasLength(3));
    }
  });

  test('a story survives storage and sharing as it was', () {
    final back = UserStory.fromJson(story.toJson())!;
    expect(back.toJson(), story.toJson());

    final bundle =
        SharedBundle.decode(SharedBundle(stories: [story]).encode())!;
    expect(bundle.stories.single.toJson(), story.toJson());
    expect(bundle.length, 1);
  });

  test('stories read back from storage or a link are checked', () {
    expect(UserStory.fromJson(null), isNull);
    expect(
        UserStory.fromJson({'id': 'user:1', 'name': 'x', 'colors': []}), isNull,
        reason: 'not a story id');
    expect(
      UserStory.fromJson({
        'id': 'story:1',
        'name': ' ',
        'colors': ['#000000', '#FFFFFF'],
      }),
      isNull,
      reason: 'no name',
    );
    expect(
      UserStory.fromJson({
        'id': 'story:1',
        'name': 'Two colours needed',
        'colors': ['#000000', 'red'],
      }),
      isNull,
    );

    final odd = UserStory.fromJson({
      'id': 'story:2',
      'name': 'N' * 500,
      'colors': ['#000000', '#FFFFFF', 7, '#123456'],
      'motion': 'sideways',
      'length': 100000,
      'moments': [
        {'at': 3, 'kind': 'spark', 'color': 'javascript:', 'words': 'W' * 999},
        {'at': -1, 'kind': 'spark'},
        {'at': 2.5, 'kind': 'spark'},
        {'at': 4, 'kind': 'explode'},
        {'at': 299, 'kind': 'spell'},
        {'at': 300, 'kind': 'spell'},
        'not a moment',
        for (var i = 0; i < 100; i++) {'at': 10, 'kind': 'sparkles'},
      ],
    })!;
    expect(odd.name.length, UserStory.maxName);
    expect(odd.colors, ['#000000', '#FFFFFF', '#123456']);
    expect(odd.motion, SceneMotion.drift);
    expect(odd.length, UserStory.maxLength);
    expect(odd.moments.length, lessThanOrEqualTo(UserStory.maxMoments));
    final first = odd.moments.first;
    expect(first.at, 3);
    expect(first.color, isEmpty, reason: 'not a colour');
    expect(first.words.length, UserStory.maxWords);
    expect(odd.moments.map((m) => m.at), isNot(contains(300)));
    expect(odd.moments.map((m) => m.at), contains(299));

    final short = UserStory.fromJson({
      'id': 'story:3',
      'name': 'Short',
      'colors': ['#000000', '#FFFFFF'],
      'length': 1,
      'moments': [
        {'at': 25, 'kind': 'spark'},
      ],
    })!;
    expect(short.length, UserStory.minLength);
    expect(short.moments, isEmpty, reason: 'past the end of the story');
  });

  test('the library lists your stories first and forgets deleted ones',
      () async {
    final preferences = PreferencesController(store: InMemoryKeyValueStore());
    final library = EffectLibrary(preferences);
    await preferences.saveUserStory(story);
    await preferences.toggleFavorite(story.id);
    await preferences.savePlaylist(const Playlist(
      id: 'p1',
      name: 'Bedtime',
      effectIds: ['story:1', 'sleeping_dragon'],
    ));

    final stories = library.ofKind(EffectKind.story);
    expect(stories.first.id, 'story:1');
    expect(stories.first.name, 'The lost star');
    expect(library.ofKind(EffectKind.story, builtInOnly: true).first.id,
        isNot('story:1'));
    expect(identical(library.byId('story:1'), library.byId('story:1')), isTrue,
        reason: 'the same effect until it is edited');
    expect(library.isUserStory('story:1'), isTrue);

    await preferences.saveUserStory(UserStory(
      id: story.id,
      name: 'The found star',
      colors: story.colors,
    ));
    expect(preferences.userStories, hasLength(1));
    expect(library.byId('story:1')!.name, 'The found star');

    await preferences.deleteUserStory('story:1');
    expect(library.byId('story:1'), isNull);
    expect(preferences.favorites, isNot(contains('story:1')));
    expect(preferences.playlists.single.effectIds, ['sleeping_dragon']);
  });

  test('stories are saved with the preferences', () async {
    final store = InMemoryKeyValueStore();
    final first = PreferencesController(store: store);
    await first.saveUserStory(story);
    final second = PreferencesController(store: store);
    await second.load();
    expect(second.userStories.single.toJson(), story.toJson());
  });
}
