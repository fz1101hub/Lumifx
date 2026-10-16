import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes the window of every test in the file like a phone (an iPhone
/// 13: 390 x 844 logical pixels). The framework's default, 800 x 600, is
/// a tablet width to the app and would get the tablet layouts. Call it
/// from `main()`; a test that wants another size sets `tester.view` itself.
void usePhoneWindow() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
    addTearDown(view.reset);
  });
}
