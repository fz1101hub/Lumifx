import 'package:flutter/widgets.dart';

import '../../core/camera/screen_sampler.dart';

/// Why the camera did not start.
enum CameraStartResult {
  started,

  /// The user said no (now or before).
  denied,

  /// No camera, or it failed to open.
  unavailable,
}

/// The phone's camera, pointed at the TV: delivers the colours it sees a
/// few times a second.
abstract class CameraInput {
  /// Opens the camera and starts sampling; [onColors] is called with each
  /// sampled frame until [stop].
  Future<CameraStartResult> start(void Function(ScreenColors) onColors);

  Future<void> stop();

  /// The live picture, to aim at the TV; null while the camera is off.
  Widget? buildPreview();
}

/// For platforms and tests without a camera.
class NoCameraInput implements CameraInput {
  const NoCameraInput();

  @override
  Future<CameraStartResult> start(void Function(ScreenColors) onColors) async =>
      CameraStartResult.unavailable;

  @override
  Future<void> stop() async {}

  @override
  Widget? buildPreview() => null;
}
