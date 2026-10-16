import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/camera/screen_sampler.dart';
import 'camera_input.dart';

/// The back camera through the `camera` plugin, at a low resolution: only
/// a few thousand pixels of each frame are read, about ten times a second,
/// on the phone; nothing is recorded, stored or sent.
class PluginCameraInput implements CameraInput {
  PluginCameraInput({this.interval = const Duration(milliseconds: 90)});

  /// The least time between two sampled frames.
  final Duration interval;

  CameraController? _controller;
  DateTime _lastSample = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sampling = false;

  @override
  Future<CameraStartResult> start(void Function(ScreenColors) onColors) async {
    await stop();
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on Object {
      return CameraStartResult.unavailable;
    }
    if (cameras.isEmpty) {
      return CameraStartResult.unavailable;
    }
    final camera = cameras
            .where((c) => c.lensDirection == CameraLensDirection.back)
            .firstOrNull ??
        cameras.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!identical(_controller, controller)) {
        await controller.dispose();
        return CameraStartResult.unavailable;
      }
      await controller.startImageStream((image) {
        if (_sampling || !identical(_controller, controller)) {
          return;
        }
        final now = DateTime.now();
        if (now.difference(_lastSample) < interval) {
          return;
        }
        _lastSample = now;
        _sampling = true;
        try {
          final frame = _frameOf(image);
          if (frame == null) {
            return;
          }
          final colors = sampleScreen(
            frame,
            quarterTurns: _quarterTurns(
              camera,
              controller.value.deviceOrientation,
            ),
          );
          if (colors != null) {
            onColors(colors);
          }
        } finally {
          _sampling = false;
        }
      });
      return CameraStartResult.started;
    } on CameraException catch (e) {
      await _release(controller);
      return switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          CameraStartResult.denied,
        _ => CameraStartResult.unavailable,
      };
    } on Object {
      await _release(controller);
      return CameraStartResult.unavailable;
    }
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    if (controller != null) {
      await _release(controller);
    }
  }

  Future<void> _release(CameraController controller) async {
    if (identical(_controller, controller)) {
      _controller = null;
    }
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } on Object {
      // Already stopped with the camera.
    }
    try {
      await controller.dispose();
    } on Object {
      // Nothing left to release.
    }
  }

  @override
  Widget? buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    return CameraPreview(controller);
  }

  static CameraFrame? _frameOf(CameraImage image) {
    final format = switch (image.format.group) {
      ImageFormatGroup.yuv420 => FrameFormat.yuv420,
      ImageFormatGroup.bgra8888 => FrameFormat.bgra8888,
      _ => null,
    };
    if (format == null) {
      return null;
    }
    return CameraFrame(
      width: image.width,
      height: image.height,
      format: format,
      planes: [
        for (final plane in image.planes)
          FramePlane(
            plane.bytes,
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel,
          ),
      ],
    );
  }

  /// Clockwise quarter turns that make the sensor's picture upright with
  /// the phone held in [orientation].
  static int _quarterTurns(
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    final device = switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + device) % 360
        : (camera.sensorOrientation - device + 360) % 360;
    return degrees ~/ 90;
  }
}
