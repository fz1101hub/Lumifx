import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Where a photo comes from.
enum PhotoSource { gallery, camera }

/// The photo could not be opened: no permission, no camera, or a file the
/// phone cannot read.
class PhotoUnavailable implements Exception {
  const PhotoUnavailable(this.reason);

  final Object reason;

  @override
  String toString() => 'PhotoUnavailable: $reason';
}

/// Lets the user choose a photo or take one.
abstract interface class PhotoPicker {
  /// The photo's bytes, small enough to read its colours; null when the
  /// user changes their mind. Throws [PhotoUnavailable].
  Future<Uint8List?> pick(PhotoSource source);
}

/// For platforms and tests without photos.
class NoPhotoPicker implements PhotoPicker {
  const NoPhotoPicker();

  @override
  Future<Uint8List?> pick(PhotoSource source) async => null;
}

/// The system's photo picker and camera. The photo stays on the phone;
/// the small copy the picker makes in the app's temporary folder is
/// deleted once its colours are read.
class PluginPhotoPicker implements PhotoPicker {
  PluginPhotoPicker();

  final _picker = ImagePicker();

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.gallery => ImageSource.gallery,
          PhotoSource.camera => ImageSource.camera,
        },
        maxWidth: 512,
        maxHeight: 512,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }
      try {
        return await file.readAsBytes();
      } finally {
        await _discard(file.path);
      }
    } on Object catch (error) {
      throw PhotoUnavailable(error);
    }
  }

  static Future<void> _discard(String path) async {
    try {
      await discardPickedCopy(path, await getTemporaryDirectory());
    } on Object {
      // No temporary folder to compare with: the copy is left to the
      // system, which clears its cache anyway.
    }
  }
}

/// Deletes the picker's copy at [path] when it lies in the app's own
/// [temporary] folder; a photo anywhere else (the gallery's own file) is
/// never touched.
@visibleForTesting
Future<void> discardPickedCopy(String path, Directory temporary) async {
  try {
    final file = File(path);
    final folder = temporary.resolveSymbolicLinksSync();
    final copy = file.resolveSymbolicLinksSync();
    if (copy.startsWith('$folder${Platform.pathSeparator}')) {
      await file.delete();
    }
  } on Object {
    // Gone already, or never ours: the system clears its cache anyway.
  }
}
