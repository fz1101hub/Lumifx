import 'package:flutter/services.dart';

/// One effect on the home-screen widget: a tap opens LumiFX on [link].
class WidgetEffect {
  const WidgetEffect({
    required this.id,
    required this.name,
    required this.colors,
    required this.link,
  });

  final String id;

  /// Already in the phone's language.
  final String name;

  /// ARGB colours for the tile's background, first to last.
  final List<int> colors;
  final String link;

  Map<String, Object> toJson() =>
      {'id': id, 'name': name, 'colors': colors, 'link': link};
}

/// The home-screen widget of the favourites (Android; iOS once its widget
/// extension is added, see docs/IOS_WIDGET.md).
abstract interface class HomeWidgets {
  Future<void> update({
    required String title,
    required String empty,
    required List<WidgetEffect> effects,
  });
}

/// Hands the widget's content to the platform: Android stores it and
/// redraws its widgets; iOS writes it to the app group the widget reads
/// and reloads the widget timelines.
class ChannelHomeWidgets implements HomeWidgets {
  const ChannelHomeWidgets();

  static const _channel = MethodChannel('com.lumifx/widgets');

  @override
  Future<void> update({
    required String title,
    required String empty,
    required List<WidgetEffect> effects,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'empty': empty,
        'effects': [for (final e in effects) e.toJson()],
      });
    } on PlatformException {
      // No widget support on this platform: nothing to update.
    } on MissingPluginException {
      // Same, e.g. desktop or tests.
    }
  }
}

class NoHomeWidgets implements HomeWidgets {
  const NoHomeWidgets();

  @override
  Future<void> update({
    required String title,
    required String empty,
    required List<WidgetEffect> effects,
  }) async {}
}
