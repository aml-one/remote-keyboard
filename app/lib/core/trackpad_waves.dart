import 'dart:ui' show Offset;

enum WaveFlash { lift, tap, doubleTap }

/// Visual-only contacts for the trackpad ripple. Pointer routing stays in
/// [TrackpadGestures]; this never sends HID. [pos] is global so rings can
/// follow a finger off the pad.
class TrackpadWaveField {
  static const fadeSeconds = 0.45;

  final Map<int, TrackpadWaveTouch> active = {};
  final List<TrackpadWaveBurst> fading = [];

  void Function()? onWake;

  double now = 0;

  bool get busy => active.isNotEmpty || fading.isNotEmpty;

  void down(int id, Offset pos) {
    final tone = active.isEmpty ? 0 : 1;
    active[id] = TrackpadWaveTouch(
      id: id,
      pos: pos,
      tone: tone,
      t0: now,
    );
    onWake?.call();
  }

  void move(int id, Offset pos) {
    final touch = active[id];
    if (touch == null) return;
    touch.pos = pos;
  }

  void up(int id, {WaveFlash flash = WaveFlash.lift}) {
    final touch = active.remove(id);
    if (touch == null) return;
    fading.add(
      TrackpadWaveBurst(
        pos: touch.pos,
        tone: touch.tone,
        phase: touch.phase,
        bornAge: touch.age(now),
        flash: flash,
      ),
    );
    onWake?.call();
  }

  void tick(double dt) {
    now += dt;
    for (final touch in active.values) {
      touch.phase += dt * 5.2;
    }
    for (final burst in fading) {
      burst.phase += dt * 4.4;
      burst.life -= dt / fadeSeconds;
    }
    fading.removeWhere((b) => b.life <= 0);
  }
}

class TrackpadWaveTouch {
  TrackpadWaveTouch({
    required this.id,
    required this.pos,
    required this.tone,
    required this.t0,
  });

  final int id;
  Offset pos;
  final int tone;
  final double t0;
  double phase = 0;

  double age(double now) => now - t0;
}

class TrackpadWaveBurst {
  TrackpadWaveBurst({
    required this.pos,
    required this.tone,
    required this.phase,
    required this.bornAge,
    this.flash = WaveFlash.lift,
  });

  Offset pos;
  final int tone;
  double phase;
  final double bornAge;
  final WaveFlash flash;
  double life = 1;
}
