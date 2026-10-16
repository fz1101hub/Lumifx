import 'package:flutter/widgets.dart';
import 'package:lumifx/src/core/camera/screen_sampler.dart';
import 'package:lumifx/src/features/tv/camera_input.dart';

/// A camera that sends the colours a test gives it.
class FakeCameraInput implements CameraInput {
  FakeCameraInput({this.result = CameraStartResult.started});

  CameraStartResult result;
  void Function(ScreenColors)? _onColors;
  int starts = 0;
  int stops = 0;

  bool get isRunning => _onColors != null;

  @override
  Future<CameraStartResult> start(void Function(ScreenColors) onColors) async {
    starts++;
    if (result == CameraStartResult.started) {
      _onColors = onColors;
    }
    return result;
  }

  @override
  Future<void> stop() async {
    stops++;
    _onColors = null;
  }

  /// Delivers a frame's colours, as the camera would.
  void show(ScreenColors colors) => _onColors?.call(colors);

  @override
  Widget? buildPreview() =>
      isRunning ? const ColoredBox(color: Color(0xFF223344)) : null;
}
