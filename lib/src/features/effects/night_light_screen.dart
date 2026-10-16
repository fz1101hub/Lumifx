import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/effects/effect.dart';
import '../../core/effects/engine/effect_renderer.dart';
import '../../core/effects/engine/light_frame.dart';
import '../../core/screen_wake.dart';
import '../common/app_text.dart';
import 'light_color_ui.dart';
import 'playback_controller.dart';

/// The phone or tablet as a bedside lamp: the effect's lamps as large, soft
/// glows on black, full screen, the screen kept on. When the effect plays on
/// the lights, the glows follow them; otherwise the screen plays it alone.
class NightLightScreen extends StatefulWidget {
  const NightLightScreen({
    required this.effect,
    this.screenWake = const WakelockScreenWake(),
    super.key,
  });

  final LightingEffect effect;
  final ScreenWake screenWake;

  @override
  State<NightLightScreen> createState() => _NightLightScreenState();
}

class _NightLightScreenState extends State<NightLightScreen>
    with SingleTickerProviderStateMixin {
  static const _lamps = 3;

  /// Slower than the effect itself: a night light should barely move.
  static const _pace = 0.5;

  late final Ticker _ticker = createTicker(_tick);
  late final EffectRenderer _renderer = EffectRenderer(
    widget.effect,
    slotCount: _lamps,
    seed: 11,
  );
  List<LightFrame> _frames = List.filled(_lamps, LightFrame.off);
  PlaybackController? _playback;
  bool _controls = true;
  Timer? _hideControls;

  @override
  void initState() {
    super.initState();
    _frames = _renderer.render(Duration.zero);
    unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    unawaited(widget.screenWake.keepOn(true));
    _showControls();
    if (!WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      unawaited(_ticker.start());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playback = AppScope.of(context).playback;
  }

  void _tick(Duration elapsed) {
    final playback = _playback;
    final live = playback != null && playback.effect.id == widget.effect.id
        ? playback.player?.currentFrames
        : null;
    setState(() {
      _frames = live != null && live.isNotEmpty
          ? live
          : _renderer.render(elapsed * _pace);
    });
  }

  void _showControls() {
    _hideControls?.cancel();
    setState(() => _controls = true);
    _hideControls = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _controls = false);
      }
    });
  }

  @override
  void dispose() {
    _hideControls?.cancel();
    _ticker.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    // The player keeps the screen on by itself while an effect plays.
    if (_playback?.player == null) {
      unawaited(widget.screenWake.keepOn(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: l10n.nightLight,
              excludeSemantics: true,
              child: CustomPaint(painter: _GlowPainter(_frames)),
            ),
            AnimatedOpacity(
              opacity: _controls ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.close,
                        color: Colors.white70,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          l10n.nightLightHint,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft glows, one per lamp, spread across the screen and kept dim.
class _GlowPainter extends CustomPainter {
  _GlowPainter(this.frames);

  final List<LightFrame> frames;

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty) {
      return;
    }
    final horizontal = size.width >= size.height;
    for (final (i, frame) in frames.indexed) {
      final t = (i + 0.5) / frames.length;
      final center = horizontal
          ? Offset(size.width * t, size.height / 2)
          : Offset(size.width / 2, size.height * t);
      final radius =
          (horizontal ? size.width : size.height) / frames.length * 0.9;
      final color = frame.color.toColor();
      final level = (frame.brightness * 0.7).clamp(0.0, 1.0);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: level),
            color.withValues(alpha: level * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.frames != frames;
}
