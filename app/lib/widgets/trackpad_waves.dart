import 'dart:math' as math;

import 'package:aml_ui/aml_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/palettes.dart';
import '../core/trackpad_waves.dart';

/// Circular ripple overlay. Ticks only while a finger is down or a fade
/// is still dying, so idle pads cost nothing.
///
/// Positions are **global**. The painter lives in a route Overlay so rings
/// can follow a finger off the pad after the gesture started there.
class TrackpadWaves extends StatefulWidget {
  const TrackpadWaves({
    super.key,
    required this.field,
    required this.palette,
    this.useOverlay = true,
  });

  final TrackpadWaveField field;
  final KeyPalette palette;

  /// Route Overlay so rings can follow a finger off a clipped pad. Landscape
  /// paints in-tree instead (`false`) so a pad resize cannot tear the ticker.
  final bool useOverlay;

  @override
  State<TrackpadWaves> createState() => _TrackpadWavesState();
}

class _TrackpadWavesState extends State<TrackpadWaves>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration? _last;
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.field.onWake = _wake;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.useOverlay) _mountOverlay();
      if (mounted && widget.field.busy) _wake();
    });
  }

  @override
  void activate() {
    super.activate();
    if (widget.field.busy) _wake();
  }

  @override
  void didUpdateWidget(covariant TrackpadWaves oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field != widget.field) {
      oldWidget.field.onWake = null;
      widget.field.onWake = _wake;
    }
    if (widget.useOverlay) {
      if (_entry == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.useOverlay) _mountOverlay();
        });
      } else {
        _entry!.markNeedsBuild();
      }
    } else if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
    if (widget.field.busy) _wake();
  }

  @override
  void dispose() {
    widget.field.onWake = null;
    _ticker.dispose();
    _frame.dispose();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _mountOverlay() {
    if (!mounted || _entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _entry = OverlayEntry(builder: _overlay);
    overlay.insert(_entry!);
    if (widget.field.busy) _wake();
  }

  Widget _overlay(BuildContext overlayContext) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WavePainter(
              field: widget.field,
              palette: widget.palette,
              frame: _frame,
              toLocal: (global) {
                final box = overlayContext.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize || !box.attached) {
                  return global;
                }
                return box.globalToLocal(global);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final last = _last ?? elapsed;
    _last = elapsed;
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0) dt = 1 / 60;
    if (dt > 0.05) dt = 0.05;
    widget.field.tick(dt);
    _frame.value++;
    if (!widget.field.busy) {
      _ticker.stop();
      _last = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useOverlay) return const SizedBox.expand();
    return SizedBox.expand(
      child: CustomPaint(
        painter: _WavePainter(
          field: widget.field,
          palette: widget.palette,
          frame: _frame,
          toLocal: (global) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize || !box.attached) return global;
            return box.globalToLocal(global);
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.field,
    required this.palette,
    required this.frame,
    required this.toLocal,
  }) : super(repaint: frame);

  final TrackpadWaveField field;
  final KeyPalette palette;
  final Listenable frame;
  final Offset Function(Offset global) toLocal;

  static const _tap = Color(0xFFFFD54F);
  static const _doubleTap = Color(0xFFFF9100);

  Color _ink(int tone, [WaveFlash flash = WaveFlash.lift]) {
    return switch (flash) {
      WaveFlash.tap => _tap,
      WaveFlash.doubleTap => _doubleTap,
      WaveFlash.lift => tone == 0 ? AmlTheme.violet : AmlTheme.mint,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!field.busy) return;
    for (final touch in field.active.values) {
      _ripple(
        canvas,
        origin: toLocal(touch.pos),
        age: touch.age(field.now),
        alpha: 1,
        phase: touch.phase,
        color: _ink(touch.tone),
      );
    }
    for (final burst in field.fading) {
      _ripple(
        canvas,
        origin: toLocal(burst.pos),
        age: burst.bornAge + (1 - burst.life) * 0.35,
        alpha: burst.life.clamp(0.0, 1.0),
        phase: burst.phase,
        color: _ink(burst.tone, burst.flash),
      );
    }
  }

  void _ripple(
    Canvas canvas, {
    required Offset origin,
    required double age,
    required double alpha,
    required double phase,
    required Color color,
  }) {
    final pulse = 1 + 0.10 * math.sin(phase);
    final haloR = 38 * pulse;
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.38 * alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: origin, radius: haloR));
    canvas.drawCircle(origin, haloR, halo);

    for (var ring = 0; ring < 3; ring++) {
      final local = 14.0 + (age * 58 + ring * 20) % 72;
      final fade = (1 - local / 92).clamp(0.0, 1.0);
      final a = alpha * fade * (0.50 - ring * 0.10);
      if (a <= 0.02) continue;
      canvas.drawCircle(
        origin,
        local,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7 + 0.4 * math.sin(phase + ring)
          ..color = color.withValues(alpha: a),
      );
    }

    final glowR = 11 * pulse;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95 * alpha),
          color.withValues(alpha: 0.85 * alpha),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.38, 1.0],
      ).createShader(Rect.fromCircle(center: origin, radius: glowR));
    canvas.drawCircle(origin, glowR, glow);
    canvas.drawCircle(
      origin,
      3.1 * pulse,
      Paint()..color = Colors.white.withValues(alpha: 0.92 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.field != field;
}
