import 'dart:ui' show Offset;

/// Laptop-style trackpad taps.
///
/// A quick lift does **not** click immediately. The click waits until we
/// know it is not becoming tap-and-hold. A second finger-down in the
/// window cancels that click: lift quickly for a double-click, or keep
/// the finger down to hold the button (drag). Sending click then
/// button-down inside Windows' double-click time looks like a double
/// click even when the finger never lifted.
class TrackpadGestures {
  static const tapMax = Duration(milliseconds: 200);
  static const doubleWindow = Duration(milliseconds: 400);
  static const pendingClick = Duration(milliseconds: 280);
  static const slop = 16.0;
  static const left = 1;
  static const middle = 4;
  static const right = 2;
  static const holdDelay = Duration(milliseconds: 100);

  /// Hardware L/M/R stays down while the finger is on that button.
  static int mergeButtons(int hardware, {bool padHeld = false}) =>
      hardware | (padHeld ? left : 0);
  /// HID counts per logical pixel at sensitivity 1. Max slider 2.4 → 12.
  static const pointerScale = 5.0;

  final Map<int, _Contact> _pts = {};
  DateTime? _lastTapAt;
  bool _dragHeld = false;
  bool _secondDown = false;
  bool _multi = false;
  bool _clickPending = false;
  double _scrollY = 0;
  double _accX = 0;
  double _accY = 0;

  bool get dragHeld => _dragHeld;
  bool get clickPending => _clickPending;
  bool get usingForMove =>
      _multi || _dragHeld || _pts.values.any((c) => c.travel > slop);

  List<TrackpadCmd> down(int id, Offset pos, DateTime t) {
    final cmds = <TrackpadCmd>[];
    _pts[id] = _Contact(id: id, origin: pos, last: pos, started: t);
    if (_pts.length >= 2) {
      _multi = true;
      _secondDown = false;
      _clickPending = false;
      cmds.add(TrackpadCmd.cancelHold);
      cmds.add(TrackpadCmd.cancelClick);
      if (_dragHeld) {
        _dragHeld = false;
        cmds.add(const TrackpadCmd.mouse());
      }
      _scrollY = 0;
      return cmds;
    }
    _multi = false;
    final armed =
        _lastTapAt != null && t.difference(_lastTapAt!) <= doubleWindow;
    _secondDown = armed;
    if (armed) {
      _clickPending = false;
      cmds
        ..add(TrackpadCmd.cancelClick)
        ..add(TrackpadCmd.scheduleHold);
    } else {
      cmds.add(TrackpadCmd.cancelHold);
    }
    return cmds;
  }

  List<TrackpadCmd> move(int id, Offset pos, DateTime t, double gain) {
    final c = _pts[id];
    if (c == null) return const [];
    final before = _centroid();
    c.last = pos;
    c.travel = (pos - c.origin).distance;
    final d = _centroid() - before;
    if (_pts.length >= 2) {
      return _panScroll(d);
    }
    if (_secondDown && !_dragHeld && c.travel > slop) {
      final (dx, dy) = _takeStep(d, gain);
      _dragHeld = true;
      _secondDown = false;
      _clickPending = false;
      _lastTapAt = null;
      return [
        TrackpadCmd.cancelHold,
        TrackpadCmd.cancelClick,
        TrackpadCmd.mouse(buttons: left, dx: dx, dy: dy),
      ];
    }
    if (c.travel <= slop && !_dragHeld) {
      return const [];
    }
    final (dx, dy) = _takeStep(d, gain);
    if (dx == 0 && dy == 0) return const [];
    return [
      TrackpadCmd.mouse(
        buttons: _dragHeld ? left : 0,
        dx: dx,
        dy: dy,
      ),
    ];
  }

  List<TrackpadCmd> up(int id, DateTime t) {
    final c = _pts.remove(id);
    final cmds = <TrackpadCmd>[TrackpadCmd.cancelHold];
    if (_pts.length < 2) {
      _scrollY = 0;
    }
    if (c == null) return cmds;
    if (_dragHeld && _pts.isEmpty) {
      _dragHeld = false;
      _secondDown = false;
      _lastTapAt = null;
      cmds.add(const TrackpadCmd.mouse());
      return cmds;
    }
    if (_multi || _pts.isNotEmpty) {
      if (_pts.isEmpty) _multi = false;
      return cmds;
    }
    _multi = false;
    final isTap = t.difference(c.started) <= tapMax && c.travel <= slop;
    final wasSecond = _secondDown;
    _secondDown = false;
    if (!isTap) {
      _lastTapAt = null;
      return cmds;
    }
    _lastTapAt = t;
    if (wasSecond) {
      _clickPending = false;
      cmds
        ..add(TrackpadCmd.cancelClick)
        ..add(TrackpadCmd.haptic)
        ..add(const TrackpadCmd.mouse(buttons: left))
        ..add(const TrackpadCmd.mouse())
        ..add(const TrackpadCmd.mouse(buttons: left))
        ..add(const TrackpadCmd.mouse())
        ..add(TrackpadCmd.doubleTapFlash);
      return cmds;
    }
    _clickPending = true;
    cmds
      ..add(TrackpadCmd.haptic)
      ..add(TrackpadCmd.scheduleClick)
      ..add(TrackpadCmd.tapFlash);
    return cmds;
  }

