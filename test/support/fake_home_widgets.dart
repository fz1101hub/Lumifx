import 'package:lumifx/src/features/shortcuts/home_widgets.dart';

class FakeHomeWidgets implements HomeWidgets {
  String? title;
  String? empty;
  List<WidgetEffect> effects = const [];
  int updates = 0;

  @override
  Future<void> update({
    required String title,
    required String empty,
    required List<WidgetEffect> effects,
  }) async {
    this.title = title;
    this.empty = empty;
    this.effects = effects;
    updates++;
  }
}
