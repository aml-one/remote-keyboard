import 'package:flutter/material.dart';

/// Outline laptop trackpad from the 30×30 touchpad SVG path.
///
/// Stroke is inset so the 2-unit gaps stay open, at the same line weight as
/// a 20px Material rounded chrome icon.
class TrackpadGlyph extends StatelessWidget {
  const TrackpadGlyph({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TrackpadGlyphPainter(color),
    );
  }
}

class _TrackpadGlyphPainter extends CustomPainter {
  _TrackpadGlyphPainter(this.color);

  final Color color;

  /// Plate / button gap in viewBox units.
  static const _gap = 2.0;
  static const _corner = 2.0;

  /// Material rounded icons use a 2px stroke on a 24px grid.
  static const _materialStroke = 2.0;
  static const _materialGrid = 24.0;

  static const _k1 = 0.554;
  static const _k2 = 0.446;

  /// SVG `rect929` with `translate(0,-289.0625)` applied.
  static Path _path({double inset = 0}) {
    final d = inset;
    final r = _corner - d;
    final l = 3 + d;
    final t = 6 + d;
    final right = 27 - d;
    final plateB = 16 - d;
    final btnT = 18 + d;
    final btnB = 24 - d;
    final split = 14 - d;
    final splitR = 16 + d;

    final path = Path();
    path.moveTo(l + r, t);
    path.cubicTo(l + r - _k1 * r, t, l, t + _k2 * r, l, t + r);
    path.lineTo(l, plateB);
    path.lineTo(right, plateB);
    path.lineTo(right, t + r);
    path.cubicTo(right, t + _k2 * r, right - _k2 * r, t, right - r, t);
    path.close();

    path.moveTo(l, btnB - r);
    path.cubicTo(l, btnB - _k2 * r, l + _k2 * r, btnB, l + r, btnB);
    path.lineTo(split, btnB);
    path.lineTo(split, btnT);
    path.lineTo(l, btnT);
    path.close();

    path.moveTo(splitR, btnT);
    path.lineTo(splitR, btnB);
    path.lineTo(right - r, btnB);
    path.cubicTo(
      right - _k2 * r,
      btnB,
      right,
      btnB - _k2 * r,
      right,
      btnB - r,
    );
    path.lineTo(right, btnT);
    path.close();
    return path;
  }

  static final Path _outer = _path();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = _outer.getBounds();
    final scale = size.shortestSide / bounds.longestSide;
    canvas.save();
    canvas.translate(
      (size.width - bounds.width * scale) / 2 - bounds.left * scale,
      (size.height - bounds.height * scale) / 2 - bounds.top * scale,
    );
    canvas.scale(scale);

    // Same on-screen weight as Icons.link_off_rounded at [size].
    // Cap so a 6-unit button still has a hole and [_gap] stays empty.
    final material =
        _materialStroke * (size.shortestSide / _materialGrid) / scale;
    final maxInside = (6.0 - _gap) / 2;
    final stroke = material < maxInside ? material : maxInside;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 4
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    canvas.drawPath(_path(inset: stroke / 2), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackpadGlyphPainter old) => old.color != color;
}