  /// First-tap click, after [pendingClick], if a second contact never came.
  List<TrackpadCmd> clickFired() {
    if (!_clickPending || _secondDown || _dragHeld || _pts.isNotEmpty) {
      return const [];
    }
    _clickPending = false;
    _lastTapAt = null;
    return const [
      TrackpadCmd.mouse(buttons: left),
      TrackpadCmd.mouse(),
    ];
  }

  List<TrackpadCmd> holdFired() {
    if (_dragHeld || !_secondDown || _pts.length != 1) {
      return const [];
    }
    final c = _pts.values.first;
    if (c.travel > slop) return const [];
    _dragHeld = true;
    _secondDown = false;
    _clickPending = false;
    _lastTapAt = null;
    return const [
      TrackpadCmd.cancelClick,
      TrackpadCmd.haptic,
      TrackpadCmd.mouse(buttons: left),
    ];
  }

  List<TrackpadCmd> cancelAll() {
    _pts.clear();
    _secondDown = false;
    _clickPending = false;
    _multi = false;
    _scrollY = 0;
    _accX = 0;
    _accY = 0;
    final cmds = <TrackpadCmd>[
      TrackpadCmd.cancelHold,
      TrackpadCmd.cancelClick,
    ];
    if (_dragHeld) {
      _dragHeld = false;
      cmds.add(const TrackpadCmd.mouse());
    }
    return cmds;
  }

  Offset _centroid() {
    var sum = Offset.zero;
    for (final p in _pts.values) {
      sum += p.last;
    }
    return sum / _pts.length.toDouble();
  }

  (int, int) _takeStep(Offset d, double gain) {
    _accX += d.dx * gain;
    _accY += d.dy * gain;
    final dx = _accX.truncate();
    final dy = _accY.truncate();
    _accX -= dx;
    _accY -= dy;
    return (dx, dy);
  }

  List<TrackpadCmd> _panScroll(Offset d) {
    _scrollY += d.dy;
    const step = 6.0;
    if (_scrollY.abs() < step) return const [];
    final ticks = (-(_scrollY / step)).truncate().clamp(-8, 8);
    _scrollY -= -ticks * step;
    if (ticks == 0) return const [];
    return [TrackpadCmd.mouse(wheel: ticks)];
  }
}

class _Contact {
  _Contact({
    required this.id,
    required this.origin,
    required this.last,
    required this.started,
  });

  final int id;
  final Offset origin;
  Offset last;
  final DateTime started;
  double travel = 0;
}

class TrackpadCmd {
  const TrackpadCmd._(
    this.kind, {
    this.buttons = 0,
    this.dx = 0,
    this.dy = 0,
    this.wheel = 0,
  });

  const TrackpadCmd.mouse({
    int buttons = 0,
    int dx = 0,
    int dy = 0,
    int wheel = 0,
  }) : this._(
          TrackpadCmdKind.mouse,
          buttons: buttons,
          dx: dx,
          dy: dy,
          wheel: wheel,
        );

  static const haptic = TrackpadCmd._(TrackpadCmdKind.haptic);
  static const scheduleHold = TrackpadCmd._(TrackpadCmdKind.scheduleHold);
  static const cancelHold = TrackpadCmd._(TrackpadCmdKind.cancelHold);
  static const scheduleClick = TrackpadCmd._(TrackpadCmdKind.scheduleClick);
  static const cancelClick = TrackpadCmd._(TrackpadCmdKind.cancelClick);
  static const tapFlash = TrackpadCmd._(TrackpadCmdKind.tapFlash);
  static const doubleTapFlash = TrackpadCmd._(TrackpadCmdKind.doubleTapFlash);

  final TrackpadCmdKind kind;
  final int buttons;
  final int dx;
  final int dy;
  final int wheel;
}

enum TrackpadCmdKind {
  mouse,
  haptic,
  scheduleHold,
  cancelHold,
  scheduleClick,
  cancelClick,
  tapFlash,
  doubleTapFlash,
}
