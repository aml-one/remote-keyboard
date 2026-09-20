import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotekeyboard/core/trackpad_gestures.dart';

void main() {
  final origin = Offset.zero;
  final t0 = DateTime.utc(2026, 1, 1);

  List<TrackpadCmd> mice(List<TrackpadCmd> cmds) =>
      cmds.where((c) => c.kind == TrackpadCmdKind.mouse).toList();

  bool hasClick(List<TrackpadCmd> cmds) {
    final m = mice(cmds);
    return m.any((c) => c.buttons == TrackpadGestures.left && c.dx == 0 && c.dy == 0) &&
        m.any((c) => c.buttons == 0 && c.dx == 0 && c.dy == 0 && c.wheel == 0);
  }

  int clickPulses(List<TrackpadCmd> cmds) {
    final m = mice(cmds);
    var n = 0;
    for (var i = 0; i + 1 < m.length; i++) {
      if (m[i].buttons == TrackpadGestures.left &&
          m[i].dx == 0 &&
          m[i + 1].buttons == 0 &&
          m[i + 1].dx == 0) {
        n++;
      }
    }
    return n;
  }

  test('quick tap clicks after the pending window, not on lift', () {
    final g = TrackpadGestures();
    expect(mice(g.down(1, origin, t0)), isEmpty);
    final up = g.up(1, t0.add(const Duration(milliseconds: 80)));
    expect(hasClick(up), isFalse);
    expect(up.any((c) => c.kind == TrackpadCmdKind.scheduleClick), isTrue);
    expect(g.clickPending, isTrue);
    expect(hasClick(g.clickFired()), isTrue);
    expect(g.clickPending, isFalse);
  });

  test('leaving the finger on then lifting is not a tap', () {
    final g = TrackpadGestures();
    g.down(1, origin, t0);
    final up = g.up(1, t0.add(const Duration(milliseconds: 500)));
    expect(hasClick(up), isFalse);
    expect(mice(up), isEmpty);
    expect(g.clickFired(), isEmpty);
  });

  test('moving after a tap is cursor move, not another click', () {
    final g = TrackpadGestures();
    g.down(1, origin, t0);
    g.up(1, t0.add(const Duration(milliseconds: 80)));
    expect(hasClick(g.clickFired()), isTrue);
    final t1 = t0.add(const Duration(milliseconds: 500));
    g.down(2, origin, t1);
    final moved = g.move(
      2,
      const Offset(40, 0),
      t1.add(const Duration(milliseconds: 16)),
      1,
    );
    expect(hasClick(moved), isFalse);
    expect(mice(moved).any((c) => c.buttons == TrackpadGestures.left), isFalse);
    expect(mice(moved).any((c) => c.dx != 0), isTrue);
    expect(g.usingForMove, isTrue);
    expect(g.holdFired(), isEmpty);
    final up = g.up(2, t1.add(const Duration(milliseconds: 400)));
    expect(hasClick(up), isFalse);
  });

  test('tap then move on the second down starts a drag', () {
    final g = TrackpadGestures();
    g.down(1, origin, t0);
    g.up(1, t0.add(const Duration(milliseconds: 80)));
    final t1 = t0.add(const Duration(milliseconds: 150));
    g.down(2, origin, t1);
    expect(g.clickFired(), isEmpty);
    final moved = g.move(
      2,
      const Offset(40, 0),
      t1.add(const Duration(milliseconds: 16)),
      1,
    );
    expect(g.dragHeld, isTrue);
    expect(hasClick(moved), isFalse);
    expect(
      mice(moved).any((c) => c.buttons == TrackpadGestures.left && c.dx != 0),
      isTrue,
    );
    final up = g.up(2, t1.add(const Duration(milliseconds: 400)));
    expect(mice(up).single.buttons, 0);
  });

  test('double tap is two clicks on the second lift', () {
    final g = TrackpadGestures();
    g.down(1, origin, t0);
    final first = g.up(1, t0.add(const Duration(milliseconds: 80)));
    expect(hasClick(first), isFalse);
    final t1 = t0.add(const Duration(milliseconds: 200));
    g.down(2, origin, t1);
    expect(g.clickFired(), isEmpty);
    final second = g.up(2, t1.add(const Duration(milliseconds: 80)));
    expect(clickPulses(second), 2);
  });

  test('a tap flashes yellow and the second tap in a double flashes orange', () {
    final g = TrackpadGestures();
    g.down(1, origin, t0);
    final first = g.up(1, t0.add(const Duration(milliseconds: 80)));
    expect(first.any((c) => c.kind == TrackpadCmdKind.tapFlash), isTrue);
    expect(first.any((c) => c.kind == TrackpadCmdKind.doubleTapFlash), isFalse);
    final t1 = t0.add(const Duration(milliseconds: 200));
    g.down(2, origin, t1);
    final second = g.up(2, t1.add(const Duration(milliseconds: 80)));
    expect(second.any((c) => c.kind == TrackpadCmdKind.doubleTapFlash), isTrue);
    expect(second.any((c) => c.kind == TrackpadCmdKind.tapFlash), isFalse);
  });

  test('tap then tap-and-hold holds without a click, so it is not a double-click', () {
    final g = TrackpadGestures();
    g.down(1, origin, t0);
    final first = g.up(1, t0.add(const Duration(milliseconds: 80)));
    expect(hasClick(first), isFalse);
    final t1 = t0.add(const Duration(milliseconds: 180));
    g.down(2, origin, t1);
    expect(g.clickFired(), isEmpty);
    final held = g.holdFired();
    expect(g.dragHeld, isTrue);
    expect(mice(held).single.buttons, TrackpadGestures.left);
    expect(hasClick(held), isFalse);
    expect(g.clickFired(), isEmpty);
    final up = g.up(2, t1.add(const Duration(milliseconds: 400)));
    expect(mice(up).single.buttons, 0);
  });

  test('hardware mouse buttons stay down and merge with a pad hold', () {
    expect(TrackpadGestures.mergeButtons(0), 0);
    expect(TrackpadGestures.mergeButtons(TrackpadGestures.left), TrackpadGestures.left);
    expect(
      TrackpadGestures.mergeButtons(TrackpadGestures.right, padHeld: true),
      TrackpadGestures.right | TrackpadGestures.left,
    );
    expect(
      TrackpadGestures.mergeButtons(TrackpadGestures.middle),
      TrackpadGestures.middle,
    );
  });
}
