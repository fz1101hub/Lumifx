import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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

/// The system's photo picker and camera. The photo stays on the phone.
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
      return await file?.readAsBytes();
    } on Object catch (error) {
      throw PhotoUnavailable(error);
    }
  }
}
