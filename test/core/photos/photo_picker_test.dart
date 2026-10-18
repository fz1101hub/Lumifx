import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumifx/src/core/photos/photo_picker.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('lumifx_photos'));
  tearDown(() => root.deleteSync(recursive: true));

  test('the picker\'s copy in the temporary folder is deleted', () async {
    final temporary = Directory('${root.path}/cache')..createSync();
    final copy = File('${temporary.path}/image_picker_1.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    await discardPickedCopy(copy.path, temporary);
    expect(copy.existsSync(), isFalse);
  });

  test('a photo outside the temporary folder is left alone', () async {
    final temporary = Directory('${root.path}/cache')..createSync();
    // A folder whose name only starts like the temporary one's.
    final gallery = Directory('${root.path}/cache-gallery')..createSync();
    final photo = File('${gallery.path}/holiday.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    await discardPickedCopy(photo.path, temporary);
    expect(photo.existsSync(), isTrue);

    // Already gone: nothing to do, and nothing thrown.
    await discardPickedCopy('${temporary.path}/missing.jpg', temporary);
  });
}
